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

echo "[1/5] Installing build dependencies..."
$SUDO apt-get update -qq
$SUDO apt-get install -y -qq \
    build-essential \
    flex \
    bison \
    libelf-dev \
    libssl-dev \
    bc \
    wget \
    gcc-aarch64-linux-gnu \
    qemu-user-static \
    binfmt-support

echo ""
echo "[2/5] Installing Firecracker..."
ARCH=$(uname -m)
FC_VERSION="v1.6.0"
FC_URL="https://github.com/firecracker-microvm/firecracker/releases/download/${FC_VERSION}/firecracker-${FC_VERSION}-${ARCH}.tgz"

mkdir -p bin
if [ ! -f "bin/firecracker" ]; then
    wget -qO- "$FC_URL" | tar -xz -C bin --strip-components=1
    mv "bin/firecracker-${FC_VERSION}-${ARCH}" bin/firecracker
    mv "bin/jailer-${FC_VERSION}-${ARCH}" bin/jailer
    chmod +x bin/firecracker bin/jailer
    echo "  Installed bin/firecracker (${FC_VERSION})"
else
    echo "  bin/firecracker already exists, skipping"
fi

echo ""
echo "[3/5] Building x86_64 kernel..."
cd kernel
./build-kernel.sh x86_64
echo ""

echo "[4/5] Building ARM64 kernel (Apple Silicon)..."
./build-kernel.sh arm64
cd ..
echo ""

echo "[5/5] Building rootfs..."
cd rootfs
$SUDO ./build-rootfs.sh
cd ..

echo ""
echo "=== Build Complete ==="
echo ""
echo "Artifacts:"
echo "  kernel/vmlinux          - x86_64 kernel (Intel Macs, Linux)"
echo "  kernel/vmlinux-arm64    - ARM64 kernel (Apple Silicon)"
echo "  rootfs/rootfs-x86_64.ext4   - x86_64 root filesystem"
echo "  rootfs/rootfs-aarch64.ext4  - ARM64 root filesystem"
echo "  bin/firecracker         - Firecracker binary"
echo ""
echo "For Linux (x86_64):"
echo "  ./linux/linux-vm-boot --kernel kernel/vmlinux --rootfs rootfs/rootfs-x86_64.ext4 --memory 128 --no-network"
echo ""
echo "  (To enable networking, set up a TAP device first - see docs)"
echo ""
echo "For macOS, copy these files to your Mac:"
echo "  - kernel/vmlinux-arm64 (Apple Silicon)"
echo "  - rootfs/rootfs-aarch64.ext4"
echo ""
echo "Then on macOS:"
echo "  cd macos && ./build.sh"
echo "  ./macos-vm-boot --kernel ../kernel/vmlinux-arm64 --rootfs ../rootfs/rootfs-aarch64.ext4 --memory 128 --no-network"
