# Stage 1: Deploying a single node cluster

Docs:
  - [Manual Single-Node Cluster](https://kairos.io/docs/examples/single-node/)

## Get a pre-built ISO

aarch64:
  - TODO: Add hadron arm link as soon as we got one
  - [kairos-fedora-40-standard-arm64-generic-v3.6.1-beta2-k3sv1.32.10+k3s1.iso](https://github.com/kairos-io/kairos/releases/download/v3.6.1-beta2/kairos-fedora-40-standard-arm64-generic-v3.6.1-beta2-k3sv1.32.10+k3s1.iso)

amd64:
  - [kairos-hadron-0.0.1-standard-amd64-generic-v3.6.1-beta2-k3sv1.32.10+k3s1.iso](https://github.com/kairos-io/kairos/releases/download/v3.6.1-beta2/kairos-hadron-0.0.1-standard-amd64-generic-v3.6.1-beta2-k3sv1.32.10+k3s1.iso)
  - [kairos-fedora-40-standard-amd64-generic-v3.6.1-beta2-k3sv1.32.10+k3s1.iso](https://github.com/kairos-io/kairos/releases/download/v3.6.1-beta2/kairos-fedora-40-standard-amd64-generic-v3.6.1-beta2-k3sv1.32.10+k3s1.iso)

## Create a Virtual Machine

Options:

1. qemu/libvirt
2. VirtualBox
3. Host Proxmox locally?
4. Public cloud provider

Quickest path to success:

```bash
# Create a disk image
qemu-img create -f qcow2 kairos.img 60g

# Start the VM (assuming ISO is named "kairos.iso")
qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -nographic \
    -serial mon:stdio \
    -m 4096 \
    -smp 2 \
    -rtc base=utc,clock=rt \
    -chardev socket,path=/tmp/kairos.sock,server=on,wait=off,id=qga0 \
    -device virtio-serial \
    -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
    -drive id=disk1,if=none,media=disk,file="kairos.img" \
    -device virtio-blk-pci,drive=disk1,bootindex=0 \
    -drive id=cdrom1,if=none,media=cdrom,file="kairos.iso" \
    -device ide-cd,drive=cdrom1,bootindex=1 \
    -boot menu=on

# To exit: CTRL^A -> x
# To cleanup: rm kairos.img
```

## Deploy Kairos

- SSH to the virtual machine
- Create a basic Kairos config:

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

- Install Kairos:
  ```bash
  kairos-agent manual-install config.yaml
  ```

- Check that Kubernetes is running (from within the VM):

  ```bash
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  kubectl get nodes
  ```

✅ Done! 🎉
