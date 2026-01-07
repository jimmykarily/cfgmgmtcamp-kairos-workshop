# Abstract

Immutability at the OS level is gaining traction as a way to simplify, secure, and scale Kubernetes operations — without the fragility of hand-crafted node configurations or the false sense of control offered by traditional configuration management systems, which often still result in drift and snowflakes. In this hands-on workshop, you'll learn how to build Kubernetes clusters that are easier to deploy, upgrade, and recover — and do it all step-by-step, without needing to become an OS expert.

### You'll learn how to:
- Understand what an immutable OS is and why it matters
- Deploy Kubernetes on top of an immutable system
- Add and manage read-only worker nodes
- Upgrade nodes manually or via Kubernetes-native workflows
- Create your own tailored, immutable OS image
- Integrating OS builds into your CI/CD pipelines

### If time allows, we'll also explore:
- Air-gapped and hybrid-cloud deployments
- PXE/netboot cluster bootstrapping
- Trusted Boot with TPM/UEFI
- High-availability setups on immutable infrastructure
- Raspberry Pi and edge use cases with mesh networking

All examples will be built using [Kairos](https://kairos.io), an open-source Linux toolkit designed to make immutability practical and flexible — but the patterns you'll learn are applicable beyond any single tool.

## Audience

This workshop is designed for **platform engineers, SREs, and solution architects** who need more flexibility than fully managed Kubernetes solutions typically allow — but who also want to avoid taking on the burden of maintaining yet another complex system. If you're comfortable with Linux, familiar with Kubernetes basics, and can spin up a VM or cloud instance, you'll leave with real-world skills you can apply immediately.
