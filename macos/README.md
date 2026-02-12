# Kairos Workshop - MacOS Track

This folder contains a MacOS-native adaptation of the Kairos workshop, designed to run entirely on a Mac without requiring Linux VMs for the control plane or external services like GitHub.

## Why a MacOS Track?

The original workshop was designed with Linux tooling in mind (qemu with KVM, Docker with native socket access). On MacOS, several challenges arise:

| Challenge | Original Approach | MacOS Solution |
|-----------|-------------------|----------------|
| VM creation | qemu with KVM | **QEMU with HVF** + **vmnet-bridged** networking |
| Container builds | Docker with socket mount | **Podman** in rootful mode |
| Image registry | ttl.sh / quay.io | **Local registry** (localhost:5000) |
| CI/CD pipeline | GitHub Actions | **Gitea** + **Argo Workflows** |

## Prerequisites

Install the following on your Mac:

```bash
# QEMU (VM manager with Apple Hypervisor Framework support)
brew install qemu

# Podman (container runtime)
brew install podman
podman machine init
podman machine start

# Podman Compose (for local infrastructure)
brew install podman-compose
```

## Workshop Structure

### Phase 0: Local Infrastructure
Set up local Gitea and Registry services.

→ [local-infra/README.md](local-infra/README.md)

### Stage 1: Deploying a Single Node Cluster (MacOS)
Create a Kairos VM using QEMU with Apple Hypervisor Framework.

→ [stage-1-macos.md](stage-1-macos.md)

### Stage 2: Build Your Own Immutable OS (MacOS)
Build custom Kairos images using Podman and push to local registry.

→ [stage-2-macos.md](stage-2-macos.md)

### Stage 3: CI/CD with Gitea + Argo Workflows
Replace GitHub Actions with local GitOps pipeline.

→ [stage-3-macos.md](stage-3-macos.md) *(coming soon)*

### Stage 4: Manual Upgrades (MacOS)
Perform A/B partition upgrades manually using `kairos-agent`.

→ [stage-4-macos.md](stage-4-macos.md)

### Stage 5: Multi-node Cluster (MacOS)
Deploy a multi-node cluster with master and worker VMs.

→ [stage-5-macos.md](stage-5-macos.md)

### Stage 6: Kubernetes-based Upgrades (MacOS)
Use the Kairos Operator for automated, Kubernetes-native OS upgrades.

→ [stage-6-macos.md](stage-6-macos.md)

## Quick Start

```bash
# 1. Start local infrastructure (Gitea + Registry)
cd macos/local-infra
podman-compose up -d

# 2. Verify services
open http://localhost:3000   # Gitea
open http://localhost:8000   # Registry UI

# 3. Follow Stage 1 to create your first Kairos VM
```

See [Stage 1](stage-1-macos.md) for detailed VM setup instructions.

## Architecture Overview

With **vmnet-bridged** networking, VMs get real IP addresses from your network's DHCP server:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Local Network (e.g., 192.168.20.0/24)        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    MacOS Host (.100)                       │  │
│  │  ┌─────────────┐  ┌─────────────┐                         │  │
│  │  │   Gitea     │  │  Registry   │                         │  │
│  │  │  :3000      │  │   :5000     │                         │  │
│  │  └─────────────┘  └─────────────┘                         │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              QEMU + HVF (vmnet-bridged)                    │  │
│  │                                                            │  │
│  │  ┌─────────────────────┐  ┌─────────────────────┐         │  │
│  │  │  Master VM (.150)   │  │  Worker VM (.151)   │         │  │
│  │  │  K3s control-plane  │◄─│  K3s agent          │         │  │
│  │  │  Argo Workflows     │  │                     │         │  │
│  │  └─────────────────────┘  └─────────────────────┘         │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘

SSH: ssh kairos@192.168.20.150
K8s: kubectl --server=https://192.168.20.150:6443
```

## Differences from Original Workshop

| Stage | Original | MacOS Track |
|-------|----------|-------------|
| 1 | qemu with KVM (Linux) | QEMU with HVF + vmnet-bridged |
| 2 | Docker + ttl.sh | Podman + local registry |
| 3 | GitHub Actions | Gitea + Argo Workflows |
| 4 | Same | Same |
| 5 | Same | QEMU for worker VMs (bridged network) |
| 6 | Same | Same |
