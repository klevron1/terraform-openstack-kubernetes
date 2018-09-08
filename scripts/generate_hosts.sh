#!/bin/bash

rm -rf files/hosts_entries.txt

for instance in worker-0 worker-1 worker-2; do
IPADDRESSES=($(openstack server show $instance -f json | jq .addresses | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}"))
PRIVATE_ADDRESS=${IPADDRESSES[1]}
echo "$PRIVATE_ADDRESS $instance" >> files/hosts_entries.txt
done


for instance in controller-0 controller-1 controller-2; do
IPADDRESSES=($(openstack server show $instance -f json | jq .addresses | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}"))
PRIVATE_ADDRESS=${IPADDRESSES[1]}
echo "$PRIVATE_ADDRESS $instance" >> files/hosts_entries.txt
done

instance=haproxy
IPADDRESSES=($(openstack server show $instance -f json | jq .addresses | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}"))
PUBLIC_ADDRESS=${IPADDRESSES[0]}
echo "$PUBLIC_ADDRESS $instance" >> files/hosts_entries.txt

sudo cat files/hosts.backup files/hosts_entries.txt > /etc/hosts
