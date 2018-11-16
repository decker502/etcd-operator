#!/usr/bin/env bash

readonly root=$(cd $(dirname "${BASH_SOURCE}")/.. && pwd)

export ETCD_DOMAINS=${ETCD_DOMAINS:-""}

# Define all your etcd nodes,
# And separated with blank space like <user_1@ip_1> <user_2@ip_2> <user_3@ip_3>.
# The user should have sudo privilege
export ETCD_NODES=${ETCD_NODES:-""}

#　发布机证书目录
export LOCAL_CERT_DIR="${root}/cert"

# 目录机相关配置项
export ETCD_CFG_DIR="/etc/etcd"
export ETCD_DATA_DIR="/var/lib/etcd"
export ETCD_GOMAXPROCS="2"
export ETCD_CERT_DIR="${ETCD_CFG_DIR}/cert"
export ETCD_BIN_DIR="/opt/etcd/bin"

export ETCD_CAFILE=${ETCD_CAFILE:-"${ETCD_CERT_DIR}/ca.pem"}
export ETCD_CERTFILE=${ETCD_CERTFILE:-"${ETCD_CERT_DIR}/client.pem"}
export ETCD_KEYFILE=${ETCD_KEYFILE:-"${ETCD_CERT_DIR}/client-key.pem"}

unset -f concat-etcd-servers length-of concat-etcd-initial-cluster
