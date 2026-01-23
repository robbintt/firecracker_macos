# Architecture

This document describes the architecture of the firecracker_macos project - an ultra-lean MVP for achieving macOS/Linux VM parity.

## Overview

The goal is to boot **identical VM workloads** on both macOS and Linux using:
- **Linux**: Firecracker microVM
- **macOS**: Apple Virtualization.framework

Both platforms use the **same kernel binary** and **same root filesystem image**, with platform-specific thin wrappers providing a unified CLI interface.

## Components

```
┌─────────────────────────────────────────────────────────────┐
│                         User                                 │
└────────────────┬──────────────────┬─────────────────────────┘
                 │                  │
                 │                  │
    ┌────────────▼──────────┐  ┌───▼──────────────────┐
    │  macos-vm-boot        │  │  linux-vm-boot       │
    │  (Swift)              │  │  (Bash)              │
    └────────────┬──────────┘  └───┬──────────────────┘
                 │                  │
                 │                  │
    ┌────────────▼──────────┐  ┌───▼──────────────────┐
    │  Virtualization.      │  │  Firecracker         │
    │  framework            │  │                      │
    └────────────┬──────────┘  └───┬──────────────────┘
                 │                  │
                 └──────────┬───────┘
                            │
              ┌─────────────▼─────────────┐
              │   Shared Artifacts        │
              │  • vmlinux (kernel)       │
              │  • rootfs.ext4 (rootfs)   │
              └───────────────────────────┘
```

## Architecture Layers

### Layer 1: Shared Artifacts

#### Kernel (vmlinux)
- **Source**: Linux kernel v6.1.112
- **Config**: Minimal microVM configuration with virtio drivers
- **Size**: ~10-20 MB uncompressed
- **Format**: ELF64 executable (vmlinux)
- **Key features**:
  - virtio-blk (block devices)
  - virtio-net (networking)
  - virtio-console (serial console)
  - virtio-rng (entropy)
  - ext4 filesystem support

#### Root Filesystem (rootfs.ext4)
- **Base**: Alpine Linux v3.19 minirootfs
- **Size**: 256 MB (sparse)
- **Format**: raw ext4 image
- **Contents**:
  - Minimal Alpine userspace
  - OpenRC init system
  - Basic networking tools
  - Test utilities

### Layer 2: Platform Wrappers

#### macOS: macos-vm-boot (Swift)

A Swift application using Apple's Virtualization.framework:

```swift
VZVirtualMachine {
    bootLoader: VZLinuxBootLoader(kernel)
    storage: VZVirtioBlockDevice(rootfs)
    console: VZVirtioConsoleDevice(stdout)
    network: VZVirtioNetworkDevice(NAT)
    entropy: VZVirtioEntropyDevice()
}
```

**Key characteristics**:
- Compiled binary (`macos-vm-boot`)
- Uses native macOS virtualization APIs
- No external dependencies beyond system frameworks
- Console: virtio console (hvc0)
- Boot args: `console=hvc0 root=/dev/vda rw`

#### Linux: linux-vm-boot (Bash)

A shell script wrapper for Firecracker:

```bash
firecracker --config-file {
    kernel: vmlinux
    rootfs: /dev/vda
    memory: 128MB
    console: serial (ttyS0)
}
```

**Key characteristics**:
- Shell script (portable)
- Generates Firecracker JSON config dynamically
- Requires Firecracker binary
- Console: serial port (ttyS0)
- Boot args: `console=ttyS0 reboot=k panic=1 pci=off root=/dev/vda rw`

### Layer 3: Unified Interface

Both wrappers expose identical CLI interface:

```bash
--kernel <path>   # Path to vmlinux
--rootfs <path>   # Path to rootfs.ext4
--memory <MB>     # Memory in megabytes
```

This abstraction allows:
- Same scripts/automation on both platforms
- Easy switching between development environments
- Consistent testing and validation

## Key Design Decisions

### 1. Virtio Everywhere

**Decision**: Use virtio devices for all I/O

**Rationale**:
- Supported by both Firecracker and Virtualization.framework
- High performance paravirtualized devices
- Industry standard for VMs
- Minimal driver complexity in kernel

**Devices**:
- **virtio-blk**: Block storage (`/dev/vda`)
- **virtio-net**: Networking (`eth0`)
- **virtio-console**: Console I/O (`hvc0` on macOS)
- **virtio-rng**: Entropy (`/dev/random`)
- **virtio-balloon**: Memory management

### 2. Uncompressed Kernel

**Decision**: Use uncompressed vmlinux, not bzImage

**Rationale**:
- Apple Virtualization.framework requires uncompressed ELF kernel
- Firecracker supports both but vmlinux is simpler
- Allows single kernel binary for both platforms
- Boot time difference is negligible for small kernel

### 3. Raw ext4 Image

**Decision**: Use raw ext4 filesystem image

**Rationale**:
- Supported natively by both platforms
- No conversion or mounting complexity
- Direct block device mapping
- Simple to create and modify

