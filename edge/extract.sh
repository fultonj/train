#!/bin/bash

SRC=central
DIR=edge-common
CLEAN=1

if [[ ! -d $SRC ]]; then
    echo "cannot find $SRC directory"
    exit 1
fi
if [[ $CLEAN ]]; then
    rm -rf $DIR
fi
if [[ ! -d $DIR ]]; then
    mkdir $DIR
fi

if [[ ! -e central/config-download/group_vars/overcloud.json ]]; then
    echo "Cannot find central/config-download/group_vars/overcloud.json"
    exit 1
fi

cat central/config-download/group_vars/overcloud.json | jq '{"parameter_defaults": {"AllNodesExtraMapData": .}}' > $DIR/all-nodes-extra-map-data.json

source ~/stackrc

openstack stack output show $SRC EndpointMap --format json | jq '{"parameter_defaults": {"EndpointMapOverride": .output_value}}' > $DIR/endpoint-map.json

openstack stack output show $SRC HostsEntry -f json | jq -r '{"parameter_defaults":{"ExtraHostFileEntries": .output_value}}' > $DIR/extra-host-file-entries.json

openstack stack output show $SRC GlobalConfig --format json \
  | jq '{"parameter_defaults": {"GlobalConfigExtraMapData": .output_value}}' \
  > $DIR/global-config-extra-map-data.json

openstack object save central plan-environment.yaml
python -c "import yaml; data=yaml.safe_load(open('plan-environment.yaml').read()); print yaml.dump(dict(parameter_defaults=data['passwords']))" > edge-common/passwords.yaml
rm -f plan-environment.yaml

wc -l $DIR/*
