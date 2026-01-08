# Stage 5: Deploying a multi-node cluster

Docs:
    - [Manual Multi-Node Cluster](https://kairos.io/docs/examples/multi-node/)

For this exercise, we will create 2 virtual machines, one will be the control plane (master) and the other one the worker. In order to allow them to communicate,
they should be part of the same network. How you do that depends on your virtualization software / hypervisor.

## Select your installation source

You can use an image you created in one of the previous stages or you can pick
one from https://quay.io/organization/kairos . We will use k3s in this example
so make sure you select one with k3s that matches your architecture.

## Prepare master node

In a manner similar to [stage-1](stage-1.md), boot up a VM and install Kairos
with a simple config like the following:


```
#cloud-config

hostname: metal-{{ trunc 4 .MachineID }}
users:
- name: kairos # Change to your own user
  passwd: kairos # Change to your own password
  groups:
    - admin # This user needs to be part of the admin group

k3s:
  enabled: true
```

If you still have the VM from [stage-1](stage-1.md) around, you can use that in this exercise.

## Find the k3s token

Assuming the installation above is complete and you rebooted to the installed system, find the k3s token which we'll use in the next step to connect the worker to
the cluster. Run this on the master node and note down the result.

```bash
    cat /var/lib/rancher/k3s/server/node-token
```

Also, if you don't already know the IP address of the master node, find it and
note it down too (e.g. using `ip addr` command on the master node).

## Prepare worker node

Similarly to how the master node was created, create a new VM but this time use
a config like the following:

```yaml
#cloud-config

hostname: metal-{{ trunc 4 .MachineID }}
users:
- name: kairos
  passwd: kairos
  groups:
    - admin

k3s-agent: # Warning: the key is different from the master node one
  enabled: true
  args:
    - --with-node-id # will configure the agent to use the node ID to communicate with the master node
  env:
    K3S_TOKEN: "<MASTER_SERVER_TOKEN>" # /var/lib/rancher/k3s/server/node-token from the master node
    K3S_URL: https://<MASTER_SERVER_IP>:6443 # Same IP that you use to log into your master node
```

Replace <MASTER_SERVER_IP> and <MASTER_SERVER_TOKEN> with the values you found
on the previous step.

## Verify that it works

If everything worked correctly, you should be able to see both nodes when you run
the following on the master node:

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
```

✅ Done! 🎉
