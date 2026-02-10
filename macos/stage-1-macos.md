# Stage 1: Deploying a Single Node Cluster (MacOS)

This guide walks through deploying a Kairos single-node Kubernetes cluster on MacOS using **QEMU**.

Docs:
  - [Manual Single-Node Cluster](https://kairos.io/docs/examples/single-node/)

## Prerequisites

### Install QEMU

```bash
brew install qemu
```

Verify installation:

```bash
qemu-system-aarch64 --version
qemu-img --version
```

### Install sshpass (optional, for easier SSH)

```bash
brew install hudochenkov/sshpass/sshpass
```

## Get a Pre-built ISO

Since MacOS on Apple Silicon is ARM-based, download the **aarch64** (arm64) ISO:

- [kairos-fedora-40-standard-arm64-generic-v3.7.1-k3sv1.35.0+k3s1.iso](https://github.com/kairos-io/kairos/releases/download/v3.7.1/kairos-fedora-40-standard-arm64-generic-v3.7.1-k3sv1.35.0+k3s1.iso) (514M) — Recommended
- [kairos-hadron-0.0.1-standard-arm64-generic-v3.7.1-k3sv1.35.0+k3s1.iso](https://github.com/kairos-io/kairos/releases/download/v3.7.1/kairos-hadron-0.0.1-standard-arm64-generic-v3.7.1-k3sv1.35.0+k3s1.iso) (357M) — Smaller, minimal image

```bash
# Navigate to the local-infra directory
cd macos/local-infra

# Download the Fedora-based Kairos ISO
curl -LO https://github.com/kairos-io/kairos/releases/download/v3.7.1/kairos-fedora-40-standard-arm64-generic-v3.7.1-k3sv1.35.0+k3s1.iso

# Rename for convenience
mv kairos-fedora-40-standard-arm64-generic-v3.7.1-k3sv1.35.0+k3s1.iso kairos.iso
```

> [!NOTE]
> The Fedora-based image is recommended as it has better driver support for virtualized environments.

## Create and Boot the VM

We provide helper scripts to manage QEMU VMs easily. See [local-infra/README.md](local-infra/README.md) for details.

### 1. Boot the VM with ISO

```bash
cd macos/local-infra

# Create disk and boot from ISO for fresh install
./start-master.sh --iso kairos.iso --create-disk
```

This will:
- Create a 60GB disk image (`kairos.qcow2`)
- Boot from the ISO with 8GB RAM
- Forward ports: SSH (2226), K3s API (6444), Web Installer (8080)

### 2. Boot Menu and GRUB Configuration

When the VM boots, you'll see the Kairos bootloader menu:

```
 │*Kairos                                                                     │
 │ Kairos (manual)                                                            │
 │ kairos (interactive install)                                               │
 │ Kairos (remote recovery mode)                                              │
 │ Kairos (boot local node from livecd)                                       │
 │ Kairos (debug)
```

> [!IMPORTANT]
> **Before selecting**, press `e` to edit the GRUB entry and **remove `nomodeset`** from the kernel command line. This is required for the display to work properly with QEMU's virtio-gpu on MacOS.
>
> 1. Highlight **Kairos** and press `e`
> 2. Find the line starting with `linux` 
> 3. Remove `nomodeset` from that line
> 4. Press `Ctrl+X` or `F10` to boot

After editing, select **Kairos** or press `Ctrl+X` to boot.

## Install Kairos

### 1. SSH into the VM

Thanks to the port forwarding, you can SSH via localhost:

```bash
ssh -p 2226 kairos@localhost
# Password: kairos

# Or with sshpass:
sshpass -p 'kairos' ssh -p 2226 -o StrictHostKeyChecking=no kairos@localhost
```

> [!TIP]
> The web installer is also available at http://localhost:8080 if you prefer a GUI installation.

### 2. Create Kairos Configuration

```bash
cat > config.yaml <<EOF
#cloud-config
users:
  - name: kairos
    passwd: kairos
    groups:
      - admin

install:
  reboot: true

k3s:
  enabled: true
EOF
```

### 3. Run the Installation

```bash
sudo kairos-agent manual-install config.yaml
```

The installation will:
1. Partition the disk
2. Install the immutable OS
3. Configure K3s
4. Reboot automatically

> [!NOTE]
> After reboot, the QEMU window may close. Restart the VM without the ISO (see next section).

## Post-Installation: Boot from Disk

After installation, restart the VM **without** the ISO to boot from the installed disk:

```bash
cd macos/local-infra

# Boot from disk only (no ISO)
./start-master.sh
```

### Boot Menu (Post-Install)

The boot menu now shows:

```
 │*Kairos                                                                     │
 │ Kairos (fallback)                                                          │
 │ Kairos recovery                                                            │
 │ Kairos state reset (auto)                                                  │
 │ Kairos remote recovery
```

Select **Kairos** (the default) to boot into the installed system.

## Verify Kubernetes

### 1. SSH into the Running System

```bash
sshpass -p 'kairos' ssh -p 2226 kairos@localhost
```

### 2. Check Kubernetes

```bash
# Check nodes (as root)
sudo kubectl get nodes
```

Expected output:

```
NAME          STATUS   ROLES                  AGE     VERSION
kairos-xxxx   Ready    control-plane,master   2m      v1.35.0+k3s1
```

### 3. Access Kubernetes from Mac (Optional)

Since we forwarded port 6444 → 6443, you can access the cluster directly from your Mac:

```bash
# On the VM (as root), get the kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml
```

Copy the content and save it on your Mac:

```bash
# On your Mac
mkdir -p ~/.kube

# Create the config file (paste content, change server to localhost:6444)
cat > ~/.kube/config-kairos <<EOF
# Paste the k3s.yaml content here
# Change: server: https://127.0.0.1:6444
EOF

# Test access
export KUBECONFIG=~/.kube/config-kairos
kubectl get nodes
```

## Script Options Reference

The `start-master.sh` script supports various options:

```bash
./start-master.sh --help

Options:
  --disk PATH       Path to qcow2 disk image (default: kairos.qcow2)
  --iso PATH        Path to ISO for installation (optional)
  --create-disk     Create disk image if it doesn't exist
  --memory MB       Memory in MB (default: 8192)
  --cpus N          Number of CPUs (default: 2)

Port Forwards:
  SSH:           localhost:2226 -> VM:22
  K3s API:       localhost:6444 -> VM:6443
  Web Installer: localhost:8080 -> VM:8080
```

### Examples

```bash
# Boot existing master from disk
./start-master.sh

# Fresh install from ISO
./start-master.sh --iso kairos.iso --create-disk

# Use a custom disk image
./start-master.sh --disk kairos-custom.qcow2

# Boot custom disk with ISO attached
./start-master.sh --disk kairos-custom.qcow2 --iso build/custom.iso
```

## Troubleshooting

### Black screen / Display not working

The `nomodeset` kernel parameter must be removed for QEMU's virtio-gpu to work properly:

1. At the GRUB menu, press `e` to edit the boot entry
2. Find the line starting with `linux`
3. Remove `nomodeset` from that line
4. Press `Ctrl+X` or `F10` to boot

> [!TIP]
> After installation, you may need to do this on every boot until you modify the GRUB configuration permanently inside the VM.

### "hvf" acceleration not available

Ensure you're on Apple Silicon (M1/M2/M3/M4) and running a recent macOS version. Check:

```bash
sysctl kern.hv_support
# Should return: kern.hv_support: 1
```

### VM is very slow

Make sure `accel=hvf` is in your QEMU command. The scripts handle this automatically. Without it, QEMU uses software emulation.

### SSH connection refused

1. Wait for the VM to fully boot (watch the QEMU window)
2. Verify port forwarding: `lsof -i :2226`
3. Try connecting to the console directly via QEMU window

### SSH host key verification failed

After reinstalling or rebooting the VM, the SSH host key changes. Remove the old key:

```bash
ssh-keygen -R "[localhost]:2226"
```

Then reconnect:

```bash
ssh -p 2226 kairos@localhost
```

### UEFI firmware not found

The scripts automatically detect QEMU's firmware location. If it fails:

```bash
# Check where QEMU installed its firmware
ls $(brew --prefix qemu)/share/qemu/*.fd
```

### K3s not starting

```bash
# SSH into the VM and check logs
sshpass -p 'kairos' ssh -p 2226 kairos@localhost
sudo journalctl -u k3s -f
```

## Cleanup

To start fresh:

```bash
cd macos/local-infra

# Remove disk and create new one
rm kairos.qcow2

# Then reinstall
./start-master.sh --iso kairos.iso --create-disk
```

## Next Steps

Once your single-node cluster is running:

→ [Stage 2: Build your own immutable OS](stage-2-macos.md)

---

✅ Done! 🎉
