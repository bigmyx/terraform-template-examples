#!/bin/bash
set -e
set -o pipefail

####################### Script Parameters #######################

MYIP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
INSTANCEID=$(curl http://169.254.169.254/latest/meta-data/instance-id)
MYHOSTNAME="consul-$${INSTANCEID#*-}"
AWS_REGION=${region}
NAME_TAG=${tag}
CONSULVERSION=${consul_version}
BINDIR=/usr/local/bin
DATADIR=/data/consul
CONSULCONFIGDIR=/etc/consul.d
CONSULCONFIGFILE=$CONSULCONFIGDIR/consul.json
CONSULDOWNLOAD=https://releases.hashicorp.com/consul/$${CONSULVERSION}/consul_$${CONSULVERSION}_linux_amd64.zip
UPSTART_FILE=/etc/init/consul.conf
TMP_FILE=/tmp/consul.zip

hostname $MYHOSTNAME

#################### Install dependencies #######################
yum install -y unzip install curl jq at
easy_install awscli

curl -L $${CONSULDOWNLOAD} > $TMP_FILE
unzip -o /tmp/consul.zip -d $BINDIR
chmod 0755 $BINDIR/consul
rm -f $TMP_FILE

mkdir -p $CONSULCONFIGDIR
mkdir -p $DATADIR

###### Create upstart conf ######
cat > $UPSTART_FILE <<EOL
description "Consul agent"
start on runlevel [2345]
stop on runlevel [!2345]
respawn
script
  export GOMAXPROCS=`nproc`
  exec $BINDIR/consul agent \
    -ui \
    -config-dir=$CONSULCONFIGDIR \
    -bind=$MYIP \
    -node=$MYHOSTNAME \
    -datacenter=$AWS_REGION
end script
EOL

cat > $CONSULCONFIGFILE <<EOL
{
  "data_dir": "/data/consul",
  "log_level": "INFO",
  "bootstrap_expect": 3,
  "client_addr": "0.0.0.0",
  "server": true,
  "enable_syslog": true,
  "rejoin_after_leave": true,
  "retry_join_ec2": {
    "region": "$AWS_REGION",
    "tag_key": "Name",
    "tag_value": "$NAME_TAG"
  }
}
EOL

start consul



