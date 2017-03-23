#!/bin/bash

# Install deps
yum install -y aws-cli jq telnet vim bind-utils
# Disable automatic updates by updating yum configuration file
sed -i "17"' s/^/#/' "/etc/yum.conf"

# Setup the cluster parameter so this node can join the right cluster.
echo ECS_CLUSTER=${cluster} >> /etc/ecs/ecs.config
