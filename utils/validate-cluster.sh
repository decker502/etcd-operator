#!/usr/bin/env bash

# Validates that the cluster is healthy.
# Error codes are:
# 0 - success
# 1 - fatal (cluster is unlikely to work)

set -o errexit
set -o nounset
set -o pipefail
set -x

if [ $# -le 0 ];then
  echo -e "Environment para should be set" >&2
  exit 1
fi

envfile=$1

ETCD_ROOT=$(cd $(dirname "${BASH_SOURCE}")/.. && pwd)

source "$ETCD_ROOT/utils/config-default.sh"

if [ -f "${ETCD_ROOT}/env/${envfile}.sh" ]; then
  source "${ETCD_ROOT}/env/${envfile}.sh"
fi

source "$ETCD_ROOT/utils/common.sh"

attempt=0
while true; do

  etcd_status=$(ETCDCTL_API=3 ${ETCD_ROOT}/binaries/etcdctl --cert=${LOCAL_CERT_DIR}/client.pem --key=${LOCAL_CERT_DIR}/client-key.pem --cacert=${LOCAL_CERT_DIR}/ca.pem --endpoints=${ETCD_SERVERS} endpoint health) || true
  
  healthy=$(echo "${etcd_status}" | grep -c 'is healthy') || true

  if ((${NUM_ETCD_NODES} > healthy)); then
    if ((attempt < 5)); then
      echo -e "${color_yellow}Cluster not working yet.${color_norm}"
      attempt=$((attempt+1))
      sleep 30
    else
      echo -e " ${color_yellow}Validate output:${color_norm}"
      echo -e "${color_red}Validation returned one or more failed nodes. Cluster is probably broken.${color_norm}"
      exit 1
    fi
  else
    echo -e "${color_green}Cluster validation succeeded${color_norm}"
    break
  fi
done

