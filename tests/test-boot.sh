#!/bin/bash
set -e

# Test boot script - validates that VM boots correctly
# This script is platform-agnostic where possible

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

KERNEL_PATH="${PROJECT_ROOT}/kernel/vmlinux"
ROOTFS_PATH="${PROJECT_ROOT}/rootfs/rootfs.ext4"
MEMORY_MB=128

echo "=== VM Boot Test ==="
echo ""

# Check which platform we're on
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
    VM_BOOT="${PROJECT_ROOT}/macos/macos-vm-boot"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="linux"
    VM_BOOT="${PROJECT_ROOT}/linux/linux-vm-boot"
else
    echo "Error: Unsupported platform: $OSTYPE"
    exit 1
fi

echo "Platform: $PLATFORM"
echo "VM Boot: $VM_BOOT"
echo ""

# Check if VM boot binary exists
if [ ! -f "$VM_BOOT" ]; then
    echo "Error: VM boot binary not found: $VM_BOOT"
    echo "Please build the VM wrapper first."
    exit 1
fi

# Check if kernel exists
if [ ! -f "$KERNEL_PATH" ]; then
    echo "Error: Kernel not found: $KERNEL_PATH"
    echo "Please build the kernel first: cd kernel && ./build-kernel.sh"
    exit 1
fi

# Check if rootfs exists
if [ ! -f "$ROOTFS_PATH" ]; then
    echo "Error: Rootfs not found: $ROOTFS_PATH"
    echo "Please build the rootfs first: cd rootfs && sudo ./build-rootfs.sh"
    exit 1
fi

echo "Kernel: $KERNEL_PATH ($(du -h "$KERNEL_PATH" | cut -f1))"
echo "Rootfs: $ROOTFS_PATH ($(du -h "$ROOTFS_PATH" | cut -f1))"
echo "Memory: ${MEMORY_MB}MB"
echo ""

# Test argument parsing
echo "Testing argument parsing..."

# Test help
if ! "$VM_BOOT" --help > /dev/null 2>&1; then
    echo "Error: --help flag failed"
    exit 1
fi

# Test missing kernel argument
if "$VM_BOOT" --rootfs "$ROOTFS_PATH" --memory 128 2>/dev/null; then
    echo "Error: Should fail with missing --kernel"
    exit 1
fi

# Test missing rootfs argument
if "$VM_BOOT" --kernel "$KERNEL_PATH" --memory 128 2>/dev/null; then
    echo "Error: Should fail with missing --rootfs"
    exit 1
fi

# Test missing memory argument
if "$VM_BOOT" --kernel "$KERNEL_PATH" --rootfs "$ROOTFS_PATH" 2>/dev/null; then
    echo "Error: Should fail with missing --memory"
    exit 1
fi

# Test invalid kernel path
if "$VM_BOOT" --kernel "/nonexistent" --rootfs "$ROOTFS_PATH" --memory 128 2>/dev/null; then
    echo "Error: Should fail with invalid kernel path"
    exit 1
fi

echo "✓ Argument parsing tests passed"
echo ""

# Note: Full boot test would require actually running the VM and checking output
# This is difficult to automate without timeout mechanisms and proper TTY handling
echo "Basic validation complete!"
echo ""
echo "To manually test VM boot:"
echo "  $VM_BOOT --kernel $KERNEL_PATH --rootfs $ROOTFS_PATH --memory $MEMORY_MB"
echo ""
echo "Once booted, run inside the VM:"
echo "  /root/test.sh"
echo "  poweroff"
