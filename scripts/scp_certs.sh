#!/bin/bash

# rm -rf ~/.ssh/known_hosts
cd certificates || exit 1

for instance in worker-0 worker-1 worker-2; do
IPADDRESSES=($(openstack server show $instance -f json | jq .addresses | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}"))
PUBLIC_ADDRESS=${IPADDRESSES[0]}
scp -i ~/.ssh/id_rsa-kubernetes_the_hard_way -o StrictHostKeyChecking=no ca.pem ${instance}-key.pem ${instance}.pem ../files/hosts_entries.txt ubuntu@${PUBLIC_ADDRESS}:~/
done


for instance in controller-0 controller-1 controller-2; do
IPADDRESSES=($(openstack server show $instance -f json | jq .addresses | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}"))
PUBLIC_ADDRESS=${IPADDRESSES[0]}
scp -i ~/.ssh/id_rsa-kubernetes_the_hard_way -o StrictHostKeyChecking=no ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
service-account-key.pem service-account.pem ../files/hosts_entries.txt ubuntu@${PUBLIC_ADDRESS}:~/
done

cd ..

