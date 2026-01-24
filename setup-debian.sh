#!/bin/bash
# Setup script for Debian/Ubuntu to build all firecracker_macos artifacts
set -e

echo "=== Firecracker macOS Setup for Debian/Ubuntu ==="
echo ""

# Check if running as root for apt
if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

echo "[1/4] Installing build dependencies..."
$SUDO apt-get update -qq
$SUDO apt-get install -y -qq \
    build-essential \
    flex \
    bison \
    libelf-dev \
    libssl-dev \
    bc \
    wget \
    gcc-aarch64-linux-gnu

echo ""
echo "[2/4] Building x86_64 kernel..."
cd kernel
./build-kernel.sh x86_64
echo ""

echo "[3/4] Building ARM64 kernel (Apple Silicon)..."
./build-kernel.sh arm64
cd ..
echo ""

echo "[4/4] Building rootfs..."
cd rootfs
$SUDO ./build-rootfs.sh
cd ..

echo ""
echo "=== Build Complete ==="
echo ""
echo "Artifacts:"
echo "  kernel/vmlinux        - x86_64 kernel (Intel Macs, Linux)"
echo "  kernel/vmlinux-arm64  - ARM64 kernel (Apple Silicon)"
echo "  rootfs/rootfs.ext4    - Root filesystem (works on both)"
echo ""
echo "For Linux (x86_64):"
echo "  ./linux/linux-vm-boot --kernel kernel/vmlinux --rootfs rootfs/rootfs.ext4 --memory 128"
echo ""
echo "For macOS, copy these files to your Mac:"
echo "  - kernel/vmlinux (Intel) or kernel/vmlinux-arm64 (Apple Silicon)"
echo "  - rootfs/rootfs.ext4"
echo ""
echo "Then on macOS:"
echo "  cd macos && ./build.sh"
echo "  ./macos-vm-boot --kernel ../kernel/vmlinux-arm64 --rootfs ../rootfs/rootfs.ext4 --memory 128"
