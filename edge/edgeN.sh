#!/usr/bin/env bash

if [[ -z $1 ]]; then
    N=1
else
    N=$1
fi
if [[ $N -lt 1 ]]; then
    echo "Only positive integers please"
    exit 1
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
    cp edge0/deploy.sh $deploy/deploy.sh
    sed s/edge0/$deploy/g -i $deploy/deploy.sh
    pushd $deploy
    bash deploy.sh
    popd
done
