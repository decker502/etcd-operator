#!/usr/bin/env bash

# Backup a etcd cluster.

set -o errexit
set -o nounset
set -o pipefail

ETCD_ROOT=$(dirname "${BASH_SOURCE}")

if [ $# -le 0 ];then
  echo -e "Environment para should be set" >&2
  exit 1
fi

envfile=$1
if [ -f "${ETCD_ROOT}/env/${envfile}.sh" ]; then
  source "${ETCD_ROOT}/env/${envfile}.sh"
else
  echo -e "Canot find Environment file  ${ETCD_ROOT}/env/${envfile}.sh " >&2
  exit 1
fi

source ${ETCD_ROOT}/utils/etcd-util.sh
source ${ETCD_ROOT}/utils/common.sh

# Provision master
#
# Assumed vars:
#   $1 (node)
#   $2 (etcd_name)
#   ETCD_TEMP
#   ETCD_SERVERS
#   ETCD_INITIAL_CLUSTER
function restore-etcd() {
  echo "[INFO] Restore etcd on $1"
  local node="$1"
  local etcd_name="$2"
  local node_ip="${node#*@}"

  echo "[INFO] Scp files"
  kube-scp "${node}" "${ROOT}/binaries/etcd ${ROOT}/binaries/etcdctl" "${ETCD_BIN_DIR}"
  kube-scp "${node}" "${LOCAL_CERT_DIR}/ca.pem \
    ${LOCAL_CERT_DIR}/client.pem \
    ${LOCAL_CERT_DIR}/client-key.pem \
    ${LOCAL_CERT_DIR}/server-${node_ip}.pem \
    ${LOCAL_CERT_DIR}/server-${node_ip}-key.pem \
    ${LOCAL_CERT_DIR}/peer-${node_ip}.pem \
    ${LOCAL_CERT_DIR}/peer-${node_ip}-key.pem" "${ETCD_CERT_DIR}"
    
  kube-ssh "${node}" " sudo rm -f /tmp/snapshot.db"
  kube-scp "${node}"  "${LOCAL_BACKUP_DIR}/snapshot.db" "/tmp"

  echo "[INFO] Restore"

  ETCD_OLD_DATA_DIR=$(date +%Y%m%d%H%M%S)

  kube-ssh "${node}" " sudo systemctl stop etcd;"

  kube-ssh "${node}" "if [[ -d ${ETCD_DATA_DIR} ]];then \
      sudo mv ${ETCD_DATA_DIR} /tmp/old_etcd_data_${ETCD_OLD_DATA_DIR}; \
    fi"

  kube-ssh "${node}" " sudo rm -rf ${etcd_name}.etcd"
  kube-ssh "${node}" " \
    sudo ETCDCTL_API=3 ${ETCD_BIN_DIR}/etcdctl \
        snapshot restore /tmp/snapshot.db \
        --name ${etcd_name} \
        --initial-cluster ${ETCD_INITIAL_CLUSTER}  \
        --initial-cluster-token k8s-etcd-cluster \
        --initial-advertise-peer-urls https://${node}:2380 ; "
  kube-ssh "${node}" "sudo mkdir -p ${ETCD_DATA_DIR}; \
    sudo mv ${etcd_name}.etcd ${ETCD_DATA_DIR}/default.etcd; \
    sudo chown -R etcd.etcd ${ETCD_DATA_DIR}; "

}

echo -e "${color_green}... calling verify-prereqs${color_norm}" >&2
verify-prereqs
echo -e "${color_green}... calling verify-etcd-binaries${color_norm}" >&2
verify-etcd-binaries

echo -e "${color_green}... calling etcd restore${color_norm}" >&2

num_infra=0
for node in ${ETCD_NODES}; do
  restore-etcd ${node} "infra${num_infra}"  
  let ++num_infra
done

for node in ${ETCD_NODES}; do
  echo "[INFO] start service for ${node}"
  kube-ssh "${node}" "sudo systemctl daemon-reload; sudo systemctl enable etcd;"
  kube-ssh "${node}" "sudo systemctl restart etcd" &
done

wait

echo -e "${color_green}... calling validate-cluster${color_norm}" >&2
# Override errexit
(validate-cluster) && validate_result="$?" || validate_result="$?"

if [[ "${validate_result}" == "1" ]]; then
	exit 1
fi
