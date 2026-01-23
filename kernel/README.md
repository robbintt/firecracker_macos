# Kernel Build

Minimal Linux kernel configuration for microVMs that boots on both Firecracker (Linux) and Apple Virtualization.framework (macOS).

## Requirements

### Linux
- GCC or Clang
- make
- flex
- bison
- libelf-dev
- libssl-dev
- bc
- wget

On Ubuntu/Debian:
```bash
sudo apt-get install build-essential flex bison libelf-dev libssl-dev bc wget
```

### macOS
The kernel itself is built on Linux. macOS users should use the pre-built kernel or build on a Linux machine/VM.

## Building

```bash
cd kernel
./build-kernel.sh
```

This will:
1. Download Linux kernel source (v6.1.112)
2. Apply the minimal microVM configuration
3. Build the kernel
4. Output `vmlinux` in the `kernel/` directory

The build process may take 10-30 minutes depending on your system.

## Configuration

The `microvm-kernel.config` file contains a minimal kernel configuration optimized for:

- **Virtio drivers**: Required for both Firecracker and Virtualization.framework
  - virtio-blk (block devices)
  - virtio-net (networking)
  - virtio-console (serial console)
  - virtio-balloon (memory management)
  - virtio-rng (entropy/random numbers)

- **Minimal footprint**: Only essential drivers and features enabled

- **Fast boot**: Optimized for quick startup times

- **Cross-platform compatibility**: Works with both Firecracker and Apple's hypervisor

## Kernel Command Line

The kernel is typically booted with:
```
console=hvc0 root=/dev/vda rw
```

Where:
- `console=hvc0`: Virtio console device
- `root=/dev/vda`: Root filesystem on first virtio block device
- `rw`: Mount root filesystem read-write

## Size

The resulting uncompressed kernel (`vmlinux`) is typically 10-20 MB.

## Customization

To modify the kernel configuration:

1. Edit `microvm-kernel.config`
2. Run `./build-kernel.sh` to rebuild

Key areas for customization:
- **Networking**: Additional protocols, netfilter rules
- **Filesystems**: Support for other filesystem types
- **Security**: SELinux, AppArmor, additional hardening
- **Debugging**: Additional debugging options for development

## Troubleshooting

**Build fails**: Ensure all dependencies are installed and you have sufficient disk space (5-10 GB).

**Kernel doesn't boot**: Check that virtio drivers are enabled in the config.

**Console output missing**: Ensure `CONFIG_VIRTIO_CONSOLE=y` and `CONFIG_HVC_DRIVER=y` are set.
