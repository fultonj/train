#!/usr/bin/bash

CLOUD=overcloud
opensatck stack delete $CLOUD --wait --yes
openstack overcloud delete $CLOUD --yes
