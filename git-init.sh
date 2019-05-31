#!/usr/bin/env bash
# Filename:                git-init.sh
# Description:             configures my git env
# Supported Langauge(s):   GNU Bash 4.2.x
# Time-stamp:              <2019-05-31 15:04:11 fultonj> 
# -------------------------------------------------------
# Clones the repos that I am interested in.
# -------------------------------------------------------
if [[ $1 == 'tht' ]]; then
    pushd ~
    declare -a repos=(
        'openstack/tripleo-heat-templates' \
        'openstack/tripleo-common'\
        'openstack/tripleo-validations'\
	);
fi
# -------------------------------------------------------
if [[ $# -eq 0 ]]; then
    # uncomment whatever you want
    declare -a repos=(
                      # 'openstack/tripleo-heat-templates' \
		      # 'openstack/tripleo-common'\
                      # 'openstack/tripleo-ansible' \
                      # 'openstack/tripleo-validations' \
                      # 'openstack/python-tripleoclient' \	
		      # 'openstack/puppet-ceph'\
		      #'openstack/heat'\
		      # 'openstack-infra/tripleo-ci'\
		      # 'openstack/tripleo-puppet-elements'\
		      # 'openstack/tripleo-specs'\
		      # 'openstack/os-net-config'\
		      # 'openstack/tripleo-docs'\
		      # 'openstack/tripleo-quickstart'\
		      # 'openstack/tripleo-quickstart-extras'\
		      #'openstack/tripleo-repos' 
		      #'openstack/puppet-nova'\
		      #'openstack/puppet-tripleo'\
		      # add the next repo here
    );
fi
# -------------------------------------------------------
gerrit_user='fultonj'
git config --global user.email "fulton@redhat.com"
git config --global user.name "John Fulton"
git config --global push.default simple
git config --global gitreview.username $gerrit_user

git review --version
if [ $? -gt 0 ]; then
    echo "installing git-review from upstream"
    dir=/tmp/$(date | md5sum | awk {'print $1'})
    mkdir $dir
    pushd $dir
    curl http://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/g/git-review-1.24-5.el7.noarch.rpm > git-review-1.24-5.el7.noarch.rpm
    sudo yum localinstall git-review-1.24-5.el7.noarch.rpm -y 
    popd 
    rm -rf $dir
fi 

for repo in "${repos[@]}"; do
    dir=$(echo $repo | awk 'BEGIN { FS = "/" } ; { print $2 }')
    if [ ! -d $dir ]; then
	git clone https://git.openstack.org/$repo.git
	pushd $dir
	git remote add gerrit ssh://$gerrit_user@review.openstack.org:29418/$repo.git
	git review -s
	popd
    else
	pushd $dir
	git pull --ff-only origin master
	popd
    fi
done

# -------------------------------------------------------
if [[ $1 == 'tht' ]]; then
    if [[ ! -e ~/templates ]]; then
        ln -v -s ~/tripleo-heat-templates ~/templates
    fi
    if [[ ! -d /usr/share/tripleo-common/playbooks.bak ]]; then
        sudo mv -v /usr/share/tripleo-common/playbooks{,.bak}
    fi
    if [[ -d ~/tripleo-common/playbooks ]]; then
        sudo ln -f -v -s ~/tripleo-common/playbooks /usr/share/tripleo-common/playbooks
    fi
    if [[ ! -d /usr/share/openstack-tripleo-validations.bak ]]; then
        sudo mv -v /usr/share/openstack-tripleo-validations{,.bak}
    fi
    if [[ -d ~/tripleo-validations ]]; then
        sudo ln -f -v -s ~/tripleo-validations /usr/share/openstack-tripleo-validations
    fi
    popd
    echo 'source /home/stack/stackrc' >> ~/.bashrc
    echo 'alias os=openstack' >> ~/.bashrc    
fi
# -------------------------------------------------------
