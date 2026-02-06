# Stage 4: Upgrading your cluster manually (MacOS)

Docs:
  - [Manual Upgrade](https://kairos.io/docs/upgrade/manual/)
  - [A/B Upgrades](https://kairos.io/docs/architecture/container/#ab-upgrades)

## Overview

Kairos uses an A/B partition scheme for atomic, immutable upgrades:

- **Active partition**: Currently running OS
- **Passive partition**: Target for upgrades

When you upgrade, the new image is written to the passive partition. After reboot, partitions swap roles. If the upgrade fails, you can boot back to the previous (now passive) partition.

## Prerequisites

- Kairos VM running (from [Stage 1](stage-1-macos.md))
- SSH access to the VM

## Check Current Version

```bash
# SSH into the VM
sshpass -p 'kairos' ssh -p 2226 kairos@localhost

# Check current Kairos version
cat /etc/kairos-release | grep -E "KAIROS_VERSION|KAIROS_FLAVOR|KAIROS_SOFTWARE_VERSION"
```

Example output (custom image from Stage 2):
```
KAIROS_FLAVOR="ubuntu"
KAIROS_FLAVOR_RELEASE="22.04"
KAIROS_SOFTWARE_VERSION="v1.35.0+k3s1"
KAIROS_SOFTWARE_VERSION_PREFIX="k3s"
KAIROS_VERSION="v0.0.1"
```

## Choose an Upgrade Source

### Option 1: Use a Kairos Official Image

List available upgrade images directly from the VM:

```bash
sudo kairos-agent upgrade list-releases
```

Example output:
```
Using registry: quay.io/kairos
Current image:
quay.io/kairos/ubuntu:22.04-standard-arm64-generic-v0.0.1-k3sv1.35.0-k3s1

Available releases with higher version:
quay.io/kairos/ubuntu:22.04-standard-arm64-generic-v3.7.2-k3s-v1.35.0-k3s3
quay.io/kairos/ubuntu:22.04-standard-arm64-generic-v3.7.1-k3s-v1.35.0-k3s1
quay.io/kairos/ubuntu:22.04-standard-arm64-generic-v3.6.0-k3s-v1.34.1-k3s1
...
```

Browse all images at: https://quay.io/organization/kairos

### Option 2: Use Your Custom Image from Stage 3

If you built and pushed a custom image to ttl.sh or your local registry:
```
ttl.sh/kairos-custom-fedora:2h
```

### Option 3: Build a New Version

Use the Argo workflow from Stage 3 to build a new version, then push it to a registry accessible from the VM.

## Perform the Upgrade

### 1. SSH into the VM

```bash
sshpass -p 'kairos' ssh -p 2226 kairos@localhost
```

### 2. Run the Upgrade

```bash
# Upgrade to a Kairos official image (example - v3.7.2 with K3s 1.35.0)
sudo kairos-agent upgrade --source oci:quay.io/kairos/ubuntu:22.04-standard-arm64-generic-v3.7.2-k3s-v1.35.0-k3s3

# Or upgrade to your custom image
sudo kairos-agent upgrade --source oci:ttl.sh/kairos-custom-fedora:2h
```

The upgrade process will:
1. Pull the new container image
2. Extract it to the passive partition
3. Update the bootloader

### 3. Reboot

```bash
sudo reboot
```

> [!NOTE]
> The SSH connection will drop during reboot. Wait ~1 minute before reconnecting.

### 4. Verify the Upgrade

```bash
# Reconnect
sshpass -p 'kairos' ssh -p 2226 kairos@localhost

# Check the new version
cat /etc/kairos-release | grep -E "KAIROS_VERSION|KAIROS_FLAVOR|KAIROS_SOFTWARE_VERSION"

# Verify K3s is running
sudo kubectl get nodes
```

Example output after upgrading from v0.0.1 to v3.7.2:
```
KAIROS_FLAVOR="ubuntu"
KAIROS_FLAVOR_RELEASE="22.04"
KAIROS_SOFTWARE_VERSION="v1.35.0+k3s3"
KAIROS_SOFTWARE_VERSION_PREFIX="k3s"
KAIROS_VERSION="v3.7.2"
```

## Rollback (If Needed)

If the upgrade causes issues, you can boot back to the previous version:

### Option 1: GRUB Menu

1. Reboot the VM
2. At the GRUB menu, select **"Kairos (fallback)"**
3. This boots the previous (passive) partition

Example output after booting fallback (back to v0.0.1):
```
KAIROS_FLAVOR="ubuntu"
KAIROS_FLAVOR_RELEASE="22.04"
KAIROS_SOFTWARE_VERSION="v1.35.0+k3s1"
KAIROS_SOFTWARE_VERSION_PREFIX="k3s"
KAIROS_VERSION="v0.0.1"
```

This demonstrates the A/B partition scheme:

| Partition | After Upgrade | After Fallback |
|-----------|---------------|----------------|
| **Active** | v3.7.2 (k3s3) | v0.0.1 (k3s1) |
| **Passive** | v0.0.1 (k3s1) | v3.7.2 (k3s3) |

### Option 2: From Command Line

```bash
# Check current boot entry
sudo grub-editenv /oem/grubenv list

# Set to boot from fallback
sudo grub-editenv /oem/grubenv set next_entry=fallback

# Reboot
sudo reboot
```

## Upgrade Considerations

### Kubernetes Version Compatibility

When upgrading, ensure the K3s version is compatible:
- **Minor version jumps** (e.g., 1.30 → 1.31): Usually safe
- **Major version downgrades**: May cause issues with cluster state
- **Same version, different Kairos release**: Safe

### Preserving Data

Kairos preserves data in:
- `/usr/local/` - Persisted across upgrades
- `/oem/` - OEM configuration
- `/var/lib/rancher/` - K3s data (etcd, etc.)

### Upgrade vs Fresh Install

| Upgrade | Fresh Install |
|---------|---------------|
| Preserves K3s cluster state | Starts fresh |
| Keeps `/usr/local/` data | Clean slate |
| A/B partition swap | Wipes disk |

## Troubleshooting

### Upgrade fails to pull image

Check DNS is working in the VM:
```bash
curl -I https://quay.io
```

If DNS fails, see the DNS fix in [Stage 3 Prerequisites](stage-3-macos.md#fix-dns-in-the-vm-important).

### Node not rejoining cluster after upgrade

Check K3s logs:
```bash
sudo journalctl -u k3s -f
```

Common issues:
- K3s version mismatch (major downgrade)
- Network connectivity

### Boot stuck after upgrade

1. At GRUB menu, select **"Kairos (fallback)"**
2. Once booted, check logs:
   ```bash
   sudo journalctl -b -1  # Previous boot logs
   ```

## Next Steps

→ [Stage 5: Multi-node Cluster](stage-5-macos.md)

---

✅ Done! 🎉
