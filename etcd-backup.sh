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

echo -e "${color_green}... calling verify-prereqs${color_norm}" >&2
verify-prereqs
echo -e "${color_green}... calling verify-etcd-binaries${color_norm}" >&2
verify-etcd-binaries

echo -e "${color_green}... calling etcd-up${color_norm}" >&2
mkdir -p ${LOCAL_BACKUP_DIR}

ETCD_BACKUP_NAME=$(date +%Y%m%d%H%M%S)
(ETCDCTL_API=3 ${ETCD_ROOT}/binaries/etcdctl \
        --endpoints=${ETCD_SERVERS} \
        --cert=${LOCAL_CERT_DIR}/client.pem --key=${LOCAL_CERT_DIR}/client-key.pem --cacert=${LOCAL_CERT_DIR}/ca.pem \
        snapshot save ${LOCAL_BACKUP_DIR}/snapshot-${ETCD_BACKUP_NAME}.db) && backup_result="$?" || backup_result="$?"

if [[ "${backup_result}" != "0" ]]; then
    rm -f ${LOCAL_BACKUP_DIR}/snapshot-${ETCD_BACKUP_NAME}.db.*
    echo -e "${color_red}... etcd backup fail ${color_red}" >&2
else
    echo -e "${color_yellow} Warning : Please watch the BACKUP result below!!!(重点关注下列备份结果，确保Key数目正确) ${color_norm}" >&2
    ETCDCTL_API=3 ${ETCD_ROOT}/binaries/etcdctl \
        --endpoints=${ETCD_SERVERS} \
        --cert=${LOCAL_CERT_DIR}/client.pem --key=${LOCAL_CERT_DIR}/client-key.pem --cacert=${LOCAL_CERT_DIR}/ca.pem \
        snapshot status -w table ${LOCAL_BACKUP_DIR}/snapshot.db

    rm -f ${LOCAL_BACKUP_DIR}/snapshot.db; ln -s ${LOCAL_BACKUP_DIR}/snapshot-${ETCD_BACKUP_NAME}.db ${LOCAL_BACKUP_DIR}/snapshot.db
    echo -e "${color_green}... etcd  backup done${color_norm}" >&2
fi

