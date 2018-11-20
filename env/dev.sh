#!/usr/bin/env bash
readonly ENV_ROOT=$(cd $(dirname "${BASH_SOURCE}")/.. && pwd)

# 必填项
export ETCD_NODES=("10.200.0.15 10.200.0.14 10.200.0.13")

export LOCAL_CERT_DIR="${ENV_ROOT}/cert/dev"
export LOCAL_BACKUP_DIR="${ENV_ROOT}/backup/dev"
# 可选项
# export ETCD_DOMAINS=("www.do.com" "www2.do.com")
# export LOCAL_CERT_DIR="${root}/ca-cert"
# export ETCD_CFG_DIR="/etc/etcd"
# export ETCD_DATA_DIR="/var/lib/etcd"
# export ETCD_GOMAXPROCS="2"
# export ETCD_CERT_DIR="${ETCD_CFG_DIR}/cert"
# export ETCD_BIN_DIR="/opt/etcd/bin"

# export ETCD_CAFILE=${ETCD_CAFILE:-"${ETCD_CERT_DIR}/ca.pem"}
# export ETCD_CERTFILE=${ETCD_CERTFILE:-"${ETCD_CERT_DIR}/client.pem"}
# export ETCD_KEYFILE=${ETCD_KEYFILE:-"${ETCD_CERT_DIR}/client-key.pem"}