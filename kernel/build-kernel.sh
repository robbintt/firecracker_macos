#!/bin/bash
set -e

KERNEL_VERSION="6.1.112"
BUILD_DIR="$(pwd)/build"
KERNEL_DIR="${BUILD_DIR}/linux-${KERNEL_VERSION}"
CONFIG_FILE="$(pwd)/microvm-kernel.config"
OUTPUT_KERNEL="$(pwd)/vmlinux"

echo "Building minimal microVM kernel..."
echo "Kernel version: ${KERNEL_VERSION}"

# Create build directory
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# Download kernel source if not already present
if [ ! -d "${KERNEL_DIR}" ]; then
    echo "Downloading kernel source..."
    KERNEL_MAJOR=$(echo ${KERNEL_VERSION} | cut -d. -f1)
    wget -q --show-progress "https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_MAJOR}.x/linux-${KERNEL_VERSION}.tar.xz"
    echo "Extracting kernel source..."
    tar -xf "linux-${KERNEL_VERSION}.tar.xz"
    rm "linux-${KERNEL_VERSION}.tar.xz"
else
    echo "Using existing kernel source in ${KERNEL_DIR}"
fi

cd "${KERNEL_DIR}"

# Copy our config
echo "Applying microVM kernel configuration..."
cp "${CONFIG_FILE}" .config

# Build the kernel
echo "Building kernel (this may take a while)..."
make -j$(nproc) vmlinux

# Copy the kernel to the output location
echo "Copying kernel to ${OUTPUT_KERNEL}..."
cp vmlinux "${OUTPUT_KERNEL}"

echo ""
echo "Kernel build complete!"
echo "Output: ${OUTPUT_KERNEL}"
echo ""
echo "Kernel size: $(du -h ${OUTPUT_KERNEL} | cut -f1)"
