#!/usr/bin/env bash

IRONIC=1

if [[ -z $1 ]]; then
    N=1
else
    N=$1
fi
if [[ $N -lt 1 ]]; then
    echo "Only positive integers please"
    exit 1
fi

if [[ $IRONIC -eq 1 ]]; then
    source ~/stackrc
    i=1
    for UUID in $(openstack baremetal node list -f value -c UUID -c Name \
                            -c "Provisioning State" \
                      | grep available | grep ceph | awk {'print $1'}); do
        openstack baremetal node set $UUID \
                  --property capabilities="node:$i-ceph-0,boot_option:local"
        i=$((i+1))
    done
    if [[ $i -ne $N ]]; then
        echo "N being reset from $N to $i (based on available Ceph nodes)"
        N=$i
    fi
fi

for i in $(seq 1 $N); do
    deploy="edge$i"
    if [[ -d $deploy ]]; then
        echo "A directory named $deploy already exists. Aborting."
        exit 1
    fi
    echo "Creating $deploy (deployment $i out of $N)"
    
    mkdir $deploy
    cp edge0/ceph.yaml $deploy/ceph.yaml
    sed s/edge0/$deploy/g -i $deploy/ceph.yaml
    cp edge0/overrides.yaml $deploy/overrides.yaml
    sed s/edge0/$deploy/g -i $deploy/overrides.yaml
    sed s/"0-ceph-%index%"/"$i-ceph-%index%"/g -i $deploy/overrides.yaml
    cp edge0/deploy.sh $deploy/deploy.sh
    sed s/edge0/$deploy/g -i $deploy/deploy.sh
    pushd $deploy
    bash deploy.sh
    popd
done
