#!/bin/bash
set -e

ROOTFS_SIZE="256M"
ALPINE_VERSION="3.19"
ALPINE_MIRROR="https://dl-cdn.alpinelinux.org/alpine"

# Parse arguments
BUILD_ARCH=""
FORCE_BUILD=0

for arg in "$@"; do
    case $arg in
        --arch=*)
            BUILD_ARCH="${arg#*=}"
            ;;
        --force)
            FORCE_BUILD=1
            ;;
        *)
            echo "Usage: $0 [--arch=x86_64|aarch64] [--force]"
            echo "  --arch: Build only specified architecture (default: both)"
            echo "  --force: Force rebuild even if image exists"
            exit 1
            ;;
    esac
done

# Determine which architectures to build
if [ -n "$BUILD_ARCH" ]; then
    ARCHITECTURES=("$BUILD_ARCH")
else
    ARCHITECTURES=("x86_64" "aarch64")
fi

echo "Building Alpine Linux rootfs..."
echo "Size: ${ROOTFS_SIZE}"
echo "Alpine version: ${ALPINE_VERSION}"
echo "Architectures: ${ARCHITECTURES[*]}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

# Function to build rootfs for a specific architecture
build_rootfs_for_arch() {
    local ARCH=$1
    local ROOTFS_IMAGE="rootfs-${ARCH}.ext4"
    local MOUNT_POINT="/tmp/rootfs-mount-${ARCH}-$$"

    # Skip if output already exists (unless force)
    if [ -f "${ROOTFS_IMAGE}" ] && [ "$FORCE_BUILD" -eq 0 ]; then
        echo ""
        echo "Rootfs already exists: ${ROOTFS_IMAGE}"
        echo "Use '--force' to rebuild"
        return 0
    fi

    echo ""
    echo "========================================="
    echo "Building rootfs for ${ARCH}"
    echo "========================================="

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
    ALPINE_FILE="alpine-minirootfs-${ALPINE_VERSION}.0-${ARCH}.tar.gz"
    ALPINE_URL="${ALPINE_MIRROR}/v${ALPINE_VERSION}/releases/${ARCH}/${ALPINE_FILE}"

    wget -q --show-progress "${ALPINE_URL}" -O "/tmp/${ALPINE_FILE}"

    echo "Extracting Alpine Linux to rootfs..."
    tar -xzf "/tmp/${ALPINE_FILE}" -C "${MOUNT_POINT}"
    rm "/tmp/${ALPINE_FILE}"

    # For ARM64 cross-compilation, copy QEMU static binary
    if [ "${ARCH}" = "aarch64" ] && [ "$(uname -m)" != "aarch64" ]; then
        echo "Setting up QEMU for ARM64 emulation..."
        if [ -f /usr/bin/qemu-aarch64-static ]; then
            mkdir -p "${MOUNT_POINT}/usr/bin"
            cp /usr/bin/qemu-aarch64-static "${MOUNT_POINT}/usr/bin/"
        else
            echo "ERROR: qemu-aarch64-static not found!"
            echo "Install qemu-user-static package:"
            echo "  Debian/Ubuntu: sudo apt-get install qemu-user-static"
            echo "  RHEL/Fedora:   sudo dnf install qemu-user-static"
            echo "  Arch:          sudo pacman -S qemu-user-static"
            umount "${MOUNT_POINT}"
            rmdir "${MOUNT_POINT}"
            rm -f "${ROOTFS_IMAGE}"
            exit 1
        fi
    fi

    # Copy overlay files
    if [ -d "overlay" ]; then
        echo "Copying overlay files..."
        cp -r overlay/* "${MOUNT_POINT}/"
    fi

    # Set up resolv.conf for chroot networking
    echo "nameserver 8.8.8.8" > "${MOUNT_POINT}/etc/resolv.conf"

    # Install OpenRC and essential packages
    echo "Installing OpenRC and base packages..."
    chroot "${MOUNT_POINT}" /sbin/apk add --no-cache \
        openrc \
        alpine-base \
        agetty

    # Enable essential services
    chroot "${MOUNT_POINT}" /sbin/rc-update add devfs sysinit
    chroot "${MOUNT_POINT}" /sbin/rc-update add dmesg sysinit
    chroot "${MOUNT_POINT}" /sbin/rc-update add mdev sysinit
    chroot "${MOUNT_POINT}" /sbin/rc-update add hwclock boot
    chroot "${MOUNT_POINT}" /sbin/rc-update add modules boot
    chroot "${MOUNT_POINT}" /sbin/rc-update add sysctl boot
    chroot "${MOUNT_POINT}" /sbin/rc-update add hostname boot
    chroot "${MOUNT_POINT}" /sbin/rc-update add bootmisc boot
    chroot "${MOUNT_POINT}" /sbin/rc-update add syslog boot 2>/dev/null || true
    chroot "${MOUNT_POINT}" /sbin/rc-update add mount-ro shutdown
    chroot "${MOUNT_POINT}" /sbin/rc-update add killprocs shutdown
    chroot "${MOUNT_POINT}" /sbin/rc-update add savecache shutdown

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

    # Configure console (supports both Firecracker and macOS)
    # Use a boot script to detect which console is available
    cat > "${MOUNT_POINT}/etc/init.d/serial-console" << 'EOL'
#!/sbin/openrc-run

description="Start getty on available serial console"

depend() {
    after localmount
}

start() {
    # Firecracker uses ttyS0
    if [ -e /dev/ttyS0 ]; then
        ebegin "Starting getty on ttyS0"
        start-stop-daemon --start --background --exec /sbin/getty -- -L ttyS0 115200 vt100
        eend $?
    fi
    
    # macOS Virtualization.framework uses hvc0
    if [ -e /dev/hvc0 ]; then
        stty -F /dev/hvc0 -echo
        ebegin "Starting getty on hvc0"
        start-stop-daemon --start --background --exec /sbin/getty -- -L hvc0 115200 vt100
        eend $?
    fi
}
EOL
    chmod +x "${MOUNT_POINT}/etc/init.d/serial-console"
    chroot "${MOUNT_POINT}" /sbin/rc-update add serial-console default

    # Minimal inittab - let OpenRC handle consoles
    cat > "${MOUNT_POINT}/etc/inittab" << 'EOL'
::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default

::ctrlaltdel:/sbin/reboot
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

    # Remove QEMU binary if it was added (no longer needed in final image)
    if [ "${ARCH}" = "aarch64" ] && [ -f "${MOUNT_POINT}/usr/bin/qemu-aarch64-static" ]; then
        echo "Cleaning up QEMU binary..."
        rm -f "${MOUNT_POINT}/usr/bin/qemu-aarch64-static"
    fi

    # Unmount
    echo "Unmounting rootfs..."
    umount "${MOUNT_POINT}"
    rmdir "${MOUNT_POINT}"

    # Don't cleanup twice
    trap - EXIT

    # Fix ownership if run via sudo
    if [ -n "$SUDO_USER" ]; then
        chown "$SUDO_USER:$SUDO_USER" "${ROOTFS_IMAGE}"
    fi

    echo ""
    echo "Rootfs build complete for ${ARCH}!"
    echo "Output: ${ROOTFS_IMAGE}"
    echo "Size: $(du -h ${ROOTFS_IMAGE} | cut -f1)"
}

# Build rootfs for each requested architecture
for ARCH in "${ARCHITECTURES[@]}"; do
    build_rootfs_for_arch "$ARCH"
done

echo ""
echo "========================================="
echo "All builds complete!"
echo "========================================="
echo ""
echo "You can test with:"
echo "  x86_64 on Linux:  ./linux/linux-vm-boot --kernel ../kernel/vmlinux-x86_64 --rootfs rootfs-x86_64.ext4 --memory 128"
echo "  ARM64 on macOS:   ./macos/macos-vm-boot --kernel ../kernel/vmlinux-arm64 --rootfs rootfs-aarch64.ext4 --memory 128 --no-network"
