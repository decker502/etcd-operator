#!/usr/bin/env bash

# Tear down a Kubernetes cluster.

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

echo -en "${color_red}Warning: All data will be delete (集群所有数据都将被删除)!!! Are you sure? (Y/n)${color_norm}" 
read 

if [[ ${REPLY} != "Y" && ${REPLY} != "y" ]]; then
  exit 0
fi


echo -e "${color_green}Bringing down cluster ${color_norm}"

echo -e "${color_green}... calling verify-prereqs${color_norm}" >&2
verify-prereqs

echo -e "${color_green}... calling etcd-down${color_norm}" >&2
etcd-down

echo -e "${color_green}Done${color_norm}"
