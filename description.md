## Outline

1. **What are immutable OS and how to think about operations with this paradigm**

   Explore the philosophy and architecture of immutable systems versus traditional configuration management tools. Learn how immutability enables atomic upgrades, reduced drift, simplified recovery, and stronger security postures.  **Resources**

   - [Immutable Architecture](https://kairos.io/docs/architecture/immutable/)
   - [Understanding Immutable Linux OS: Benefits, Architecture, and Challenges](https://kairos.io/blog/2023/03/22/understanding-immutable-linux-os-benefits-architecture-and-challenges/)

2. **Introduction to Kairos and its major concepts**

   Get familiar with Kairos as a cloud-native, distro-agnostic, immutable Linux meta-distribution. Understand key concepts like A/B system partitions, persistent data separation, recovery mode, and cloud-config-driven provisioning.

   **Resources**

   - [Getting Started](https://kairos.io/getting-started/)
   - [What is Kairos](https://kairos.io/getting-started/what-is-kairos/)
   - [Architecture](https://kairos.io/docs/architecture/)
   - [Reference](https://kairos.io/docs/reference/)

3. **Deploying a single-node cluster**

   Deploy Kairos on a VM or bare-metal machine and initialize a Kubernetes control plane using K3s and cloud-init. Validate node readiness and explore initial workloads.

   **Resources**

   - [Manual Single-Node Cluster](https://kairos.io/docs/examples/single-node/)

4. **Build your own immutable OS**

   Use the **Kairos Factory** (from the Web or CLI) to create a custom immutable OS image tailored to your needs. Learn how to configure the base system, embed Kubernetes, and prepare for consistent provisioning.

   **Resources**

   - [The Kairos Factory](https://kairos.io/docs/reference/kairos-factory/)

5. **Integrating OS builds into your CI/CD pipelines**

  Automate OS image building and publishing using GitHub Actions or similar CI systems.

  **Resources**

  - Pending

6. **Upgrading your cluster manually**

   Perform manual upgrades using A/B partitions and Kairos commands. Practice rolling back and verifying upgraded systems.

   **Resources**

   - [Manual Upgrade](https://kairos.io/docs/upgrade/manual/)

7. **Deploying a multi-node cluster**

   Scale to a multi-node setup by bootstrapping additional Kairos worker nodes. Learn how to use cloud-config to preconfigure joining behavior.

   **Resources**

   - [Manual Multi-Node Cluster](https://kairos.io/docs/examples/multi-node/)

8. **Upgrading your cluster through Kubernetes**

   Set up the **Kairos Operator** to manage in-cluster, declarative upgrades. Apply upgrade plans to roll out updates across multiple nodes in a safe, automated way.

  **Resources**

  - [Kairos Operator README](https://github.com/kairos-io/kairos-operator)

### ⏱️ Optional Advanced Topics *(time and interest permitting)*

- **Build an air-gapped cluster**

  Mirror container images and OS builds to run a Kubernetes cluster completely offline.

  **Resources**

  - [How to Create an Airgap K3s Installation with Kairos](https://kairos.io/docs/examples/airgap/)

- **Perform a hybrid-cloud deployment**

  Combine public cloud and on-prem nodes into a single cluster using Kairos-based images.

  **Resources**

  - Pending

- **PXE/netboot cluster bootstrapping**

  Use AuroraBoot to provision nodes over the network without local install media i.e. cdrom/usb

  **Resources**

  - [Netboot](https://kairos.io/docs/installation/netboot/)
  - [P2P Multi-Node Cluster Provisioned via Netboot](https://kairos.io/docs/examples/p2p_e2e/)

- **Trusted Boot with TPM/UEFI for maximum security**

  Enable cryptographic boot verification to ensure system integrity at startup.

  **Resources**

  - [Architecture](https://kairos.io/docs/architecture/trustedboot/)
  - [Installation](https://kairos.io/docs/installation/trustedboot/)
  - [Upgrading](https://kairos.io/docs/upgrade/trustedboot/)
  - [System Extensions](https://kairos.io/docs/advanced/sys-extensions/)
  - [Unlocking the Mysteries of Trusted Boot: A Deep Dive into Secure System Boot Processes](https://kairos.io/blog/2024/04/10/unlocking-the-mysteries-of-trusted-boot-a-deep-dive-into-secure-system-boot-processes/)

- **Deploying an HA multi-node cluster**

  Set up a highly available control plane using immutable nodes and external etcd or load balancing.

  **Resources**

  - [Manual HA Cluster](https://kairos.io/docs/examples/ha/)
  - [Self-coordinating HA Cluster](https://kairos.io/docs/examples/multi-node-p2p-ha/)
  - [Self-coordinating P2P Multi-Node Cluster with High Availability and KubeVIP](https://kairos.io/docs/examples/multi-node-p2p-ha-kubevip/)

- **Deploying a multi-node self-coordinating cluster**

  Use Kairos mesh networking features to create clusters that auto-discover and join each other.

  **Resources**

  - [Self-Coordinating Multi-Node Cluster](https://kairos.io/docs/examples/multi-node-p2p/)

- **Raspberry Pi deployments**

  Boot Kairos on ARM devices and set up a lightweight edge Kubernetes deployment with real hardware.

  **Resources**

  - [Installation](https://kairos.io/docs/installation/raspberry/)
