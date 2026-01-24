#!/bin/bash
set -e

# Firecracker officially supports 6.1 guest kernels
# https://github.com/firecracker-microvm/firecracker/blob/main/docs/kernel-policy.md
KERNEL_VERSION="6.1.161"
BUILD_DIR="$(pwd)/build"
KERNEL_DIR="${BUILD_DIR}/linux-${KERNEL_VERSION}"

# Determine target architecture
TARGET_ARCH="${1:-x86_64}"

if [ "$TARGET_ARCH" = "arm64" ] || [ "$TARGET_ARCH" = "aarch64" ]; then
    TARGET_ARCH="arm64"
    CONFIG_FILE="$(pwd)/microvm-kernel-arm64.config"
    OUTPUT_KERNEL="$(pwd)/vmlinux-arm64"
    export ARCH=arm64
    export CROSS_COMPILE=aarch64-linux-gnu-
    echo "Cross-compiling for ARM64 (Apple Silicon)"
    echo "Requires: sudo apt install gcc-aarch64-linux-gnu"
else
    TARGET_ARCH="x86_64"
    CONFIG_FILE="$(pwd)/microvm-kernel.config"
    OUTPUT_KERNEL="$(pwd)/vmlinux"
    echo "Building for x86_64"
fi

echo "Building minimal microVM kernel..."
echo "Kernel version: ${KERNEL_VERSION}"
echo "Target: ${TARGET_ARCH}"

# Skip if output already exists (use --force to rebuild)
if [ -f "${OUTPUT_KERNEL}" ] && [ "$2" != "--force" ]; then
    echo "Kernel already exists: ${OUTPUT_KERNEL}"
    echo "Use './build-kernel.sh ${TARGET_ARCH} --force' to rebuild"
    exit 0
fi

# Create build directory
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# Download kernel source if not already present
if [ ! -d "${KERNEL_DIR}" ]; then
    echo "Downloading kernel source..."
    KERNEL_MAJOR=$(echo ${KERNEL_VERSION} | cut -d. -f1)
    TARBALL="linux-${KERNEL_VERSION}.tar.xz"
    if [ ! -f "${TARBALL}" ]; then
        wget -q --show-progress "https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_MAJOR}.x/${TARBALL}"
    fi
    echo "Extracting kernel source..."
    tar -xf "${TARBALL}"
    rm "${TARBALL}"
else
    echo "Using existing kernel source in ${KERNEL_DIR}"
fi

cd "${KERNEL_DIR}"

# Copy our config
echo "Applying microVM kernel configuration..."
cp "${CONFIG_FILE}" .config

# Apply defaults for any new options (non-interactive)
make olddefconfig

# Build the kernel
echo "Building kernel (this may take a while)..."
if [ "$TARGET_ARCH" = "arm64" ]; then
    # ARM64: build Image (uncompressed) - Virtualization.framework needs this
    make -j$(nproc) Image
    KERNEL_IMAGE="arch/arm64/boot/Image"
else
    # x86_64: build vmlinux
    make -j$(nproc) vmlinux
    KERNEL_IMAGE="vmlinux"
fi

# Copy the kernel to the output location
echo "Copying kernel to ${OUTPUT_KERNEL}..."
cp "${KERNEL_IMAGE}" "${OUTPUT_KERNEL}"

echo ""
echo "Kernel build complete!"
echo "Output: ${OUTPUT_KERNEL}"
echo ""
echo "Kernel size: $(du -h ${OUTPUT_KERNEL} | cut -f1)"
