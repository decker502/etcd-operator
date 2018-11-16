#!/usr/bin/env bash

# Bring up a etcd cluster.

set -o errexit
set -o nounset
set -o pipefail

ETCD_ROOT=$(dirname "${BASH_SOURCE}")

source ${ETCD_ROOT}/utils/etcd-util.sh

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

source ${ETCD_ROOT}/utils/common.sh

echo -e "${color_green}... calling verify-prereqs${color_norm}" >&2
verify-prereqs
echo -e "${color_green}... calling verify-etcd-binaries${color_norm}" >&2
verify-etcd-binaries

echo -e "${color_green}... calling etcd-up${color_norm}" >&2
etcd-up ${envfile}
echo -e "${color_green}... etcd-up done${color_norm}" >&2

echo -e "${color_green}... calling validate-cluster${color_norm}" >&2
# Override errexit
(validate-cluster) && validate_result="$?" || validate_result="$?"

if [[ "${validate_result}" == "1" ]]; then
	exit 1
fi
