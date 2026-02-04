# Stage 6: Upgrading your cluster through Kubernetes

Docs:
  - [Kairos Operator README](https://github.com/kairos-io/kairos-operator)

For this exercise, you can use any of the clusters you created in the previous
stages (multi-node or single-node).

## Deploy the kairos operator

The following command needs `git` to be in the PATH. If you added `git` to your
Kairos image as per the example on [stage-2](stage-2.md), you should be able to
issue this command from withing the master node. Otherwise, you'll need to copy
the k3s kubeconfig (`/etc/rancher/k3s/k3s.yaml`) to your host machine (assuming
`git` is available there), change the values in the file to point to the IP address
of the master node and issue the command from your host machine.

Depending on your network setup, hypervisor, etc, your mileage might vary.

If you have `git` available, you can install the Kairos operator with the following command:

```bash
kubectl apply -k https://github.com/kairos-io/kairos-operator/config/default
```

### Alternative: Without git (e.g., Hadron-based images)

If you're using a Hadron-based image (or any image without `git`), you can download
the kairos-operator tarball directly with `curl` and apply it:

```bash
# Download and extract the kairos-operator
curl -sL https://github.com/kairos-io/kairos-operator/archive/refs/heads/main.tar.gz | tar -xz -C /tmp

# Deploy the operator
kubectl apply -k /tmp/kairos-operator-main/config/default
```

This method uses `curl` (which is available on Hadron) instead of `git`.

### Alternative: Copy from host

Another workaround is to clone the [kairos-operator repository](https://github.com/kairos-io/kairos-operator) to your host system and then `scp` the directory inside the virtual machine. Then install the kairos-operator using the following command from the root directory of the repository:

```bash
kubectl apply -k config/default
```

## Upgrading using Kubernetes Resources

The operator acts on 2 types of Custom Resources: NodeOp and NodeOpUpgrade. In this
example, we'll use the NodeOpUpgrade which is specifically designed for upgrading
Kairos.

Create a yaml file similar to the following, replacing the `spec.image` value
with the image you intend to upgrade to. Also check the rest of the options to see
what's possible.

```yaml
apiVersion: operator.kairos.io/v1alpha1
kind: NodeOpUpgrade
metadata:
  name: kairos-upgrade
  namespace: default
spec:
  # The container image containing the new Kairos version
  image: quay.io/kairos/opensuse:leap-15.6-standard-amd64-generic-v3.4.2-k3sv1.30.11-k3s1

  # NodeSelector to target specific nodes (optional)
  nodeSelector:
    matchLabels:
      kairos.io/managed: "true"

  # Maximum number of nodes that can run the upgrade simultaneously
  # 0 means run on all nodes at once
  concurrency: 1

  # Whether to stop creating new jobs when a job fails
  # Useful for canary deployments
  stopOnFailure: true

  # Whether to upgrade the active partition (defaults to true)
  # upgradeActive: true

  # Whether to upgrade the recovery partition (defaults to false)
  # upgradeRecovery: false

  # Whether to force the upgrade without version checks
  # force: false
```

Start the upgrade by applying the above yaml file:

```bash
kubectl apply -f upgrade.yaml
```

If everything works as expected, you should see the Node being cordoned, upgraded,
rebooted and eventually un-cordoned and ready to be used again. It's important to
upgrade to an image that has a compatible kubernetes version otherwise the node
may fail to connect to the cluster (e.g. downgrading kubernetes version might not work).

✅ Done! 🎉
