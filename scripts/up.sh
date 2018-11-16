#!/usr/bin/env bash

services="etcd"

systemctl daemon-reload

for service in ${services}; do
    
    systemctl enable ${service}
    systemctl restart ${service}
done
