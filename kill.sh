#!/usr/bin/bash

source ~/stackrc

CLOUD=overcloud
# delete heat stack
openstack stack delete $CLOUD --wait --yes

# delete deployment plan 
openstack overcloud delete $CLOUD --yes
# yes, the above also deletes the heat stack but not as quickly

if [[ -e ansible.log ]]; then
    rm -v -f ansible.log
fi
if [[ -d config-download ]]; then
    rm -v -rf config-download
fi
