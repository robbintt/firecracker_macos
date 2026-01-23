# macOS VM Wrapper

A thin Swift CLI wrapper for booting VMs using Apple's Virtualization.framework.

## Requirements

- macOS 13.0 or later
- Xcode Command Line Tools or Xcode
- Swift 5.9 or later

## Building

```bash
cd macos
./build.sh
```

This will produce a `macos-vm-boot` binary in the `macos/` directory.

## Usage

```bash
./macos-vm-boot --kernel <path> --rootfs <path> --memory <MB>
```

### Arguments

- `--kernel <path>`: Path to the kernel image (vmlinux)
- `--rootfs <path>`: Path to the root filesystem image (rootfs.ext4)
- `--memory <MB>`: Amount of memory in megabytes

### Example

```bash
./macos-vm-boot --kernel ../kernel/vmlinux --rootfs ../rootfs/rootfs.ext4 --memory 128
```

## Behavior

- Boots a VM using Apple's Virtualization.framework
- Uses virtio devices for block storage, console, network, and entropy
- Dumps VM console output to stdout
- Exits when the VM stops

## Architecture

The wrapper consists of two main components:

1. **main.swift**: Handles command-line argument parsing and validation
2. **VMManager.swift**: Sets up and manages the VM lifecycle using Virtualization.framework

The VM is configured with:
- Linux boot loader with kernel command line `console=hvc0 root=/dev/vda rw`
- Virtio block device for the root filesystem
- Virtio console device attached to stdin/stdout
- Virtio network device with NAT attachment
- Virtio entropy device for `/dev/random`
- Memory balloon device for memory management

## Troubleshooting

### Build Errors

If you encounter build errors, ensure:
- You're running on macOS 13.0 or later
- Swift 5.9+ is installed: `swift --version`
- Xcode Command Line Tools are installed: `xcode-select --install`

### Runtime Errors

**"Kernel file not found"**: Ensure the kernel path is correct and the file exists.

**"Rootfs file not found"**: Ensure the rootfs path is correct and the file exists.

**"Failed to start VM"**: Check that:
- The kernel is a valid Linux kernel binary
- The rootfs is a valid ext4 image
- You have sufficient memory available
