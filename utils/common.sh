#!/usr/bin/env bash

if [[ -z "${color_start-}" ]]; then
  declare -r color_start="\033["
  declare -r color_red="${color_start}0;31m"
  declare -r color_yellow="${color_start}0;33m"
  declare -r color_green="${color_start}0;32m"
  declare -r color_norm="${color_start}0m"
fi


# length-of <arg0>
# Get the length of specific arg0, could be a space-separate string or array.
function length-of() {
  local len=0
  for part in $1; do
    let ++len
  done
  echo $len
}
# Number of nodes in your cluster.
export NUM_ETCD_NODES="${NUM_ETCD_NODES:-$(length-of "$ETCD_NODES")}"

# By default, the cluster will use the etcd installed on master.
function concat-etcd-servers() {
  local etcd_servers=""
  for node in ${ETCD_NODES}; do
    local node_ip=${node#*@}
    local prefix=""
    if [ -n "$etcd_servers" ]; then
      prefix="${etcd_servers},"
    fi
    etcd_servers="${prefix}https://${node_ip}:2379"
  done

  echo "$etcd_servers"
}
export ETCD_SERVERS="$(concat-etcd-servers)"

# By default, etcd cluster will use runtime configuration
#   https://coreos.com/etcd/docs/latest/v2/runtime-configuration.html
# Get etc initial cluster and store in ETCD_INITIAL_CLUSTER
function concat-etcd-initial-cluster() {
  local etcd_initial_cluster=""
  local num_infra=0
  for node in ${ETCD_NODES}; do
    local node_ip="${node#*@}"
    if [ -n "$etcd_initial_cluster" ]; then
      etcd_initial_cluster+=","
    fi
    etcd_initial_cluster+="infra${num_infra}=https://${node_ip}:2380"
    let ++num_infra
  done

  echo "$etcd_initial_cluster"
}
export ETCD_INITIAL_CLUSTER="$(concat-etcd-initial-cluster)"

export ETCD_NODES_IP=${ETCD_NODES[@]#*@}

unset -f concat-etcd-servers length-of concat-etcd-initial-cluster
