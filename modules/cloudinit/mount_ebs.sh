#!/bin/bash
mkfs.xfs /dev/xvdg
mkdir /var/log/obs
mount /dev/xvdg /var/log/obs
grep /dev/xvdg /proc/mounts >> /etc/fstab
sed -i 's/=1024\:4096/=8192\:8192/' /etc/sysconfig/docker #set proper ulimit for docker
