#!/bin/bash

source ~/stackrc

time openstack overcloud deploy \
  --templates ~/templates/ \
  -e ~/templates/environments/disable-telemetry.yaml \
  -e ~/templates/environments/low-memory-usage.yaml \
  -e ~/templates/environments/enable-swap.yaml \
  -e ~/templates/environments/podman.yaml \
  -e ~/templates/environments/ceph-ansible/ceph-ansible.yaml \
  -e ~/containers-env-file.yaml \
  -e ~/overcloud-yml/container-cli.yaml \
  -e ~/overcloud-yml/domain.yaml \
  -e ~/overcloud-yml/node-placement.yaml \
  -e ~/train/overrides.yaml \
  --libvirt-type qemu 2>&1 | tee -a ~/install-overcloud.log
