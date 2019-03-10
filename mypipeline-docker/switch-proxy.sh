#!/bin/bash

#
# Switch web proxy on or off
#

MODE=$1

if grep -q "^proxy=http" /etc/yum.conf; then
  STATE=on
else
  STATE=off
fi

if [ -z $MODE ]; then
  echo "Usage: $0 on|off"
  echo -e "\nProxy is currently $STATE\n"
  exit 1
fi

if [ $MODE = "on" ]; then
  sed -i "s/^#proxy=http/proxy=http/" /etc/yum.conf
  sed -i "s/^#Environment=\"HTTP_PROXY/Environment=\"HTTP_PROXY/" /etc/systemd/system/docker.service.d/http-proxy.conf
  systemctl daemon-reload
  systemctl restart docker
elif [ $MODE = "off" ]; then
  sed -i "s/^proxy=http/#proxy=http/" /etc/yum.conf
  sed -i "s/^Environment=\"HTTP_PROXY/#Environment=\"HTTP_PROXY/" /etc/systemd/system/docker.service.d/http-proxy.conf
  systemctl daemon-reload
  systemctl restart docker
else
  echo "ERROR: Invalid mode: $MODE"
  exit 1
fi

