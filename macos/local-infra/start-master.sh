#!/bin/bash
# =============================================================================
# Kairos Master VM Launcher (MacOS with Apple Silicon)
# =============================================================================
# This script starts the Kairos master/control-plane VM using QEMU with HVF.
#
# Usage:
#   ./start-master.sh                    # Boot from disk only
#   ./start-master.sh --iso kairos.iso   # Boot from ISO (for fresh install)
#   ./start-master.sh --disk my.qcow2    # Use custom disk image
#   ./start-master.sh --create-disk      # Create new disk if it doesn't exist
#
# Port Forwards:
#   - localhost:2226 -> VM:22 (SSH)
#   - localhost:6444 -> VM:6443 (K3s API)
#   - localhost:8080 -> VM:8080 (Web installer)
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Configuration (modify these as needed)
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# VM Resources
MEMORY="8192"           # 8GB RAM for master (needed for Argo Workflows)
CPUS="2"                # Number of CPUs
DISK_SIZE="60G"         # Disk size for new disks

# Default paths
DEFAULT_DISK="${SCRIPT_DIR}/kairos.qcow2"
DEFAULT_ISO=""          # No ISO by default (boot from disk)

# Network ports (host:guest)
SSH_PORT="2226"
K8S_API_PORT="6444"
WEB_INSTALLER_PORT="8080"

# UEFI Firmware
FIRMWARE="$(brew --prefix qemu 2>/dev/null)/share/qemu/edk2-aarch64-code.fd"
if [[ ! -f "$FIRMWARE" ]]; then
    FIRMWARE="${SCRIPT_DIR}/firmware/QEMU_EFI.fd"
fi

# -----------------------------------------------------------------------------
# Parse arguments
# -----------------------------------------------------------------------------
DISK="$DEFAULT_DISK"
ISO="$DEFAULT_ISO"
CREATE_DISK=false

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --disk PATH       Path to qcow2 disk image (default: kairos.qcow2)"
    echo "  --iso PATH        Path to ISO for installation (optional)"
    echo "  --create-disk     Create disk image if it doesn't exist"
    echo "  --memory MB       Memory in MB (default: 8192)"
    echo "  --cpus N          Number of CPUs (default: 2)"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Boot existing master from disk"
    echo "  $0 --iso kairos.iso --create-disk    # Fresh install from ISO"
    echo "  $0 --disk kairos-custom.qcow2        # Boot custom disk"
    echo ""
    echo "Port Forwards:"
    echo "  SSH:           localhost:${SSH_PORT} -> VM:22"
    echo "  K3s API:       localhost:${K8S_API_PORT} -> VM:6443"
    echo "  Web Installer: localhost:${WEB_INSTALLER_PORT} -> VM:8080"
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
    -netdev "user,id=net0,hostfwd=tcp::${SSH_PORT}-:22,hostfwd=tcp::${K8S_API_PORT}-:6443,hostfwd=tcp::${WEB_INSTALLER_PORT}-:8080"
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
echo "  Kairos Master VM"
echo "=========================================="
echo "  Memory:    ${MEMORY}MB"
echo "  CPUs:      ${CPUS}"
echo "  Disk:      ${DISK}"
[[ -n "$ISO" ]] && echo "  ISO:       ${ISO}"
echo ""
echo "  SSH:       ssh -p ${SSH_PORT} kairos@localhost"
echo "  K3s API:   https://localhost:${K8S_API_PORT}"
echo "  Web UI:    http://localhost:${WEB_INSTALLER_PORT}"
echo "=========================================="
echo ""
echo "Starting QEMU... (close window or Ctrl+C to stop)"
echo ""

exec "${QEMU_CMD[@]}"
