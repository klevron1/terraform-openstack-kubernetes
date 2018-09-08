#!/bin/bash

EXTERNAL_IP=$(ip address show dev ens3 | grep 'inet ' | awk '{print $2}' | sed 's/\/32//g')
#sed "s/XXX.XXX.XXX.XXX/$EXTERNAL_IP/" < /tmp/haproxy.cfg > /etc/haproxy/haproxy.cfg
#sed -i "s/XXX.XXX.XXX.XXX/$EXTERNAL_IP/g" /tmp/haproxy.cfg
#mv /tmp/haproxy.cfg /etc/haproxy/haproxy.cfg
sudo cp /tmp/haproxy.cfg /etc/haproxy/haproxy.cfg 
sudo sed -i "s@XXX.XXX.XXX.XXX@$EXTERNAL_IP@" /etc/haproxy/haproxy.cfg
service haproxy restart
