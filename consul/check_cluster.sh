#!/usr/bin/env bash

ELB_NAME=consul-elb-tf
COUNT=0
LIMIT=10
until [ $COUNT -ge $LIMIT ]
do
  echo -e "\e[0mwaiting for \e[30;48;5;82m${CLUSTER}\e[0m ... [$COUNT/$LIMIT]"
  echo -en "\e[96m"
  aws elb describe-instance-health \
    --load-balancer-name $ELB_NAME | grep InService && break
  echo -en "\e[0m"
  ((COUNT++))
  sleep 30
done

