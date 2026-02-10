# Stage 5: Deploying a multi-node cluster (MacOS)

Docs:
  - [Manual Multi-Node Cluster](https://kairos.io/docs/examples/multi-node/)

## Overview

In this stage, we'll create a 2-node Kubernetes cluster:
- **Master node**: Control plane (existing VM from previous stages)
- **Worker node**: New VM that joins the cluster

## Challenge: QEMU Networking on MacOS

QEMU's default usermode networking (`-netdev user`) isolates each VM - they can reach the internet but **cannot communicate with each other directly**.

### Solution: Host Gateway for K3s API

While QEMU socket multicast can provide VM-to-VM connectivity for ping/ICMP, it has issues with TLS traffic (like K3s API). The working solution is:

1. **Master** exposes K3s API to the host via port forwarding (`hostfwd=tcp::6444-:6443`)
2. **Worker** connects to master via host gateway (`10.0.2.2:6444`)

```
┌─────────────────┐                      ┌─────────────────┐
│   Master VM     │◄──hostfwd:6444───────│   MacOS Host    │
│  K3s Server     │                      │   10.0.2.2      │
└─────────────────┘                      └────────┬────────┘
                                                  │
                                                  ▼
                                         ┌─────────────────┐
                                         │   Worker VM     │
                                         │  K3s Agent      │
                                         │ connects to     │
                                         │ 10.0.2.2:6444   │
                                         └─────────────────┘
```

## Prerequisites

- Completed [Stage 1](stage-1-macos.md) with a working Kairos VM
- At least 12GB RAM available (8GB master + 4GB worker)
- A Kairos ISO for the worker (can be different from master, e.g., Fedora)
- Two terminal windows

## Step 1: Configure the Master Node

### Start Master VM

If your master VM is not running, start it with the launcher script:

```bash
cd macos/local-infra

# Start master (uses kairos.qcow2 by default)
./start-master.sh

# Or with a custom disk:
./start-master.sh --disk kairos-custom.qcow2
```

The script automatically forwards:
- `2226` → SSH
- `6444` → K3s API (6443 inside VM)
- `8080` → Web installer

### Configure K3s to Accept External Connections

SSH into master and configure K3s TLS SANs:

```bash
sshpass -p 'kairos' ssh -p 2226 kairos@localhost

# Add TLS SANs for external access
echo 'tls-san:
  - 10.0.2.2
  - 10.0.2.15
  - 127.0.0.1
  - localhost' | sudo tee /etc/rancher/k3s/config.yaml

# Restart K3s to regenerate certificates
sudo systemctl restart k3s
```

### Get the K3s Token

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

Save this token - you'll need it for the worker.

Example:
```
K1083a223a964a715d8263ec2e81f8183d704d4b7933123f42def852bbea0becd2c::server:1cd63fa47a5805a4c6b994fa7a85c500
```

### Verify K3s API is Accessible

From your **Mac host**:

```bash
curl -sk https://localhost:6444/version
```

Should return a JSON response (401 Unauthorized is OK - means API is reachable).

## Step 2: Start the Worker Node

### Download Worker ISO (if needed)

If you want to use a different OS for the worker (e.g., Fedora):

```bash
cd macos/local-infra

# Download Fedora-based Kairos ISO
curl -LO https://github.com/kairos-io/kairos/releases/download/v3.7.1/kairos-fedora-40-standard-arm64-generic-v3.7.1-k3sv1.35.0+k3s1.iso
mv kairos-fedora-40-standard-arm64-generic-v3.7.1-k3sv1.35.0+k3s1.iso kairos-fedora.iso
```

### Start Worker VM

In a **new terminal**:

```bash
cd macos/local-infra

# Create disk and boot from ISO
./start-worker.sh --iso kairos-fedora.iso --create-disk

# Or use existing ISO:
./start-worker.sh --iso kairos.iso --create-disk
```

The script will:
- Create `kairos-worker.qcow2` (60GB)
- Boot with 4GB RAM
- Forward SSH to port 2225

### Install Worker

1. At the GRUB menu, select **Kairos** (remove `nomodeset` if display issues)

2. Once booted to live environment, SSH in:
   ```bash
   sshpass -p 'kairos' ssh -p 2225 -o StrictHostKeyChecking=no kairos@localhost
   ```

3. Verify connectivity to master's K3s API via host:
   ```bash
   curl -sk https://10.0.2.2:6444/cacerts | head -3
   ```
   Should show certificate data.

4. Create and apply the cloud-config:
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
       K3S_URL: "https://10.0.2.2:6444"
   EOF
   ```

   > [!IMPORTANT]
   > Replace `<PASTE_TOKEN_HERE>` with the token from the master node.

5. Install:
   ```bash
   sudo kairos-agent manual-install config.yaml
   ```

6. After installation completes, the VM will reboot automatically.

### Post-Install: Restart Worker from Disk

After the reboot, restart the worker without the ISO:

```bash
cd macos/local-infra
./start-worker.sh
```

### Post-Install: Configure K3s Agent (if needed)

If the K3s agent doesn't start automatically with the right config, manually create the environment file:

```bash
sshpass -p 'kairos' ssh -p 2225 kairos@localhost

# Create K3s agent environment file
echo 'K3S_URL=https://10.0.2.2:6444
K3S_TOKEN=<PASTE_TOKEN_HERE>' | sudo tee /etc/systemd/system/k3s-agent.service.env

sudo systemctl daemon-reload
sudo systemctl restart k3s-agent
```

## Step 3: Verify the Cluster

On the **master node**:

```bash
sshpass -p 'kairos' ssh -p 2226 kairos@localhost

sudo kubectl get nodes -o wide
```

Expected output:
```
NAME                     STATUS   ROLES           AGE     VERSION        INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                            KERNEL-VERSION            CONTAINER-RUNTIME
kairos-479e              Ready    control-plane   3d12h   v1.35.0+k3s3   10.0.2.15       <none>        Ubuntu 22.04.5 LTS                  6.8.0-94-generic          containerd://2.1.5-k3s1
kairos-worker-ec386546   Ready    <none>          5m      v1.35.0+k3s1   10.0.2.15       <none>        Fedora Linux 40 (Container Image)   6.14.5-100.fc40.aarch64   containerd://2.1.5-k3s1
```

### Test Workload Distribution

```bash
# Create a deployment with multiple replicas
sudo kubectl create deployment nginx --image=nginx --replicas=4

# Check pod distribution across nodes
sudo kubectl get pods -o wide
```

You should see pods scheduled on both nodes.

## Multiple Workers

You can add more workers using the `--name` and `--ssh-port` options:

```bash
# Second worker
./start-worker.sh --name worker2 --ssh-port 2227 --iso kairos-fedora.iso --create-disk

# Third worker
./start-worker.sh --name worker3 --ssh-port 2228 --iso kairos-fedora.iso --create-disk
```

Each worker will have its own disk (`kairos-worker2.qcow2`, `kairos-worker3.qcow2`) and SSH port.

## Script Options Reference

### Master (`start-master.sh`)

```bash
./start-master.sh [OPTIONS]

Options:
  --disk PATH       Disk image (default: kairos.qcow2)
  --iso PATH        Boot from ISO
  --create-disk     Create disk if missing
  --memory MB       Memory (default: 8192)
  --cpus N          CPUs (default: 2)

Ports: SSH=2226, K3s=6444, Web=8080
```

### Worker (`start-worker.sh`)

```bash
./start-worker.sh [OPTIONS]

Options:
  --disk PATH       Disk image (default: kairos-worker.qcow2)
  --iso PATH        Boot from ISO
  --create-disk     Create disk if missing
  --memory MB       Memory (default: 4096)
  --cpus N          CPUs (default: 2)
  --ssh-port PORT   SSH port (default: 2225)
  --name NAME       Worker name (default: worker)

Port: SSH=2225 (or custom)
```

## Troubleshooting

### Worker not joining cluster

1. Check K3s agent logs:
   ```bash
   sshpass -p 'kairos' ssh -p 2225 kairos@localhost
   sudo journalctl -u k3s-agent -f
   ```

2. Verify connectivity to master API:
   ```bash
   curl -sk https://10.0.2.2:6444/cacerts
   ```

3. Check environment file exists:
   ```bash
   sudo cat /etc/systemd/system/k3s-agent.service.env
   ```

### "Connection refused" to master API

Ensure master VM is running with port forwarding:

```bash
# Check QEMU process has port forwarding
ps aux | grep qemu | grep 6444
```

If missing, restart master with the script (which includes proper forwarding).

### Worker shows wrong K3S_URL in logs

The K3s agent may have cached old config. Clear it:

```bash
sudo rm -rf /var/lib/rancher/k3s/agent
sudo systemctl restart k3s-agent
```

### TLS certificate errors

Regenerate master certificates with correct SANs:

```bash
# On master
sudo rm /var/lib/rancher/k3s/server/tls/serving-kube-apiserver.*
sudo systemctl restart k3s
```

## Cleanup

To remove the worker and return to single-node:

```bash
# On master
sshpass -p 'kairos' ssh -p 2226 kairos@localhost
sudo kubectl delete node kairos-worker-xxxxx

# Stop worker VM (close QEMU window or Ctrl+C)

# Optionally remove the disk
cd macos/local-infra
rm kairos-worker.qcow2
```

## Summary

| Node | Role | SSH Port | Memory | Script |
|------|------|----------|--------|--------|
| Master | control-plane | 2226 | 8GB | `./start-master.sh` |
| Worker | worker | 2225 | 4GB | `./start-worker.sh` |

Key insight: QEMU socket multicast has issues with TLS traffic, so we use the **host gateway** (`10.0.2.2`) with port forwarding for K3s API communication.

## Next Steps

→ [Stage 6: Kubernetes-based Upgrades](stage-6-macos.md)

---

✅ Done! 🎉
