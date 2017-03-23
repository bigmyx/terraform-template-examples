#!/usr/bin/env bash

if [ $# -eq 0 ]; then
    echo "Please supply zone as an argument"
    echo "$0 <a|b>"
    exit 1
fi

ZONE=$1

for CLUSTER in agency primarydb coordinator; do
  COUNT=0
  LIMIT=10
  until [ $COUNT -ge $LIMIT ]
  do
    echo -e "\e[0mwaiting for \e[30;48;5;82m${CLUSTER}\e[0m ... [$COUNT/$LIMIT]"
    echo -en "\e[96m"
    aws elb describe-instance-health \
      --load-balancer-name ${CLUSTER}-${ZONE} | grep InService && break
    echo -en "\e[0m"
    ((COUNT++))
    sleep 30
  done
done

