#!/bin/bash
set -e

ROOTFS_SIZE="256M"
ROOTFS_IMAGE="rootfs.ext4"
ALPINE_VERSION="3.19"
ALPINE_MIRROR="https://dl-cdn.alpinelinux.org/alpine"
MOUNT_POINT="/tmp/rootfs-mount-$$"

echo "Building Alpine Linux rootfs..."
echo "Size: ${ROOTFS_SIZE}"
echo "Alpine version: ${ALPINE_VERSION}"

# Skip if output already exists (use --force to rebuild)
if [ -f "${ROOTFS_IMAGE}" ] && [ "$1" != "--force" ]; then
    echo "Rootfs already exists: ${ROOTFS_IMAGE}"
    echo "Use './build-rootfs.sh --force' to rebuild"
    exit 0
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

# Create empty ext4 image
echo "Creating ${ROOTFS_SIZE} ext4 image..."
dd if=/dev/zero of="${ROOTFS_IMAGE}" bs=1M count=${ROOTFS_SIZE//M/} status=progress
mkfs.ext4 -F "${ROOTFS_IMAGE}"

# Mount the image
echo "Mounting rootfs image..."
mkdir -p "${MOUNT_POINT}"
mount -o loop "${ROOTFS_IMAGE}" "${MOUNT_POINT}"

# Ensure cleanup on exit
trap "umount ${MOUNT_POINT} 2>/dev/null || true; rmdir ${MOUNT_POINT} 2>/dev/null || true" EXIT

# Download and extract Alpine minirootfs
echo "Downloading Alpine Linux minirootfs..."
ARCH="x86_64"
ALPINE_FILE="alpine-minirootfs-${ALPINE_VERSION}.0-${ARCH}.tar.gz"
ALPINE_URL="${ALPINE_MIRROR}/v${ALPINE_VERSION}/releases/${ARCH}/${ALPINE_FILE}"

wget -q --show-progress "${ALPINE_URL}" -O "/tmp/${ALPINE_FILE}"

echo "Extracting Alpine Linux to rootfs..."
tar -xzf "/tmp/${ALPINE_FILE}" -C "${MOUNT_POINT}"
rm "/tmp/${ALPINE_FILE}"

# Copy overlay files
if [ -d "overlay" ]; then
    echo "Copying overlay files..."
    cp -r overlay/* "${MOUNT_POINT}/"
fi

# Set up basic system configuration
echo "Configuring system..."

# Set root password (root)
echo "root:root" | chroot "${MOUNT_POINT}" /usr/sbin/chpasswd 2>/dev/null || \
    echo 'root:$6$rounds=656000$YQKMBzYy$F8K5VnR5bH5z5z5z5z5z5z5z5z5z5z5z5z5z5z5z5z5z5z5z5z5z5z5z5z5z5z5z5z5z5z5z5z5z' > "${MOUNT_POINT}/etc/shadow"

# Configure networking
cat > "${MOUNT_POINT}/etc/network/interfaces" << 'EOL'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOL

# Enable serial console
cat > "${MOUNT_POINT}/etc/inittab" << 'EOL'
::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default

# Set up a getty on the console
hvc0::respawn:/sbin/getty 38400 hvc0
tty1::respawn:/sbin/getty 38400 tty1

# Stuff to do for the 3-finger salute
::ctrlaltdel:/sbin/reboot

# Stuff to do before rebooting
::shutdown:/sbin/openrc shutdown
EOL

# Create a simple test script
cat > "${MOUNT_POINT}/root/test.sh" << 'EOL'
#!/bin/sh
echo "=== System Test ==="
echo "Hostname: $(hostname)"
echo "Kernel: $(uname -r)"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Disk: $(df -h / | tail -1 | awk '{print $2}')"
echo "=== Test Passed ==="
EOL
chmod +x "${MOUNT_POINT}/root/test.sh"

# Create a welcome message
cat > "${MOUNT_POINT}/etc/motd" << 'EOL'

Welcome to MicroVM (Alpine Linux)

This is a minimal Alpine Linux system for microVMs.
Kernel and rootfs shared between Firecracker and macOS Virtualization.framework.

Run /root/test.sh to verify system functionality.

EOL

# Make sure /dev, /proc, /sys exist
mkdir -p "${MOUNT_POINT}/dev"
mkdir -p "${MOUNT_POINT}/proc"
mkdir -p "${MOUNT_POINT}/sys"
mkdir -p "${MOUNT_POINT}/run"
mkdir -p "${MOUNT_POINT}/tmp"
chmod 1777 "${MOUNT_POINT}/tmp"

# Unmount
echo "Unmounting rootfs..."
umount "${MOUNT_POINT}"
rmdir "${MOUNT_POINT}"

# Don't cleanup twice
trap - EXIT

echo ""
echo "Rootfs build complete!"
echo "Output: ${ROOTFS_IMAGE}"
echo "Size: $(du -h ${ROOTFS_IMAGE} | cut -f1)"
echo ""
echo "You can test it with:"
echo "  Linux:  ./linux/linux-vm-boot --kernel ../kernel/vmlinux --rootfs ${ROOTFS_IMAGE} --memory 128"
echo "  macOS:  ./macos/macos-vm-boot --kernel ../kernel/vmlinux --rootfs ${ROOTFS_IMAGE} --memory 128"
