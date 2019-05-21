#!/bin/bash

HEAT=1
DOWN=1
CONF=1
CEPH=0

STACK=overcloud
DIR=config-download
#DIR=$(date +%b%d_%H.%M)

source ~/stackrc
# -------------------------------------------------------
if [[ $HEAT -eq 1 ]]; then
    if [[ ! -d ~/templates ]]; then
        ln -s /usr/share/openstack-tripleo-heat-templates templates
    fi
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
         --no-config-download \
         --libvirt-type qemu 2>&1 | tee -a ~/install-overcloud.log

    # remove --no-config-download to make DOWN and CONF unnecessary
fi
# -------------------------------------------------------
if [[ $DOWN -eq 1 ]]; then
    if [[ $(openstack stack list | grep $STACK | wc -l) -eq 0 ]]; then
	echo "No $STACK heat stack. Exiting"
	exit 1
    fi
    openstack overcloud config download \
              --name $STACK \
              --config-dir $DIR
    if [[ ! -d $DIR ]]; then
	echo "tripleo-config-download cmd didn't create $DIR"
    else
	pushd $DIR
	tripleo-ansible-inventory --static-yaml-inventory inventory.yaml --stack $STACK
	ansible --ssh-extra-args "-o StrictHostKeyChecking=no" -i inventory.yaml all -m ping
	popd
	echo "pushd $DIR"
	echo 'ansible -i inventory.yaml all -m shell -b -a "hostname"'
    fi
fi
# -------------------------------------------------------
if [[ $CONF -eq 1 ]]; then
    if [[ ! -d $DIR ]]; then
	echo "tripleo-config-download cmd didn't create $DIR"
        exit 1;
    fi
    time ansible-playbook \
	 -v \
	 --ssh-extra-args "-o StrictHostKeyChecking=no" --timeout 240 \
	 --become \
	 -i $DIR/inventory.yaml \
	 tripleo-config-download/deploy_steps_playbook.yaml
fi
# -------------------------------------------------------
if [[ $CEPH -eq 1 ]]; then
    # Only used if you want to re-run only the ceph portion of deployment
    if [[ ! -d $DIR ]]; then
	echo "tripleo-config-download cmd didn't create $DIR"
        exit 1;
    fi
    time ansible-playbook \
	 -v \
	 --ssh-extra-args "-o StrictHostKeyChecking=no" --timeout 240 \
	 --become \
	 -i $DIR/inventory.yaml \
	 tripleo-config-download/deploy_steps_playbook.yaml --tags external_deploy_steps
fi
