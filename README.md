# Train

Every OpenStack cycle I end up with scripts I revise to make
development easier. This is where I'm storing the scripts for the
Train cycle.

<!--
I've stored them on github under various names:
- https://github.com/fultonj/oooq
- https://github.com/fultonj/rhel8
- https://github.com/fultonj/edge
- https://github.com/fultonj/tripleo-ceph-ansible
-->

## How I use

- [Deploy](https://github.com/fultonj/tripleo-lab/blob/fultonj/CHEAT.md) undercloud
- Run the following on undercloud
```
git clone git@github.com:fultonj/train.git
cd train

./git-init.sh tht
./containers.sh
./deploy.sh

```

