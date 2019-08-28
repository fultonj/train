#!/usr/bin/env bash
# for local testing of https://review.opendev.org/#/c/664065

if [[ -e inventory.yaml ]]; then
    rm -v inventory.yaml;
fi

/home/stack/tripleo-validations/scripts/tripleo-ansible-inventory \
    --static-yaml-inventory inventory.yaml --stack central,edge0,edge1,edge2

if [[ -e inventory.yaml ]]; then
    wc -l inventory.yaml;
else
    echo "inventory.yaml file not created"
fi
