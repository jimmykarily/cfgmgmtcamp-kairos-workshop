# Stage 6: Upgrading your cluster through Kubernetes (MacOS)

Docs:
  - [Kairos Operator README](https://github.com/kairos-io/kairos-operator)

## Overview

In this final stage, we'll use the **Kairos Operator** to manage OS upgrades through Kubernetes. Instead of manually running `kairos-agent upgrade` on each node (Stage 4), the operator automates the process:

1. Cordons the node (prevents new workloads)
2. Performs the upgrade
3. Reboots the node
4. Uncordons the node

This is ideal for managing upgrades across multiple nodes in a cluster.

## Prerequisites

- Working Kairos cluster (single or multi-node from previous stages)
- `kubectl` access from your Mac (via kubeconfig)
- Cluster nodes can reach external registries (quay.io)

### Important: Verify K3s Network Configuration

> [!CAUTION]
> **If you experimented with socket multicast networking in Stage 5** before switching to host port forwarding, your K3s configuration may have stale network settings that will cause upgrades to fail.

Before proceeding with operator-based upgrades, verify your K3s configuration doesn't have outdated `node-ip` settings:

```bash
sshpass -p 'kairos' ssh -p 2226 kairos@localhost "sudo cat /etc/rancher/k3s/config.yaml"
```

**Problematic configuration** (contains `node-ip` pointing to old socket multicast network):
```yaml
tls-san:
  - 192.168.100.1    # Old socket multicast IP
  - 10.0.2.15
node-ip: 192.168.100.1  # THIS WILL CAUSE K3S TO FAIL!
```

**Correct configuration** (for host port forwarding setup):
```yaml
tls-san:
  - 10.0.2.2      # Host gateway (for worker access)
  - 10.0.2.15     # VM's actual IP
  - 127.0.0.1
  - localhost
```

If you have the problematic configuration, fix it before proceeding:

```bash
sshpass -p 'kairos' ssh -p 2226 kairos@localhost "sudo tee /etc/rancher/k3s/config.yaml << 'EOF'
tls-san:
  - 10.0.2.2
  - 10.0.2.15
  - 127.0.0.1
  - localhost
EOF"

# Restart K3s to apply the changes
sshpass -p 'kairos' ssh -p 2226 kairos@localhost "sudo systemctl restart k3s"
```

### Verify Cluster Access

From your Mac:

```bash
export KUBECONFIG=~/.kube/config-kairos
kubectl get nodes
```

Or from inside the master VM:

```bash
sshpass -p 'kairos' ssh -p 2226 kairos@localhost
sudo kubectl get nodes
```

## Step 1: Deploy the Kairos Operator

### Option A: From Mac Host (Recommended)

If you have `git` installed on your Mac and kubeconfig configured:

```bash
export KUBECONFIG=~/.kube/config-kairos

# Install the Kairos operator
kubectl apply -k https://github.com/kairos-io/kairos-operator/config/default
```

### Option B: From Inside the VM (without git)

If your Kairos image doesn't have `git`, use `curl` instead:

```bash
sshpass -p 'kairos' ssh -p 2226 kairos@localhost

# Download and extract the kairos-operator
curl -sL https://github.com/kairos-io/kairos-operator/archive/refs/heads/main.tar.gz | tar -xz -C /tmp

# Deploy the operator
sudo kubectl apply -k /tmp/kairos-operator-main/config/default
```

### Verify Operator Deployment

```bash
kubectl -n kairos-operator-system get pods
```

Expected output:
```
NAME                                               READY   STATUS    RESTARTS   AGE
kairos-operator-controller-manager-xxxxx-xxxxx     2/2     Running   0          30s
```

Wait for the pod to be `Running` before proceeding.

## Step 2: Label Nodes for Upgrade

The operator uses labels to select which nodes to upgrade. Add the management label:

```bash
# Label all nodes for management by the operator
kubectl label nodes --all kairos.io/managed=true

# Verify labels
kubectl get nodes --show-labels | grep kairos.io/managed
```

## Step 3: Create Upgrade Resource

### Check Available Images

First, check what upgrade images are available for your architecture on each node:

```bash
# On master
sshpass -p 'kairos' ssh -p 2226 kairos@localhost "sudo kairos-agent upgrade list-releases"

# On worker
sshpass -p 'kairos' ssh -p 2225 kairos@localhost "sudo kairos-agent upgrade list-releases"
```

> [!NOTE]
> **Example from our multi-node cluster:**
> 
> **Master (Ubuntu 22.04 - already at latest):**
> ```
> Using registry: quay.io/kairos
> Current image:
> quay.io/kairos/ubuntu:22.04-standard-arm64-generic-v3.7.2-k3sv1.35.0-k3s3
> 
> Available releases with higher version:
> No newer releases found
> ```
> 
> **Worker (Fedora 40 - upgrades available):**
> ```
> Using registry: quay.io/kairos
> Current image:
> quay.io/kairos/fedora:40-standard-arm64-generic-v3.7.1-k3sv1.35.0-k3s1
> 
> Available releases with higher version:
> quay.io/kairos/fedora:40-standard-arm64-generic-v3.7.2-k3s-v1.33.7-k3s3
> quay.io/kairos/fedora:40-standard-arm64-generic-v3.7.2-k3s-v1.34.3-k3s3
> quay.io/kairos/fedora:40-standard-arm64-generic-v3.7.2-k3s-v1.35.0-k3s3
> ```
> 
> Notice how each node shows different available images based on its OS flavor (Ubuntu vs Fedora). The operator can upgrade different nodes to their respective flavor's latest version.

### Create the Upgrade YAML

Create an upgrade manifest targeting ARM64 images:

```bash
cat > upgrade.yaml <<'EOF'
apiVersion: operator.kairos.io/v1alpha1
kind: NodeOpUpgrade
metadata:
  name: kairos-upgrade
  namespace: default
spec:
  # ARM64 Ubuntu image - adjust version as needed
  image: quay.io/kairos/ubuntu:22.04-standard-arm64-generic-v3.7.2-k3s-v1.35.0-k3s3

  # Target nodes with this label
  nodeSelector:
    matchLabels:
      kairos.io/managed: "true"

  # Upgrade one node at a time (safe for multi-node clusters)
  concurrency: 1

  # Stop if an upgrade fails
  stopOnFailure: true

  # Upgrade the active partition
  upgradeActive: true

  # Don't upgrade recovery partition (faster)
  upgradeRecovery: false
EOF
```

> [!IMPORTANT]
> - Use ARM64 images for Apple Silicon Macs
> - Ensure K3s version is compatible with your cluster

## Step 4: Apply the Upgrade

```bash
kubectl apply -f upgrade.yaml
```

### Monitor the Upgrade

Watch the upgrade progress:

```bash
# Watch NodeOpUpgrade status
kubectl get nodeopupgrade -w

# Watch nodes (will show cordoning/rebooting)
kubectl get nodes -w

# Check operator logs
kubectl -n kairos-operator-system logs -f deployment/kairos-operator-controller-manager
```

### What Happens During Upgrade

1. **Node Cordoned** - No new pods scheduled
2. **Upgrade Job Created** - Pulls new image and writes to passive partition
3. **Node Reboots** - Boots into upgraded OS
4. **Node Uncordoned** - Returns to Ready state

Example timeline:
```
NAME            STATUS                     AGE
kairos-479e     Ready,SchedulingDisabled   0s    # Cordoned
kairos-479e     NotReady                   30s   # Rebooting
kairos-479e     Ready                      90s   # Upgrade complete
```

## Step 5: Verify the Upgrade

After the upgrade completes:

```bash
# Check node status
kubectl get nodes -o wide

# SSH into upgraded node and verify version
sshpass -p 'kairos' ssh -p 2226 kairos@localhost \
  "cat /etc/kairos-release | grep KAIROS_VERSION"
```

Expected output:
```
KAIROS_VERSION="v3.7.2"
```

## Upgrade Strategies

### Single Node Cluster

For single-node clusters, the upgrade will briefly make the cluster unavailable during reboot:

```yaml
spec:
  concurrency: 1  # Only option for single node
```

### Multi-Node Cluster

For multi-node clusters, you can control rollout:

```yaml
spec:
  # Upgrade one at a time (safest)
  concurrency: 1
  
  # Or upgrade all at once (faster but riskier)
  # concurrency: 0
```

### Canary Deployment

Upgrade a subset of nodes first by using specific labels:

```bash
# Label canary nodes
kubectl label node kairos-worker-xxxxx kairos.io/canary=true

# Create upgrade targeting only canary nodes
cat > upgrade-canary.yaml <<'EOF'
apiVersion: operator.kairos.io/v1alpha1
kind: NodeOpUpgrade
metadata:
  name: kairos-canary-upgrade
spec:
  image: quay.io/kairos/ubuntu:22.04-standard-arm64-generic-v3.7.2-k3s-v1.35.0-k3s3
  nodeSelector:
    matchLabels:
      kairos.io/canary: "true"
  concurrency: 1
  stopOnFailure: true
EOF

kubectl apply -f upgrade-canary.yaml
```

## Troubleshooting

### Upgrade Job Fails

Check the job logs:

```bash
# Find the upgrade job
kubectl get jobs -A | grep upgrade

# Check job logs
kubectl logs job/<job-name> -n <namespace>
```

### Node Stuck in NotReady

If a node doesn't come back after reboot:

1. Check VM console (QEMU window) for boot errors
2. Try booting to fallback partition (GRUB menu)
3. Check K3s agent logs after boot:
   ```bash
   sudo journalctl -u k3s-agent -f  # For worker
   sudo journalctl -u k3s -f        # For master
   ```

### Rollback an Upgrade

The Kairos operator doesn't have automatic rollback. To rollback:

1. Reboot the node
2. Select **"Kairos (fallback)"** in GRUB menu
3. Once booted, the node should rejoin the cluster with the previous version

### Delete a Stuck Upgrade

```bash
kubectl delete nodeopupgrade kairos-upgrade
```

### Upgrade Stuck with Node Cordoned (SchedulingDisabled)

If your upgrade gets stuck with the node showing `Ready,SchedulingDisabled` and the NodeOpUpgrade status shows `rebootStatus: pending`, this typically means K3s crashed during the upgrade process.

**Common cause**: Stale `node-ip` configuration pointing to a non-existent network interface (e.g., from previous socket multicast experiments).

**Symptoms**:
```bash
kubectl get nodes
# NAME          STATUS                     ROLES           AGE
# kairos-479e   Ready,SchedulingDisabled   control-plane   3d   # Stuck!

kubectl get nodeopupgrade kairos-upgrade -o yaml | grep -A5 nodeStatuses
# nodeStatuses:
#   kairos-479e:
#     phase: Completed
#     rebootStatus: pending    # Stuck waiting for reboot!
```

**Resolution**:

1. **Fix the K3s configuration** (see [Prerequisites](#important-verify-k3s-network-configuration)):
   ```bash
   sshpass -p 'kairos' ssh -p 2226 kairos@localhost "sudo tee /etc/rancher/k3s/config.yaml << 'EOF'
   tls-san:
     - 10.0.2.2
     - 10.0.2.15
     - 127.0.0.1
     - localhost
   EOF"
   
   sshpass -p 'kairos' ssh -p 2226 kairos@localhost "sudo systemctl restart k3s"
   ```

2. **Wait for K3s to stabilize**, then clean up the stuck resources:
   ```bash
   # Delete the stuck upgrade
   kubectl delete nodeopupgrade kairos-upgrade
   
   # Force delete the reboot pod if it exists
   kubectl delete pod -l kairos.io/reboot=true --force --grace-period=0
   
   # Uncordon the node
   kubectl uncordon kairos-479e  # Use your actual node name
   ```

3. **Restart any pods stuck in CrashLoopBackOff**:
   ```bash
   kubectl rollout restart deployment -n argo
   kubectl rollout restart deployment -n kube-system
   ```

4. **Clean up error pods in operator-system**:
   ```bash
   kubectl -n operator-system delete pod --field-selector=status.phase=Failed
   ```

### K3s Fails to Start After Reboot

If K3s won't start after an upgrade reboot, check the logs:

```bash
sshpass -p 'kairos' ssh -p 2226 kairos@localhost "sudo journalctl -u k3s --no-pager -n 50"
```

**Look for errors like**:
```
level=error msg="Sending HTTP/2.0 503 response..."
external host was not specified, using 192.168.100.1  # Wrong IP!
```

This indicates K3s is trying to use an IP that doesn't exist on any interface. Fix the `/etc/rancher/k3s/config.yaml` as described above.

### Upgrade Completed but rebootStatus Still "pending"

In some cases, the node reboots successfully and the upgrade completes, but the operator doesn't detect the reboot completion. You'll see:

**Symptoms**:
```bash
kubectl get nodes
# NAME                     STATUS   ROLES           AGE
# kairos-worker-ec386546   Ready,SchedulingDisabled   <none>   10h   # Still cordoned!

kubectl get nodeopupgrade kairos-upgrade -o yaml | grep -A8 'status:'
# status:
#   message: Upgrade operation is running
#   phase: Running
#   nodeStatuses:
#     kairos-worker-ec386546:
#       phase: Completed
#       rebootStatus: pending    # Stuck here despite successful reboot!
```

The node is `Ready` (rebooted successfully), the K3s version is updated, but `rebootStatus` is stuck at `pending`.

**Root Cause**: The reboot pod sets a `kairos.io/reboot-state: completed` annotation on itself just before triggering the reboot. The operator watches for this annotation to confirm the reboot was intentional. If the reboot happens too quickly (race condition), the annotation may not be persisted before the pod terminates.

**Diagnosis**:

1. Check if the reboot pod completed:
   ```bash
   kubectl get pods -l kairos.io/reboot=true
   # NAME                            READY   STATUS      RESTARTS   AGE
   # kairos-upgrade-reboot-xxxxx     0/1     Completed   0          10m
   ```

2. Check if the annotation is missing:
   ```bash
   kubectl get pod kairos-upgrade-reboot-xxxxx -o jsonpath='{.metadata.annotations}'
   # {} or missing kairos.io/reboot-state
   ```

3. Check operator logs showing "No available slots":
   ```bash
   kubectl -n operator-system logs deployment/operator-kairos-operator --tail=20
   # DEBUG  No available slots for new jobs  {"running": 1, "maxConcurrency": 1}
   ```

**Resolution**: Manually patch the reboot pod with the missing annotation:

```bash
# Find the reboot pod name
REBOOT_POD=$(kubectl get pods -l kairos.io/reboot=true -o jsonpath='{.items[0].metadata.name}')

# Patch it with the completed annotation
kubectl patch pod $REBOOT_POD -p '{"metadata":{"annotations":{"kairos.io/reboot-state":"completed"}}}'
```

The operator will immediately detect the annotation and:
1. Update `rebootStatus` to `completed`
2. Update the upgrade `phase` to `Completed`
3. Uncordon the node

Verify:
```bash
kubectl get nodes
# NAME                     STATUS   ROLES    AGE
# kairos-worker-ec386546   Ready    <none>   10h   # No longer SchedulingDisabled!

kubectl get nodeopupgrade kairos-upgrade -o jsonpath='{.status.phase}'
# Completed
```

> [!NOTE]
> This appears to be an edge case in the Kairos Operator. The operator should ideally have better detection of reboot completion (e.g., checking node boot time or implementing a timeout). Consider reporting this issue to the [kairos-operator repository](https://github.com/kairos-io/kairos-operator/issues).

## Cleanup

Remove the operator when no longer needed:

```bash
kubectl delete -k https://github.com/kairos-io/kairos-operator/config/default
```

## Summary

The Kairos Operator provides:

| Feature | Benefit |
|---------|---------|
| **Automated Upgrades** | No manual SSH to each node |
| **Controlled Rollout** | Concurrency settings for safe upgrades |
| **Kubernetes Native** | Manage OS like any other K8s resource |
| **Node Cordoning** | Graceful workload migration |

### Complete Workshop Flow

1. **Stage 1**: Boot and install Kairos VM
2. **Stage 2**: Build custom Kairos image
3. **Stage 3**: CI/CD with Argo Workflows + Gitea
4. **Stage 4**: Manual upgrade with `kairos-agent`
5. **Stage 5**: Multi-node cluster setup
6. **Stage 6**: Kubernetes-based upgrades with operator

---

✅ Workshop Complete! 🎉

You now have a fully functional local Kairos development environment on MacOS with:
- Custom image building
- Automated CI/CD pipelines
- Multi-node cluster management
- Kubernetes-native OS upgrades
