#!/bin/bash

HEAT=1
DOWN=1
CONF=1

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
    STACK_STATUS=$(openstack stack list -c "Stack Name" -c "Stack Status" \
	-f value | grep $STACK | awk {'print $2'});
    if [[ ! ($STACK_STATUS == "CREATE_COMPLETE" || 
                 $STACK_STATUS == "UPDATE_COMPLETE") ]]; then
	echo "Exiting. Status of $STACK is $STACK_STATUS"
	exit 1
    fi
    if [[ -d $DIR ]]; then rm -rf $DIR; fi
    openstack overcloud config download \
              --name $STACK \
              --config-dir $DIR
    if [[ ! -d $DIR ]]; then
	echo "tripleo-config-download cmd didn't create $DIR"
    else
	pushd $DIR
	tripleo-ansible-inventory --static-yaml-inventory inventory.yaml --stack $STACK
	if [[ ! -e inventory.yaml ]]; then
	    echo "No inventory. Giving up."
	    exit 1
	fi
        cp -a ~/.ssh/id_rsa ssh_private_key
	ansible --private-key ssh_private_key \
	    --ssh-extra-args "-o StrictHostKeyChecking=no" \
	    -i inventory.yaml all -m ping
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

    #echo "about to execute the following plays:"
    #ansible-playbook $DIR/deploy_steps_playbook.yaml --list-tasks

    # include library/roles from tripleo-validations and tripleo-common
    export ANSIBLE_ROLES_PATH="$ANSIBLE_ROLES_PATH:/usr/share/openstack-tripleo-common/playbooks/roles:/usr/share/openstack-tripleo-validations/roles:/usr/share/ansible/roles"
    export ANSIBLE_LIBRARY="$ANSIBLE_LIBRARY:/usr/share/openstack-tripleo-validations/library:/usr/share/ansible-modules/"
    export ANSIBLE_LOG_PATH="ansible.log"
    echo "NEXT: $(date)" >> ansible.log

    time ansible-playbook \
	 -v \
	 --ssh-extra-args "-o StrictHostKeyChecking=no" --timeout 240 \
	 --become \
	 -i $DIR/inventory.yaml \
         --private-key $DIR/ssh_private_key \
	 $DIR/deploy_steps_playbook.yaml

         # Just re-run ceph
         # --tags external_deploy_steps

         # Test validations
         # --tags opendev-validation-ceph
    
         # Pick up after good ceph install (need to test this)
         # --tags step2,step3,step4,step5,post_deploy_steps,external --skip-tags ceph

fi
