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

## Get a Pre-built ISO

Since MacOS on Apple Silicon is ARM-based, download the **aarch64** (arm64) ISO:

- [kairos-fedora-40-standard-arm64-generic-v3.7.1-k3sv1.35.0+k3s1.iso](https://github.com/kairos-io/kairos/releases/download/v3.7.1/kairos-fedora-40-standard-arm64-generic-v3.7.1-k3sv1.35.0+k3s1.iso) (514M) — Recommended
- [kairos-hadron-0.0.1-standard-arm64-generic-v3.7.1-k3sv1.35.0+k3s1.iso](https://github.com/kairos-io/kairos/releases/download/v3.7.1/kairos-hadron-0.0.1-standard-arm64-generic-v3.7.1-k3sv1.35.0+k3s1.iso) (357M) — Smaller, minimal image

```bash
# Create a working directory
mkdir -p ~/kairos-workshop && cd ~/kairos-workshop

# Download the Fedora-based Kairos ISO
curl -LO https://github.com/kairos-io/kairos/releases/download/v3.7.1/kairos-fedora-40-standard-arm64-generic-v3.7.1-k3sv1.35.0+k3s1.iso

# Rename for convenience
mv kairos-fedora-40-standard-arm64-generic-v3.7.1-k3sv1.35.0+k3s1.iso kairos.iso
```

> [!NOTE]
> The Fedora-based image is recommended as it has better driver support for virtualized environments.

## Create a Virtual Machine with QEMU

### 1. Create a Disk Image

```bash
cd ~/kairos-workshop

# Create a 60GB qcow2 disk image
qemu-img create -f qcow2 kairos.qcow2 60G
```

### 2. Download UEFI Firmware

QEMU on ARM requires UEFI firmware. Download the AAVMF (ARM UEFI) files:

```bash
# Create firmware directory
mkdir -p ~/kairos-workshop/firmware

# Download UEFI firmware for ARM64
curl -L -o ~/kairos-workshop/firmware/QEMU_EFI.fd \
  https://releases.linaro.org/components/kernel/uefi-linaro/latest/release/qemu64/QEMU_EFI.fd
```

Or use the firmware bundled with QEMU (check your brew installation):

```bash
# Find QEMU's share directory
ls $(brew --prefix qemu)/share/qemu/edk2-aarch64-code.fd
```

### 3. Boot the VM

```bash
cd ~/kairos-workshop

# Start the VM with the ISO attached
qemu-system-aarch64 \
    -machine virt,accel=hvf,highmem=on \
    -cpu host \
    -smp 2 \
    -m 4096 \
    -bios $(brew --prefix qemu)/share/qemu/edk2-aarch64-code.fd \
    -device virtio-gpu-pci \
    -display default,show-cursor=on \
    -device qemu-xhci \
    -device usb-kbd \
    -device usb-tablet \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::2224-:22,hostfwd=tcp::6443-:6443,hostfwd=tcp::8080-:8080 \
    -drive file=kairos.qcow2,if=virtio,format=qcow2 \
    -cdrom kairos.iso \
    -boot d
```

**Key flags explained:**

| Flag | Purpose |
|------|---------|
| `-machine virt,accel=hvf` | Use Apple Hypervisor Framework (native speed) |
| `-cpu host` | Use host CPU features |
| `-smp 2 -m 4096` | 2 CPUs, 4GB RAM |
| `-bios ...edk2-aarch64-code.fd` | UEFI firmware for ARM64 |
| `-netdev user,...hostfwd=tcp::2224-:22` | Port forward: localhost:2224 → VM:22 (SSH) |
| `-netdev user,...hostfwd=tcp::6443-:6443` | Port forward: localhost:6443 → VM:6443 (K8s API) |
| `-netdev user,...hostfwd=tcp::8080-:8080` | Port forward: localhost:8080 → VM:8080 (Web installer) |
| `-cdrom kairos.iso` | Boot from ISO |
| `-boot d` | Boot from CD-ROM first |

> [!NOTE]
> Port 2224 is used for SSH instead of 2222 because Gitea (from the local infrastructure) uses port 2222.

> [!IMPORTANT]
> The `accel=hvf` flag enables Apple's Hypervisor Framework for near-native performance. Without it, QEMU falls back to software emulation (very slow).

### 4. Boot Menu and GRUB Configuration

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
ssh -p 2224 kairos@localhost
# Password: kairos
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
kairos-agent manual-install config.yaml
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
cd ~/kairos-workshop

qemu-system-aarch64 \
    -machine virt,accel=hvf,highmem=on \
    -cpu host \
    -smp 2 \
    -m 4096 \
    -bios $(brew --prefix qemu)/share/qemu/edk2-aarch64-code.fd \
    -device virtio-gpu-pci \
    -display default,show-cursor=on \
    -device qemu-xhci \
    -device usb-kbd \
    -device usb-tablet \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::2224-:22,hostfwd=tcp::6443-:6443,hostfwd=tcp::8080-:8080 \
    -drive file=kairos.qcow2,if=virtio,format=qcow2
```

> [!TIP]
> Create a shell script `start-kairos.sh` with this command for convenience.

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
ssh -p 2224 kairos@localhost
# Password: kairos
```

### 2. Check Kubernetes

```bash
# Become root
sudo -i

# Check nodes
kubectl get nodes
```

Expected output:

```
NAME          STATUS   ROLES                  AGE     VERSION
kairos-xxxx   Ready    control-plane,master   2m      v1.35.0+k3s1
```

### 3. Access Kubernetes from Mac (Optional)

Since we forwarded port 6443, you can access the cluster directly from your Mac:

```bash
# On the VM (as root), get the kubeconfig
cat /etc/rancher/k3s/k3s.yaml
```

Copy the content and save it on your Mac:

```bash
# On your Mac
mkdir -p ~/.kube

# Create the config file (paste content, change server to localhost:6443)
cat > ~/.kube/config-kairos <<EOF
# Paste the k3s.yaml content here
# Change: server: https://127.0.0.1:6443
EOF

# Test access
export KUBECONFIG=~/.kube/config-kairos
kubectl get nodes
```
#NOTES: not working Kairos might only listen to lookup interface from within the VM
## Helper Scripts

Create these scripts in `~/kairos-workshop/` for convenience:

### start-kairos.sh (Boot from disk)

```bash
#!/bin/bash
cd ~/kairos-workshop

qemu-system-aarch64 \
    -machine virt,accel=hvf,highmem=on \
    -cpu host \
    -smp 2 \
    -m 4096 \
    -bios $(brew --prefix qemu)/share/qemu/edk2-aarch64-code.fd \
    -device virtio-gpu-pci \
    -display default,show-cursor=on \
    -device qemu-xhci \
    -device usb-kbd \
    -device usb-tablet \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::2224-:22,hostfwd=tcp::6443-:6443,hostfwd=tcp::8080-:8080 \
    -drive file=kairos.qcow2,if=virtio,format=qcow2
```

### start-kairos-iso.sh (Boot from ISO for fresh install)

```bash
#!/bin/bash
cd ~/kairos-workshop

qemu-system-aarch64 \
    -machine virt,accel=hvf,highmem=on \
    -cpu host \
    -smp 2 \
    -m 4096 \
    -bios $(brew --prefix qemu)/share/qemu/edk2-aarch64-code.fd \
    -device virtio-gpu-pci \
    -display default,show-cursor=on \
    -device qemu-xhci \
    -device usb-kbd \
    -device usb-tablet \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::2224-:22,hostfwd=tcp::6443-:6443,hostfwd=tcp::8080-:8080 \
    -drive file=kairos.qcow2,if=virtio,format=qcow2 \
    -cdrom kairos.iso \
    -boot d
```

Make them executable:

```bash
chmod +x ~/kairos-workshop/start-kairos*.sh
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

Make sure `accel=hvf` is in your QEMU command. Without it, QEMU uses software emulation.

### SSH connection refused

1. Wait for the VM to fully boot (watch the QEMU window)
2. Verify port forwarding: `lsof -i :2224`
3. Try connecting to the console directly via QEMU window

### SSH host key verification failed

After reinstalling or rebooting the VM, the SSH host key changes. Remove the old key:

```bash
ssh-keygen -R "[localhost]:2224"
```

Then reconnect:

```bash
ssh -p 2224 kairos@localhost
```

### UEFI firmware not found

```bash
# Check where QEMU installed its firmware
ls $(brew --prefix qemu)/share/qemu/*.fd

# Use the correct path in your -bios flag
```

### K3s not starting

```bash
# SSH into the VM and check logs
ssh -p 2224 kairos@localhost
sudo journalctl -u k3s -f
```

## Cleanup

To start fresh:

```bash
cd ~/kairos-workshop
rm kairos.qcow2
qemu-img create -f qcow2 kairos.qcow2 60G
```

## Next Steps

Once your single-node cluster is running:

→ [Stage 2: Build your own immutable OS](stage-2-macos.md)

---

✅ Done! 🎉
