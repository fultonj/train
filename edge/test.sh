#!/usr/bin/env bash

DISC=1
CEPH=1
GLANCE=1
NOVA=1
DEPS=1
CINDER=1
PUBLIC=0

if [[ ! -f central/centralrc ]]; then
    echo "Could not find central/centralrc to authenticate. Exiting"
    exit 1
fi
source central/centralrc

openstack endpoint list > /dev/null
if [[ $? -gt 0 ]]; then
    echo "Cannot list end points. Aborting"
    exit 1
fi

export AZ="edge0"
export HOST_AGGREGATE="HA-${AZ}"

export PRIVATE_NETWORK_CIDR=192.168.200.0/24
if [[ $PUBLIC -eq 1 ]]; then
    export PUBLIC_NETWORK_CIDR=192.168.24.0/24
    export GATEWAY=192.168.24.1
    export PUBLIC_NET_START=192.168.24.40
    export PUBLIC_NET_END=192.168.24.50
fi

if [[ $DISC -eq 1 ]]; then
    # Optional if we update NovaSchedulerDiscoverHostsInCellsInterval
    echo "Discovering any unmapped external compute node(s)"
    INV="central/config-download/inventory.yaml --limit nova_api[0]"
    ansible -i $INV Controller -m shell -b -a \
            "podman exec -ti nova_api nova-manage cell_v2 discover_hosts --verbose"
    openstack compute service list
    echo "Availability Zones"
    nova availability-zone-list
    echo "Compute availability zones (before any changes)"
    openstack availability zone list --compute

    echo "Compute Hosts"
    openstack host list 
    echo "Hypervisors"
    openstack hypervisor list
    echo "See https://docs.openstack.org/nova/latest/admin/availability-zones.html"

    if ! openstack aggregate show $HOST_AGGREGATE >null 2>&1; then
        echo "Creating a host aggregate for $AZ"
        openstack aggregate create $HOST_AGGREGATE --zone $AZ
        for H in $(openstack hypervisor list -f value -c "Hypervisor Hostname"); do
            echo "Adding $H to $HOST_AGGREGATE"
            openstack aggregate add host $HOST_AGGREGATE $H
        done
    else
        echo "Host Aggregate: $HOST_AGGREGATE"
        openstack aggregate show $HOST_AGGREGATE
    fi

    echo "Compute availability zones (after change)"
    openstack availability zone list --compute
    nova availability-zone-list

    echo "Volume services"
    openstack volume service list
    echo "Volume availability zones"
    openstack availability zone list --volume
fi

if [[ $CEPH -eq 1 ]]; then
    INV="$AZ/config-download/inventory.yaml --limit mons[0]"    
    SUFFIX=$(ls edge0/config-download/host_vars/ | head -1)
    ansible -i $INV mons -m shell -b -a \
            "podman exec -ti ceph-mon-$SUFFIX ceph -s"
    ansible -i $INV mons -m shell -b -a \
            "podman exec -ti ceph-mon-$SUFFIX ceph df"
    #ansible -i $INV mons -m shell -b -a \
    #        "podman exec -ti ceph-mon-$SUFFIX ceph osd dump | grep pool"
fi

if [[ $GLANCE -eq 1 ]]; then
    # delete all images if any
    for ID in $(openstack image list -f value -c ID); do
        openstack image delete $ID;
    done
    # download cirros image only if necessary
    IMG=cirros-0.4.0-x86_64-disk.img
    RAW=$(echo $IMG | sed s/img/raw/g)
    if [ ! -f $RAW ]; then
        if [ ! -f $IMG ]; then
            echo "Could not find qemu image $img; downloading a copy."
            curl -# https://download.cirros-cloud.net/0.4.0/$IMG > $IMG
        fi
        echo "Could not find raw image $RAW; converting."
        qemu-img convert -f qcow2 -O raw $IMG $RAW
    fi
    if [[ $CEPH -eq 1 ]]; then
        echo "Listing rbd images pool to prove glance images not on ceph"
        ansible -i $INV mons -m shell -b -a \
                "podman exec -ti ceph-mon-$SUFFIX rbd -p images ls -l"
    fi
    openstack image create cirros --container-format bare --disk-format raw --public --file $RAW
    if [[ $CEPH -eq 1 ]]; then
        echo "Listing rbd images pool to prove glance images not on ceph"
        ansible -i $INV mons -m shell -b -a \
                "podman exec -ti ceph-mon-$SUFFIX rbd -p images ls -l"
    fi
    openstack image list
