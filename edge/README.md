# Edge

I use these templates and scripts to simulate an Edge deployment.

- Use [deploy.sh](central/deploy.sh) to deploy central controllers with [central/overrides.yaml](central/overrides.yaml)
- Use [extract.sh](extract.sh) to extract controller information into edge-common
- Use [deploy.sh](edge0/deploy.sh) to deploy an hci node in AZ edge0 with [edge0/overrides.yaml](edge0/overrides.yaml) and [edge0/ceph.yaml](edge0/ceph.yaml)
- Use [test.sh](test.sh) to test that the edge deployment is working

Alternatively, you can do this which will do all of the above for you:

`time ./master.sh 2>&1 | tee -a master.log`
