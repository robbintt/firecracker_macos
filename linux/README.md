# Linux VM Wrapper (Firecracker)

A shell script wrapper for Firecracker that provides the same interface as the macOS VM wrapper.

## Requirements

- Linux (x86_64)
- Firecracker installed and in PATH
- KVM support enabled
- Root or appropriate permissions for KVM and networking

### Installing Firecracker

Download the latest release from [Firecracker releases](https://github.com/firecracker-microvm/firecracker/releases):

```bash
# Download Firecracker
ARCH="x86_64"
VERSION="v1.7.0"
curl -LOJ https://github.com/firecracker-microvm/firecracker/releases/download/${VERSION}/firecracker-${VERSION}-${ARCH}.tgz

# Extract and install
tar -xzf firecracker-${VERSION}-${ARCH}.tgz
sudo mv release-${VERSION}-${ARCH}/firecracker-${VERSION}-${ARCH} /usr/local/bin/firecracker
sudo chmod +x /usr/local/bin/firecracker

# Verify installation
firecracker --version
```

### KVM Setup

```bash
# Check if KVM is available
lsmod | grep kvm

# If not loaded, load the module
sudo modprobe kvm
sudo modprobe kvm_intel  # or kvm_amd for AMD CPUs

# Set permissions (for development)
sudo chmod 666 /dev/kvm
```

## Usage

```bash
./linux-vm-boot --kernel <path> --rootfs <path> --memory <MB>
```

### Arguments

- `--kernel <path>`: Path to the kernel image (vmlinux)
- `--rootfs <path>`: Path to the root filesystem image (rootfs.ext4)
- `--memory <MB>`: Amount of memory in megabytes

### Example

```bash
cd linux
./linux-vm-boot --kernel ../kernel/vmlinux --rootfs ../rootfs/rootfs.ext4 --memory 128
```

## Behavior

- Generates a Firecracker JSON configuration dynamically
- Boots a VM using Firecracker
- Dumps VM console output to stdout
- Exits when the VM stops
- Cleans up temporary files on exit

## Configuration

The wrapper creates a Firecracker configuration with:

- **Boot args**: `console=ttyS0 reboot=k panic=1 pci=off root=/dev/vda rw`
- **1 vCPU**: Single virtual CPU
- **Memory**: As specified by `--memory` argument
- **Root device**: virtio-blk device (`/dev/vda`)
- **Network**: virtio-net device with TAP interface (optional)

## Networking

The default configuration includes a network interface (`eth0`) with a TAP device (`tap0`). For networking to work:

1. Create a TAP device:
```bash
sudo ip tuntap add tap0 mode tap
sudo ip addr add 172.16.0.1/24 dev tap0
sudo ip link set tap0 up
```

2. Enable IP forwarding:
```bash
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

Note: You may need to adjust the interface name (`eth0`) to match your system.

If you don't need networking, you can comment out the `network-interfaces` section in the script.

## Differences from macOS Wrapper

While both wrappers provide the same command-line interface, there are minor differences:

| Feature | macOS (Virtualization.framework) | Linux (Firecracker) |
|---------|----------------------------------|---------------------|
| Console | `hvc0` (virtio console) | `ttyS0` (serial) |
| Boot args | `console=hvc0 root=/dev/vda rw` | `console=ttyS0 reboot=k panic=1 pci=off root=/dev/vda rw` |
| Network | Automatic NAT | Manual TAP setup required |

Both use `/dev/vda` for the root device and support the same kernel and rootfs images.

## Troubleshooting

**"firecracker command not found"**: Install Firecracker as described above.

**"Permission denied" on /dev/kvm**: Ensure KVM is enabled and you have permissions:
```bash
sudo chmod 666 /dev/kvm
```

**"Failed to create VM"**: Check that:
- KVM is available: `lsmod | grep kvm`
- The kernel is uncompressed (vmlinux, not bzImage)
- The rootfs is a valid ext4 image

**Network not working**: Set up the TAP device and routing as described in the Networking section.
