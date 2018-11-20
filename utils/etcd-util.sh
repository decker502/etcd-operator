#!/usr/bin/env bash

# exit on any error
set -e

if [ $# -le 0 ];then
  echo -e "Environment para should be set" >&2
  exit 1
fi

envfile=$1

SSH_OPTS="-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oLogLevel=ERROR -C"

readonly ROOT=$(cd $(dirname "${BASH_SOURCE}")/.. && pwd)
source "${ROOT}/${ETCD_CONFIG_FILE:-"utils/config-default.sh"}"

# Instantiate a etcd cluster
function etcd-up() {
  local num_infra=0
  for node in ${ETCD_NODES}; do
    echo "[INFO] make-ca-cert for ${node}"
    ETCD_DOMAINS=${ETCD_DOMAINS[@]} bash -c "${ROOT}/utils/make-ssl.sh -ip ${node#*@} -d ${LOCAL_CERT_DIR}"

    # 需要并发执行，否则etcd 多实例时会出现超时，集群无法启动
    provision-etcd "${node}" "infra${num_infra}"  
    let ++num_infra
  done
  
  for node in ${ETCD_NODES}; do
    echo "[INFO] start service for ${node}"
    kube-ssh "${node}" "sudo systemctl daemon-reload; sudo systemctl enable etcd;"
    kube-ssh "${node}" "sudo systemctl restart etcd" &
  done

  wait


}

# Delete a etcd cluster
function etcd-down() {

  for node in ${ETCD_NODES}; do
    tear-down-node ${node}
  done

}

# Provision master
#
# Assumed vars:
#   $1 (node)
#   $2 (etcd_name)
#   ETCD_SERVERS
#   ETCD_INITIAL_CLUSTER
function provision-etcd() {
  echo "[INFO] Provision etcd on $1"
  local node="$1"
  local node_ip="${node#*@}"
  local etcd_name="$2"
  ensure-setup-dir "${node}"

  echo "[INFO] Scp files"
  kube-scp "${node}" "${ROOT}/binaries/etcd ${ROOT}/binaries/etcdctl" "${ETCD_BIN_DIR}"
  kube-scp "${node}" "${LOCAL_CERT_DIR}/ca.pem \
    ${LOCAL_CERT_DIR}/client.pem \
    ${LOCAL_CERT_DIR}/client-key.pem \
    ${LOCAL_CERT_DIR}/server-${node_ip}.pem \
    ${LOCAL_CERT_DIR}/server-${node_ip}-key.pem \
    ${LOCAL_CERT_DIR}/peer-${node_ip}.pem \
    ${LOCAL_CERT_DIR}/peer-${node_ip}-key.pem" "${ETCD_CERT_DIR}" 

  echo "[INFO] Setup"

  ETCD_NAME=${etcd_name} ETCD_LISTEN_IP=${node_ip} \
  kube-ssh-pipe "${node}" "envsubst <  ${ROOT}/templates/etcd.service" "sudo cat > /etc/systemd/system/etcd.service"

  ETCD_NAME=${etcd_name} ETCD_LISTEN_IP=${node_ip} \
  kube-ssh-pipe "${node}" "envsubst <  ${ROOT}/templates/etcd.conf" "sudo cat > ${ETCD_CFG_DIR}/etcd.conf"

  kube-ssh "${node}" " \
    sudo chmod -R +x ${ETCD_BIN_DIR}; "

}

# Validate a kubernetes cluster
function validate-cluster() {
  set +e
  ${ROOT}/utils/validate-cluster.sh ${envfile}
  if [[ "$?" -ne "0" ]]; then
    for node in ${ETCD_NODES}; do
      troubleshoot-etcd ${node}
    done
    exit 1
  fi
  set -e
}

# Delete a etcd cluster
function etcd-down() {

  for node in ${ETCD_NODES}; do
    tear-down ${node}
  done
}


# Clean up
function tear-down() {
echo "[INFO] tear-down on $1"
  for service_name in etcd; do
      service_file="/etc/systemd/system/${service_name}.service"
      kube-ssh "$1" " \
        if [[ -f $service_file ]]; then \
          sudo systemctl stop $service_name; \
          sudo systemctl disable $service_name; \
          sudo rm -f $service_file; \
        fi"
  done
  kube-ssh "${1}" "sudo rm -rf ${ETCD_BIN_DIR}"
  kube-ssh "${1}" "sudo rm -rf ${ETCD_CFG_DIR}"
  kube-ssh "${1}" "sudo rm -rf ${ETCD_DATA_DIR}"
}

function troubleshoot-etcd() {
  # Troubleshooting on etcd if all required daemons are active.
  echo "[INFO] Troubleshooting on etcd $1"
  local -a required_daemon=("etcd")
  local daemon
  local daemon_status
  printf "%-24s %-10s \n" "PROCESS" "STATUS"
  for daemon in "${required_daemon[@]}"; do
    local rc=0
    kube-ssh "${1}" "sudo systemctl is-active ${daemon}" >/dev/null 2>&1 || rc="$?"
    if [[ "${rc}" -ne "0" ]]; then
      daemon_status="inactive"
    else
      daemon_status="active"
    fi
    printf "%-24s %s\n" ${daemon} ${daemon_status}
  done
  printf "\n"
}

# Verify prereqs on host machine
function verify-prereqs() {
  local rc
  rc=0
  ssh-add -L 1> /dev/null 2> /dev/null || rc="$?"
  # "Could not open a connection to your authentication agent."
  if [[ "${rc}" -eq 2 ]]; then
    eval "$(ssh-agent)" > /dev/null
    trap-add "kill ${SSH_AGENT_PID}" EXIT
  fi
  rc=0
  ssh-add -L 1> /dev/null 2> /dev/null || rc="$?"
  # "The agent has no identities."
  if [[ "${rc}" -eq 1 ]]; then
    # Try adding one of the default identities, with or without passphrase.
    ssh-add || true
  fi
  rc=0
  # Expect at least one identity to be available.
  if ! ssh-add -L 1> /dev/null 2> /dev/null; then
    echo "Could not find or add an SSH identity."
    echo "Please start ssh-agent, add your identity, and retry."
    exit 1
  fi
}

# Install handler for signal trap
function trap-add {
  local handler="$1"
  local signal="${2-EXIT}"
  local cur

  cur="$(eval "sh -c 'echo \$3' -- $(trap -p ${signal})")"
  if [[ -n "${cur}" ]]; then
    handler="${cur}; ${handler}"
  fi

  trap "${handler}" ${signal}
}

# Check whether required binaries exist, prompting to download
# if missing.
function verify-etcd-binaries() {

  binaries=(
    "${ROOT}/binaries/etcd"
    "${ROOT}/binaries/etcdctl"
  )

  for binary in ${binaries[@]}; do
    if [[ ! -f "${binary}" ]]; then
      echo "!!! Cannot find ${binary}" >&2
      exit 1
    fi
    echo "${binary}"
  done
  
}


# Run command over ssh
function kube-ssh() {
  local host="$1"
  shift
  ssh ${SSH_OPTS} -t "${host}" "$@" >/dev/null 2>&1
}

# Run command over ssh pipe
function kube-ssh-pipe() {
  local host="$1"
  local pipe="$2"
  shift 2
  eval "${pipe}" | ssh ${SSH_OPTS} -t "${host}" "$@" 
}

# Copy file recursively over ssh
function kube-scp() {
  local host="$1"
  local src=($2)
  local dst="$3"
  rsync -vzuqL  ${src[*]} "${host}:${dst}"
}

# Create dirs that'll be used during setup on target machine.
#
# Assumed vars:
function ensure-setup-dir() {
  kube-ssh "${1}" "mkdir -p ${ETCD_DATA_DIR} ${ETCD_BIN_DIR} ${ETCD_CERT_DIR};"
}