fi

if [[ $NOVA -eq 1 ]]; then
    if [[ $DEPS -eq 1 ]]; then
        echo "Checking the following dependencies..."
        IMAGE_ID=$(openstack image show cirros -f value -c id)
        if [[ -z $IMAGE_ID ]]; then
            echo "Unable to find cirros image; re-run with GLANCE=1"
            exit 1
        fi
        echo "- glance image"
        # create basic security group to allow ssh/ping/dns only if necessary
        SEC_GROUP_ID=$(openstack security group show basic -f value -c id)
        if [[ -z $SEC_GROUP_ID ]]; then
            openstack security group create basic
            # allow ssh
            openstack security group rule create basic --protocol tcp --dst-port 22:22 --remote-ip 0.0.0.0/0
            # allow ping
            openstack security group rule create --protocol icmp basic
            # allow DNS
            openstack security group rule create --protocol udp --dst-port 53:53 basic
        fi
        echo "- security groups"
        # create public/private networks only if necessary
        if [[ $PUBLIC -eq 1 ]]; then
            PUB_NET_ID=$(openstack network show public -c id -f value)
            if [[ -z $PUB_NET_ID ]]; then
                openstack network create --external --provider-physical-network datacentre --provider-network-type flat public
            fi
            PUB_SUBNET_ID=$(openstack network show public -c subnets -f value)
            if [[ -z $PUB_SUBNET_ID ]]; then
                openstack subnet create public-net \
                          --subnet-range $PUBLIC_NETWORK_CIDR \
                          --no-dhcp \
                          --gateway $GATEWAY \
                          --allocation-pool start=$PUBLIC_NET_START,end=$PUBLIC_NET_END \
                          --network public
            fi
            echo "- public networks"
        fi
        PRI_NET_ID=$(openstack network show private -c id -f value)
        if [[ -z $PRI_NET_ID ]]; then
            openstack network create --internal private
        fi
        PRI_SUBNET_ID=$(openstack network show private -c subnets -f value)
        if [[ -z $PRI_SUBNET_ID ]]; then
            openstack subnet create private-net \
                      --subnet-range $PRIVATE_NETWORK_CIDR \
                      --network private
        fi
        echo "- private networks"
        # create router only if necessary
        if [[ $PUBLIC -eq 1 ]]; then        
            ROUTER_ID=$(openstack router show vrouter -f value -c id)
            if [[ -z $ROUTER_ID ]]; then
                # IP will be automatically assigned from allocation pool of the subnet
                openstack router create vrouter
                openstack router set vrouter --external-gateway public
                openstack router add subnet vrouter private-net
            fi
            echo "- router"
            # create floating IP only if necessary
            FLOATING_IP=$(openstack floating ip list -f value -c "Floating IP Address")
            if [[ -z $FLOATING_IP ]]; then
                openstack floating ip create public
                FLOATING_IP=$(openstack floating ip list -f value -c "Floating IP Address")
            fi
            if [[ -z $FLOATING_IP ]]; then
                echo "Unable to use existing or create new floating IP"
                exit 1
            fi
            echo "- floating IP"
        fi    
        # create flavor only if necessary
        FLAVOR_ID=$(openstack flavor show tiny -f value -c id)
        if [[ -z $FLAVOR_ID ]]; then
            openstack flavor create --ram 512 --disk 1 --vcpu 1 --public tiny
        fi
        echo "- flavor"
        KEYPAIR_ID=$(openstack keypair show demokp -f value -c user_id)
        if [[ ! -z $KEYPAIR_ID ]]; then
            openstack keypair delete demokp
            if [[ -f ~/demokp.pem ]]; then
                rm -f ~/demokp.pem
            fi
        fi
        openstack keypair create demokp > ~/demokp.pem
        chmod 600 ~/demokp.pem
        echo "- SSH keypairs"
        echo ""
    fi
    echo "Deleting previous Nova server(s)"
    for ID in $(openstack server list -f value -c ID); do
        openstack server delete $ID;
    done

    if [[ $CINDER -eq 1 ]]; then
	# Delete volumes after deleting servers to ensure no volumes are attached.
	echo "Deleting previous Cinder volume(s)"
	for ID in $(openstack volume list -f value -c ID); do
            openstack volume delete $ID;
	done

	echo "Creating Cinder volume"
	openstack volume create --size 1 --availability-zone $AZ myvol
	if [ $? != "0" ]; then
            echo "Error creating a volume in AZ ${AZ}. If this is a brand new edge"
            echo "deployment then cinder-scheduler may not have time to learn about"
            echo "the new AZ. Please wait minute or so, and try again."
            exit 1
	fi
	for i in {1..5}; do
            sleep 1
            STATUS=$(openstack volume show myvol -f value -c status)
            if [[ $STATUS == "available" || $STATUS == "error" ]]; then
		break
            fi
	done

	if [[ $STATUS != "available" ]]; then
            echo "Volume create failed; aborting."
            exit 1
	fi
        if [[ $CEPH -eq 1 ]]; then
            echo "Listing rbd volumes pool"
            ansible -i $INV mons -m shell -b -a \
                    "podman exec -ti ceph-mon-$SUFFIX rbd -p volumes ls -l"
        fi
    fi

    echo "Launching Nova server"
    openstack server create --flavor tiny --image cirros --key-name demokp --network private --security-group basic myserver --availability-zone $AZ

    STATUS=$(openstack server show myserver -f value -c status)
    echo "Server status: $STATUS (waiting)"
    while [[ $STATUS == "BUILD" ]]; do
        sleep 1
        echo -n "."
        STATUS=$(openstack server show myserver -f value -c status)
    done
    echo ""
    if [[ $STATUS == "ERROR" ]]; then
        echo "Server build failed; aborting."
        exit 1
    fi
    if [[ $STATUS == "ACTIVE" ]]; then
        openstack server list
	if [[ $CEPH -eq 1 ]]; then
	    echo -e "\nListing objects in Ceph vms pool:\n"
            ansible -i $INV mons -m shell -b -a \
                    "podman exec -ti ceph-mon-$SUFFIX rbd -p vms ls -l"
	    echo ""
	fi
        if [[ $PUBLIC -eq 1 ]]; then
            FLOATING_IP=$(openstack floating ip list -f value -c "Floating IP Address")
            openstack server add floating ip myserver $FLOATING_IP
            echo "Will attempt to SSH into $FLOATING_IP for 30 seconds"
            i=0
            while true; do
                ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" \
                    -i ~/demokp.pem cirros@$FLOATING_IP "exit" 2> /dev/null && break
                echo -n "."
                sleep 1
                i=$(($i+1))
                if [[ $i -gt 30 ]]; then break; fi
            done
            echo ""
            ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" \
                -i ~/demokp.pem cirros@$FLOATING_IP "uname -a; lsblk"
            echo ""
        fi
	if [[ $CINDER -eq 1 ]]; then
            echo "Attaching the volume"
            openstack server add volume myserver myvol
            sleep 3
            openstack volume list
	fi
        if [[ $PUBLIC -eq 1 ]]; then        
            ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" \
                -i ~/demokp.pem cirros@$FLOATING_IP "uname -a; lsblk"
            echo ""
            echo -e "\nssh -o \"UserKnownHostsFile /dev/null\" -o \"StrictHostKeyChecking no\" -i ~/demokp.pem cirros@$FLOATING_IP"
        fi
    fi
fi
