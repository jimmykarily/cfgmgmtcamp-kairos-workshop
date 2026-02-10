#!/bin/bash
# =============================================================================
# Kairos Worker VM Launcher (MacOS with Apple Silicon)
# =============================================================================
# This script starts a Kairos worker VM using QEMU with HVF.
#
# Usage:
#   ./start-worker.sh                              # Boot from disk only
#   ./start-worker.sh --iso kairos.iso             # Boot from ISO (for fresh install)
#   ./start-worker.sh --disk worker2.qcow2         # Use custom disk image
#   ./start-worker.sh --create-disk                # Create new disk if it doesn't exist
#   ./start-worker.sh --name worker2 --ssh-port 2227  # Custom name and ports
#
# Port Forwards (defaults):
#   - localhost:2225 -> VM:22 (SSH)
#
# Note: Worker connects to master via host gateway (10.0.2.2:6444)
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Configuration (modify these as needed)
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# VM Resources
MEMORY="4096"           # 4GB RAM for worker
CPUS="2"                # Number of CPUs
DISK_SIZE="60G"         # Disk size for new disks

# Default paths
DEFAULT_DISK="${SCRIPT_DIR}/kairos-worker.qcow2"
DEFAULT_ISO=""          # No ISO by default (boot from disk)

# Network ports (host:guest)
SSH_PORT="2225"

# Worker identity (for multiple workers)
WORKER_NAME="worker"

# UEFI Firmware
FIRMWARE="$(brew --prefix qemu 2>/dev/null)/share/qemu/edk2-aarch64-code.fd"
if [[ ! -f "$FIRMWARE" ]]; then
    FIRMWARE="${SCRIPT_DIR}/firmware/QEMU_EFI.fd"
fi

# -----------------------------------------------------------------------------
# Parse arguments
# -----------------------------------------------------------------------------
DISK=""
ISO="$DEFAULT_ISO"
CREATE_DISK=false

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --disk PATH       Path to qcow2 disk image (default: kairos-worker.qcow2)"
    echo "  --iso PATH        Path to ISO for installation (optional)"
    echo "  --create-disk     Create disk image if it doesn't exist"
    echo "  --memory MB       Memory in MB (default: 4096)"
    echo "  --cpus N          Number of CPUs (default: 2)"
    echo "  --ssh-port PORT   SSH port on host (default: 2225)"
    echo "  --name NAME       Worker name, affects default disk name (default: worker)"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Boot existing worker from disk"
    echo "  $0 --iso kairos.iso --create-disk    # Fresh install from ISO"
    echo "  $0 --name worker2 --ssh-port 2227    # Second worker"
    echo ""
    echo "Port Forwards:"
    echo "  SSH: localhost:${SSH_PORT} -> VM:22"
    echo ""
    echo "Worker Configuration:"
    echo "  The worker connects to the master via host gateway:"
    echo "  K3S_URL=https://10.0.2.2:6444"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --disk)
            DISK="$2"
            shift 2
            ;;
        --iso)
            ISO="$2"
            shift 2
            ;;
        --create-disk)
            CREATE_DISK=true
            shift
            ;;
        --memory)
            MEMORY="$2"
            shift 2
            ;;
        --cpus)
            CPUS="$2"
            shift 2
            ;;
        --ssh-port)
            SSH_PORT="$2"
            shift 2
            ;;
        --name)
            WORKER_NAME="$2"
            shift 2
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Set default disk based on worker name if not explicitly provided
if [[ -z "$DISK" ]]; then
    DISK="${SCRIPT_DIR}/kairos-${WORKER_NAME}.qcow2"
fi

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------
if [[ ! -f "$FIRMWARE" ]]; then
    echo "Error: UEFI firmware not found at $FIRMWARE"
    echo "Install QEMU with: brew install qemu"
    exit 1
fi

# Create disk if requested and it doesn't exist
if [[ "$CREATE_DISK" == true && ! -f "$DISK" ]]; then
    echo "Creating disk image: $DISK ($DISK_SIZE)"
    qemu-img create -f qcow2 "$DISK" "$DISK_SIZE"
fi

if [[ ! -f "$DISK" ]]; then
    echo "Error: Disk image not found: $DISK"
    echo "Use --create-disk to create it, or specify an existing disk with --disk"
    exit 1
fi

if [[ -n "$ISO" && ! -f "$ISO" ]]; then
    echo "Error: ISO file not found: $ISO"
    exit 1
fi

# -----------------------------------------------------------------------------
# Build QEMU command
# -----------------------------------------------------------------------------
QEMU_CMD=(
    qemu-system-aarch64
    -machine virt,accel=hvf,highmem=on
    -cpu host
    -smp "$CPUS"
    -m "$MEMORY"
    -bios "$FIRMWARE"
    -device virtio-gpu-pci
    -display default,show-cursor=on
    -device qemu-xhci
    -device usb-kbd
    -device usb-tablet
    -device virtio-net-pci,netdev=net0
    -netdev "user,id=net0,hostfwd=tcp::${SSH_PORT}-:22"
    -drive "file=${DISK},if=virtio,format=qcow2"
)

# Add ISO if specified
if [[ -n "$ISO" ]]; then
    QEMU_CMD+=(-cdrom "$ISO" -boot d)
    echo "Booting from ISO: $ISO"
else
    echo "Booting from disk: $DISK"
fi

# -----------------------------------------------------------------------------
# Launch VM
# -----------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "  Kairos Worker VM: ${WORKER_NAME}"
echo "=========================================="
echo "  Memory:    ${MEMORY}MB"
echo "  CPUs:      ${CPUS}"
echo "  Disk:      ${DISK}"
[[ -n "$ISO" ]] && echo "  ISO:       ${ISO}"
echo ""
echo "  SSH:       ssh -p ${SSH_PORT} kairos@localhost"
echo ""
echo "  Master Connection (from inside worker):"
echo "    K3S_URL=https://10.0.2.2:6444"
echo "=========================================="
echo ""
echo "Worker cloud-config example:"
echo "---"
cat << 'CLOUDCONFIG'
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
    K3S_TOKEN: "<GET_FROM_MASTER: cat /var/lib/rancher/k3s/server/node-token>"
    K3S_URL: "https://10.0.2.2:6444"
CLOUDCONFIG
echo "---"
echo ""
echo "Starting QEMU... (close window or Ctrl+C to stop)"
echo ""

exec "${QEMU_CMD[@]}"
