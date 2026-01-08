# Stage 6: Upgrading your cluster through Kubernetes

Docs:
    - [Kairos Operator README](https://github.com/kairos-io/kairos-operator)

For this exercise, you can use any of the cluster you created in the previous
stages (multi-node or single-node).

## Deploy the kairos operator

The following command needs `git` to be in the PATH. If you added `git` to your
Kairos image as per the example on [stage-2](stage-2.md), you should be able to
issue this command from withing the master node. Otherwise, you'll need to copy
the k3s kubeconfig (`/etc/rancher/k3s/k3s.yaml`) to your host machine (assuming
`git` is available there), change the values in the file to point to the IP address
of the master node and issue the command from your host machine.

Depending on your network setup, hypervisor, etc, your mileage might vary.

```bash
kubectl apply -k https://github.com/kairos-io/kairos-operator/config/default
```
