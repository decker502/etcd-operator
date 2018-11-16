#!/usr/bin/env bash

## Set initial-cluster-state to existing, and restart etcd service.

sed -i 's/ETCD_INITIAL_CLUSTER_STATE="new"/ETCD_INITIAL_CLUSTER_STATE="existing"/' /opt/kubernetes/cfg/etcd.conf

systemctl daemon-reload
systemctl enable etcd
systemctl restart etcd