### 4. Alpine Linux

**Decision**: Use Alpine Linux as base distribution

**Rationale**:
- Tiny footprint (~30-50 MB installed)
- Fast package manager (apk)
- musl libc (smaller than glibc)
- Well-suited for containers and microVMs

### 5. No REST API

**Decision**: Simple CLI, no REST API or daemon mode

**Rationale**:
- Reduces complexity significantly
- Easier to debug and maintain
- Sufficient for MVP use case
- Can add later if needed

## Boot Flow

### macOS Boot Sequence

1. User runs: `macos-vm-boot --kernel vmlinux --rootfs rootfs.ext4 --memory 128`
2. Swift app parses arguments and validates files
3. Creates `VZVirtualMachineConfiguration`:
   - Sets memory, CPU count
   - Attaches kernel as `VZLinuxBootLoader`
   - Attaches rootfs as `VZVirtioBlockDevice`
   - Sets up console as `VZVirtioConsoleDevice`
4. Starts VM with `VZVirtualMachine.start()`
5. Kernel boots with `console=hvc0 root=/dev/vda rw`
6. Console output streams to stdout
7. VM runs until stopped
8. App exits when VM stops

### Linux Boot Sequence

1. User runs: `linux-vm-boot --kernel vmlinux --rootfs rootfs.ext4 --memory 128`
2. Bash script parses arguments and validates files
3. Generates Firecracker JSON config:
   - Sets memory, CPU count
   - Specifies kernel path and boot args
   - Attaches rootfs as virtio drive
4. Starts Firecracker with config file
5. Kernel boots with `console=ttyS0 root=/dev/vda rw`
6. Console output streams to stdout
7. VM runs until stopped
8. Script exits when VM stops

## Testing Strategy

### Unit Tests
- Argument parsing validation
- File existence checks
- Error handling

### Integration Tests
- Boot tests (platform-specific)
- Guest test script (runs inside VM)
- Artifact compatibility tests

### CI/CD Pipeline

**Linux Job**:
1. Build kernel
2. Build rootfs
3. Install Firecracker
4. Run boot tests
5. Upload artifacts

**macOS Job**:
1. Build Swift wrapper
2. Test argument parsing
3. Upload binary

**Cross-Platform Test**:
1. Download Linux artifacts (kernel, rootfs)
2. Download macOS binary
3. Verify interface compatibility
4. Test with both platforms

## Performance Considerations

### Boot Time
- Target: < 1 second for kernel boot
- Uncompressed kernel adds ~100ms vs compressed
- Alpine init is very fast
- Overall boot typically < 2 seconds

### Memory
- Minimum: 64 MB (though 128 MB recommended)
- Kernel: ~30-40 MB resident
- Alpine base: ~10-20 MB
- Overhead: ~10-15 MB

### Disk
- Kernel: 10-20 MB
- Rootfs: 256 MB (sparse, ~50 MB used)
- Build artifacts: ~2-3 GB (kernel source, build cache)

## Security Considerations

1. **VM Isolation**: Both hypervisors provide hardware-level isolation
2. **No network by default**: Minimal attack surface
3. **Read-write rootfs**: Allows persistent changes (by design for simplicity)
4. **No secrets in repo**: No hardcoded credentials (except default root:root)
5. **Minimal kernel**: Reduced attack surface with minimal drivers

## Extensibility Points

### Adding Features

**Networking**:
- macOS: Already configured (NAT)
- Linux: Requires TAP device setup

**Shared folders**:
- macOS: VZVirtioFileSystemDevice (virtiofs)
- Linux: Firecracker supports virtio-fs

**Multiple disks**:
- Both support additional virtio-blk devices

**More memory**:
- Simply increase `--memory` parameter

**Multiple CPUs**:
- Requires config change in wrapper code

## Limitations

### Current MVP Limitations

1. **No live migration**: VMs cannot be moved between hosts
2. **No snapshots**: No built-in snapshot functionality
3. **No GUI**: Console-only interface
4. **Single CPU**: Fixed to 1 vCPU (for simplicity)
5. **No hot-plug**: Devices cannot be added/removed at runtime
6. **Basic networking**: Linux requires manual TAP setup

### Platform Differences

| Feature | macOS | Linux |
|---------|-------|-------|
| Console | hvc0 (virtio) | ttyS0 (serial) |
| Network | Auto NAT | Manual TAP |
| Performance | Native M1/M2 | KVM |
| Max Memory | Host dependent | Host dependent |

## Future Enhancements

Potential areas for extension beyond MVP:

1. **REST API**: Add optional API server mode
2. **Snapshots**: VM state save/restore
3. **Multiple VMs**: Support running multiple VMs concurrently
4. **Auto-networking**: Automatic TAP setup on Linux
5. **Resource limits**: CPU pinning, I/O throttling
6. **Monitoring**: Metrics and logging
7. **OCI Images**: Support container images as rootfs
8. **ARM support**: Build for Apple Silicon and ARM Linux
