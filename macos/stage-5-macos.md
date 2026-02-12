# Stage 5: Deploying a multi-node cluster (MacOS)

Docs:
  - [Manual Multi-Node Cluster](https://kairos.io/docs/examples/multi-node/)

## Overview

In this stage, we'll create a 2-node Kubernetes cluster:
- **Master node**: Control plane (existing VM from previous stages)
- **Worker node**: New VM that joins the cluster

With **vmnet-bridged** networking, both VMs get real IPs on your local network and can communicate directly.

```
┌─────────────────┐         ┌─────────────────┐
│   Master VM     │◄───────►│   Worker VM     │
│  192.168.20.150 │  Direct │  192.168.20.151 │
│  K3s Server     │  Access │  K3s Agent      │
└─────────────────┘         └─────────────────┘
         ▲                           ▲
         │      Local Network        │
         └───────────┬───────────────┘
                     │
              ┌──────┴──────┐
              │  MacOS Host │
              │192.168.20.x │
              └─────────────┘
```

## Prerequisites

- Completed [Stage 1](stage-1-macos.md) with a working Kairos master VM
- At least 12GB RAM available (8GB master + 4GB worker)
- A Kairos ISO for the worker (can be different from master)
- Two terminal windows

## Step 1: Ensure Master is Running

If your master VM is not running, start it using the [QEMU command from Stage 1](stage-1-macos.md#post-installation-boot-from-disk).

Find the master's IP:

```bash
arp -a | grep -i "52:54"
# Example: 192.168.20.150
```

## Step 2: Get the K3s Token

SSH into the master and get the join token:

```bash
ssh kairos@192.168.20.150

sudo cat /var/lib/rancher/k3s/server/node-token
```

Save this token - you'll need it for the worker.

Example:
```
K1083a223a964a715d8263ec2e81f8183d704d4b7933123f42def852bbea0becd2c::server:1cd63fa47a5805a4c6b994fa7a85c500
```

## Step 3: Start the Worker VM

### Create Worker Disk

In a **new terminal**:

```bash
cd macos/local-infra
qemu-img create -f qcow2 kairos-worker.qcow2 60G
```

### Boot Worker VM

Use the [QEMU command from Stage 1](stage-1-macos.md#2-boot-from-iso) with these changes:
- `-m 4096` (workers need less RAM)
- `-drive file=kairos-worker.qcow2,if=virtio,format=qcow2`
- `-cdrom kairos.iso` (same ISO as master, or a different flavor)

## Step 4: Install Worker

1. At GRUB menu, select **Kairos**

2. Find worker's IP and SSH in:
   ```bash
   # From Mac - find the new VM's IP
   arp -a | grep -i "52:54"
   # Example: 192.168.20.151 (different from master)

   ssh kairos@192.168.20.151
   # Password: kairos
   ```

3. Verify connectivity to master:
   ```bash
   # Replace with your master's IP
   curl -sk https://192.168.20.150:6443/cacerts | head -3
   ```
   Should show certificate data.

4. Create the worker cloud-config (note: uses `k3s-agent` instead of `k3s`, see [Stage 1](stage-1-macos.md#3-create-configuration) for the master config):
   ```bash
   cat > config.yaml <<'EOF'
   #cloud-config
   hostname: kairos-worker

   users:
     - name: kairos
       passwd: kairos
       groups:
         - admin

   k3s-agent:
     enabled: true
     args:
       - --with-node-id
     env:
       K3S_TOKEN: "<PASTE_TOKEN_HERE>"
       K3S_URL: "https://<MASTER_IP>:6443"
   EOF
   ```

   > [!IMPORTANT]
   > - Replace `<PASTE_TOKEN_HERE>` with the token from master
   > - Replace `<MASTER_IP>` with your master's actual IP (e.g., `192.168.20.150`)

5. Install:
   ```bash
   sudo kairos-agent manual-install config.yaml
   ```

6. The VM will reboot after installation.

## Step 5: Boot Worker from Disk

After reboot, start the worker without ISO using the [QEMU command from Stage 1](stage-1-macos.md#post-installation-boot-from-disk) with:
- `-m 4096`
- `-drive file=kairos-worker.qcow2,if=virtio,format=qcow2`

## Step 6: Verify the Cluster

On the **master node**:

```bash
ssh kairos@192.168.20.150

sudo kubectl get nodes -o wide
```

Expected output:
```
NAME                     STATUS   ROLES           AGE     VERSION        INTERNAL-IP      OS-IMAGE
kairos-xxxx              Ready    control-plane   1d      v1.35.0+k3s1   192.168.20.150   Ubuntu 22.04.5 LTS
kairos-worker-xxxx       Ready    <none>          5m      v1.35.0+k3s1   192.168.20.151   Fedora Linux 40
```

### Test Workload Distribution

```bash
# Create a deployment with multiple replicas
sudo kubectl create deployment nginx --image=nginx --replicas=4

# Check pod distribution across nodes
sudo kubectl get pods -o wide
```

You should see pods scheduled on both nodes.

## Adding More Workers

For additional workers, repeat Steps 3-5 with different disk names (e.g., `kairos-worker2.qcow2`). Each worker will get a unique IP from DHCP.

## Troubleshooting

### Worker not joining cluster

1. Check K3s agent logs:
   ```bash
   ssh kairos@192.168.20.151
   sudo journalctl -u k3s-agent -f
   ```

2. Verify connectivity to master:
   ```bash
   curl -sk https://192.168.20.150:6443/cacerts
   ```

3. Check the agent environment:
   ```bash
   sudo cat /etc/systemd/system/k3s-agent.service.env
   ```

### Worker can't reach master

Verify both VMs are on the same network:

```bash
# From worker
ping 192.168.20.150
```

If ping fails, check both VMs are using `vmnet-bridged` with the same interface.

### TLS certificate errors

The master's K3s certificates include its IP by default. If you changed the master's IP, regenerate certs:

```bash
# On master
sudo rm /var/lib/rancher/k3s/server/tls/serving-kube-apiserver.*
sudo systemctl restart k3s
```

### Wrong K3S_URL in agent config

If the agent has wrong URL cached:

```bash
# On worker
sudo rm -rf /var/lib/rancher/k3s/agent
sudo systemctl restart k3s-agent
```

## Cleanup

To remove a worker:

```bash
# On master
ssh kairos@192.168.20.150
sudo kubectl delete node kairos-worker-xxxx

# Stop worker VM (close QEMU window)

# Remove disk
cd macos/local-infra
rm kairos-worker.qcow2
```

## Summary

| Node | Role | IP (example) | Memory |
|------|------|--------------|--------|
| Master | control-plane | 192.168.20.150 | 8GB |
| Worker | worker | 192.168.20.151 | 4GB |

With vmnet-bridged networking, VMs get real IPs and can communicate directly - no port forwarding or host gateway workarounds needed.

## Next Steps

→ [Stage 6: Kubernetes-based Upgrades](stage-6-macos.md)

---

✅ Done! 🎉
