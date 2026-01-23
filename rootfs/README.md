# Root Filesystem

Minimal Alpine Linux-based root filesystem as raw ext4 image for microVMs.

## Requirements

- Linux (for building)
- Root access (sudo)
- wget
- mount/umount
- mkfs.ext4
- tar

On Ubuntu/Debian:
```bash
sudo apt-get install wget e2fsprogs coreutils tar
```

## Building

```bash
cd rootfs
sudo ./build-rootfs.sh
```

This will:
1. Create a 256MB ext4 image
2. Download Alpine Linux minirootfs (v3.19)
3. Extract and configure the system
4. Add overlay files
5. Configure networking and console
6. Create test utilities

The build process takes 1-2 minutes.

## Contents

The rootfs includes:

- **Alpine Linux minirootfs**: Minimal Alpine Linux base system
- **OpenRC**: Init system
- **Basic utilities**: sh, wget, tar, etc.
- **Network tools**: DHCP client, basic networking
- **Serial console**: Configured for virtio console (hvc0)
- **Test script**: `/root/test.sh` for system validation

## Configuration

### Default Credentials
- Username: `root`
- Password: `root`

### Network
- Interface: `eth0`
- Configuration: DHCP

### Console
- Device: `hvc0` (virtio console)
- Getty: 38400 baud

## Overlay

The `overlay/` directory contains files that are copied into the rootfs:

- `overlay/init`: Custom init script (if needed)

To add custom files:
1. Place them in the `overlay/` directory with the desired path structure
2. Run `./build-rootfs.sh` to rebuild

Example:
```
overlay/
  etc/
    myconfig.conf
  root/
    myscript.sh
```

## Testing

After building, test the rootfs with:

**Linux (Firecracker):**
```bash
cd ../linux
./linux-vm-boot --kernel ../kernel/vmlinux --rootfs ../rootfs/rootfs.ext4 --memory 128
```

**macOS (Virtualization.framework):**
```bash
cd ../macos
./macos-vm-boot --kernel ../kernel/vmlinux --rootfs ../rootfs/rootfs.ext4 --memory 128
```

Inside the VM:
```bash
# Run the test script
/root/test.sh

# Check network
ip addr
ping -c 3 8.8.8.8

# Shutdown
poweroff
```

## Size

The default rootfs image is 256MB, which provides plenty of space for a minimal system. The actual used space is around 30-50MB.

To change the size, edit `ROOTFS_SIZE` in `build-rootfs.sh`.

## Customization

### Adding Packages

To add Alpine packages:

1. Edit `build-rootfs.sh` and add after the extraction step:
```bash
chroot "${MOUNT_POINT}" /sbin/apk add --no-cache <package-name>
```

2. Rebuild the rootfs

### Changing Alpine Version

Edit `ALPINE_VERSION` in `build-rootfs.sh` (e.g., "3.18", "3.19", "edge").

## Troubleshooting

**"Must be run as root"**: Use `sudo ./build-rootfs.sh`

**"Command not found"**: Install missing dependencies (mkfs.ext4, wget, etc.)

**Mount errors**: Ensure no other process is using the mount point

**Network not working in VM**: Check that virtio-net is enabled in kernel config
