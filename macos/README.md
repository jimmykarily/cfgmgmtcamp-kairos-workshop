# Kairos Workshop - MacOS Track

This folder contains a MacOS-native adaptation of the Kairos workshop, designed to run entirely on a Mac without requiring Linux VMs for the control plane or external services like GitHub.

## Why a MacOS Track?

The original workshop was designed with Linux tooling in mind (qemu with KVM, Docker with native socket access). On MacOS, several challenges arise:

| Challenge | Original Approach | MacOS Solution |
|-----------|-------------------|----------------|
| VM creation | qemu with KVM | **QEMU with HVF** (Apple Hypervisor Framework) |
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

### Stages 4-6
These stages work the same as the original workshop once you have a running cluster.

→ See [../stage-4.md](../stage-4.md), [../stage-5.md](../stage-5.md), [../stage-6.md](../stage-6.md)

## Quick Start

```bash
# 1. Start local infrastructure
cd macos/local-infra
podman-compose up -d

# 2. Verify services
open http://localhost:3000   # Gitea
open http://localhost:8080   # Registry UI

# 3. Continue with Stage 1...
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         MacOS Host                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   Gitea     │  │  Registry   │  │       QEMU + HVF        │  │
│  │  :3000      │  │   :5000     │  │                         │  │
│  │             │  │             │  │  ┌───────────────────┐  │  │
│  │  Git repos  │  │  Kairos     │  │  │   Kairos VM       │  │  │
│  │  for ISO    │  │  images     │  │  │   :2222 → SSH     │  │  │
│  │  configs    │  │             │  │  │   :6443 → K8s API │  │  │
│  └──────┬──────┘  └──────┬──────┘  │  │  ┌─────────────┐  │  │  │
│         │                │         │  │  │    K3s      │  │  │  │
│         │                │         │  │  │             │  │  │  │
│         └────────────────┼─────────┼──┼──│ Argo Workflows│ │  │  │
│                          │         │  │  └─────────────┘  │  │  │
│                          │         │  │                   │  │  │
│                          └─────────┼──┼───────────────────┘  │  │
│                                    │  └───────────────────────┘  │
│                                    │                             │
└────────────────────────────────────┴─────────────────────────────┘
```

## Differences from Original Workshop

| Stage | Original | MacOS Track |
|-------|----------|-------------|
| 1 | qemu with KVM (Linux) | QEMU with HVF (Apple Hypervisor) |
| 2 | Docker + ttl.sh | Podman + local registry |
| 3 | GitHub Actions | Gitea + Argo Workflows |
| 4 | Same | Same |
| 5 | Same | QEMU for worker VMs |
| 6 | Same | Same |
