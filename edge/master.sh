#!/usr/bin/env bash

KILL=1

source ~/stackrc
if [[ $KILL -eq 1 ]]; then
    if [[ $(openstack stack list | wc -l) -gt 1 ]]; then
        echo "Destroying the following deployments"
        openstack stack list
        for STACK in $(openstack stack list -f value -c "Stack Name"); do
            bash ../kill.sh $STACK
        done
    fi
fi

echo "Standing up central deployment"
pushd central
bash deploy.sh
popd

echo "Extracting data from central deployment for edge deployments"
bash extract.sh

echo "Standing up edge0 deployment"
pushd edge0
bash deploy.sh
popd

echo "Testing"
bash test.sh
