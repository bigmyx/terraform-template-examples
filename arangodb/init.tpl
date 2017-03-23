#!/bin/bash

# Install deps
yum install -y aws-cli jq telnet vim bind-utils
# Disable automatic updates by updating yum configuration file
sed -i "17"' s/^/#/' "/etc/yum.conf"

# Setup the cluster parameter so this node can join the right cluster.
echo ECS_CLUSTER=${cluster_name} >> /etc/ecs/ecs.config

IP=$(curl -s http://instance-data/latest/meta-data/local-ipv4)

# Start Registrator Container
cat > /etc/init/registrator.conf <<EOL
description "Consul Registrator Service"
start on started ecs
respawn
respawn limit 3 10
script
  docker run\
  --volume=/var/run/docker.sock:/tmp/docker.sock\
  ${registrator_image}\
  -ip=$IP\
  -cleanup\
  -tags ${zone},${env}\
  -ttl 120 \
  -ttl-refresh 60 \
  -retry-attempts 20 \
  -retry-interval 10000 \
  consul://${consul}:8500
end script
EOL
