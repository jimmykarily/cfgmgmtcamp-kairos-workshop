# Stage 1: Deploying a Single Node Cluster (MacOS)

This guide walks through deploying a Kairos single-node Kubernetes cluster on MacOS using **QEMU** with **vmnet-bridged** networking.

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

### Identify Your Network Interface

Find the network interface your Mac uses to connect to the network:

```bash
# List interfaces with IP addresses
ifconfig | grep -E "^en|inet "

# Typically en0 for built-in Ethernet/WiFi
ifconfig en0 | grep "inet "
```

You'll use this interface (e.g., `en0`) for bridged networking.

## Get a Pre-built ISO

Since MacOS on Apple Silicon is ARM-based, download an **aarch64** (arm64) ISO from the [Kairos releases page](https://github.com/kairos-io/kairos/releases).

### Choosing an Image Flavor

Kairos offers several base image flavors:

| Flavor | Base | Size | Best For |
|--------|------|------|----------|
| **Ubuntu** | Ubuntu 22.04/24.04 | ~1.5GB | Familiar environment, wide package availability |
| **Fedora** | Fedora 40 | ~1.5GB | Familiar environment, newer packages |
| **Hadron** | Minimal (Alpine-based) | ~500MB | Production, minimal attack surface, faster downloads |

**Ubuntu/Fedora** are full-featured distributions with familiar package managers (`apt`/`dnf`). Choose either based on your preference - they have equivalent support in Kairos.

**Hadron** is Kairos's minimal image, purpose-built for immutable infrastructure. It's smaller and faster but has fewer pre-installed tools. Great for production; for this workshop, Ubuntu or Fedora are easier to work with.

Download an ISO and place it in `macos/local-infra/kairos.iso`.

## Create and Boot the VM

### 1. Create a Disk Image

```bash
cd macos/local-infra
qemu-img create -f qcow2 kairos.qcow2 60G
```

### 2. Boot from ISO

> [!IMPORTANT]
> `vmnet-bridged` requires **sudo** to access the macOS networking stack.

```bash
cd macos/local-infra

sudo qemu-system-aarch64 \
    -machine virt,accel=hvf,highmem=on \
    -cpu host \
    -smp 2 \
    -m 8192 \
    -bios $(brew --prefix qemu)/share/qemu/edk2-aarch64-code.fd \
    -device virtio-gpu-pci \
    -display default,show-cursor=on \
    -device qemu-xhci \
    -device usb-kbd \
    -device usb-tablet \
    -device virtio-net-pci,netdev=net0 \
    -netdev vmnet-bridged,id=net0,ifname=en0 \
    -drive file=kairos.qcow2,if=virtio,format=qcow2 \
    -cdrom kairos.iso \
    -boot menu=on
```

**Key flags:**

| Flag | Purpose |
|------|---------|
| `-machine virt,accel=hvf` | Use Apple Hypervisor Framework |
| `-m 8192` | 8GB RAM (needed for K3s + workloads) |
| `-netdev vmnet-bridged,ifname=en0` | Bridge to host network (VM gets real IP) |
| `-boot menu=on` | Show boot menu |

### 3. Boot Menu

When the VM boots, you'll see the Kairos bootloader:

```
 │*Kairos                                                                     │
 │ Kairos (manual)                                                            │
 │ kairos (interactive install)                                               │
 │ Kairos (remote recovery mode)                                              │
 │ Kairos (boot local node from livecd)                                       │
 │ Kairos (debug)
```

Select **Kairos** to boot into the live environment.

## Install Kairos

### 1. Find the VM's IP Address

The VM gets an IP from your network's DHCP server. Find it from the QEMU console:

```bash
# Inside the VM
ip addr show enp0s1 | grep "inet "
```

Or from your Mac:

```bash
# Scan your network for QEMU MAC addresses (start with 52:54)
arp -a | grep -i "52:54"
```

Example: `192.168.20.150`

### 2. SSH into the VM

```bash
ssh kairos@192.168.20.150
# Password: kairos
```

### 3. Create Configuration

This is the basic cloud-config for a single-node K3s cluster (also used as a master in multi-node setups):

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

> [!TIP]
> For worker node configuration, see [Stage 5: Multi-node Cluster](stage-5-macos.md#step-4-install-worker).

### 4. Install

```bash
sudo kairos-agent manual-install config.yaml
```

The installation will partition the disk, install the OS, and reboot.

## Post-Installation: Boot from Disk

After installation, restart the VM **without** the ISO (remove the `-cdrom` and `-boot` lines):

```bash
cd macos/local-infra

sudo qemu-system-aarch64 \
    -machine virt,accel=hvf,highmem=on \
    -cpu host \
    -smp 2 \
    -m 8192 \
    -bios $(brew --prefix qemu)/share/qemu/edk2-aarch64-code.fd \
    -device virtio-gpu-pci \
    -display default,show-cursor=on \
    -device qemu-xhci \
    -device usb-kbd \
    -device usb-tablet \
    -device virtio-net-pci,netdev=net0 \
    -netdev vmnet-bridged,id=net0,ifname=en0 \
    -drive file=kairos.qcow2,if=virtio,format=qcow2
```

> [!TIP]
> **QEMU Command Reference**: This is the standard QEMU command used throughout the workshop. Other stages will reference this with minor variations:
> - **Different disk**: Change `-drive file=<disk>.qcow2`
> - **Add ISO**: Add `-cdrom <iso> -boot menu=on`
> - **Worker VM (less RAM)**: Change `-m 4096`

### Boot Menu (Post-Install)

```
 │*Kairos                                                                     │
 │ Kairos (fallback)                                                          │
 │ Kairos recovery                                                            │
 │ Kairos state reset (auto)                                                  │
 │ Kairos remote recovery
```

Select **Kairos** to boot into the installed system.

## Verify Kubernetes

### 1. SSH into the VM

```bash
ssh kairos@192.168.20.150
```

### 2. Check Cluster

```bash
sudo kubectl get nodes
```

Expected output:

```
NAME          STATUS   ROLES                  AGE     VERSION
kairos-xxxx   Ready    control-plane,master   2m      v1.35.0+k3s1
```

### 3. Access from Mac (Optional)

Copy the kubeconfig to your Mac:

```bash
# From your Mac (replace IP with your VM's IP)
scp kairos@192.168.20.150:/etc/rancher/k3s/k3s.yaml ~/.kube/config-kairos

# Update server address to VM's IP
sed -i '' 's/127.0.0.1/192.168.20.150/' ~/.kube/config-kairos

# Test
export KUBECONFIG=~/.kube/config-kairos
kubectl get nodes
```

## Troubleshooting

### vmnet permission denied

`vmnet-bridged` requires root privileges. Always run QEMU with `sudo`.

### VM doesn't get IP

1. Verify the bridge interface exists: `ifconfig en0`
2. Check your network has DHCP enabled
3. Inside VM, try: `sudo dhclient enp0s1`

### "hvf" acceleration not available

Ensure you're on Apple Silicon (M1/M2/M3/M4):

```bash
sysctl kern.hv_support
# Should return: kern.hv_support: 1
```

### SSH connection refused

Wait for the VM to fully boot. Check IP with `ip addr` from QEMU console.

### SSH host key changed

```bash
ssh-keygen -R 192.168.20.150
```

### K3s not starting

```bash
sudo journalctl -u k3s -f
```

## Cleanup

```bash
cd macos/local-infra
rm kairos.qcow2
```

## Next Steps

→ [Stage 2: Build your own immutable OS](stage-2-macos.md)

---

✅ Done! 🎉
