# Firecracker macOS

Ultra-lean MVP for macOS/Linux VM parity using Firecracker on Linux and Virtualization.framework on macOS, with shared kernel and rootfs artifacts.

## Overview

This project enables you to boot **identical Linux VM workloads** on both macOS and Linux using:
- **Linux**: [Firecracker](https://github.com/firecracker-microvm/firecracker) microVM
- **macOS**: Apple [Virtualization.framework](https://developer.apple.com/documentation/virtualization)

Both platforms use the **same kernel binary** (`vmlinux`) and **same root filesystem image** (`rootfs.ext4`), with thin platform-specific wrappers providing a unified command-line interface.

## Quick Start

### Prerequisites

**macOS**:
- macOS 13.0+ (Ventura or later)
- Xcode Command Line Tools
- Swift 5.9+

**Linux**:
- Linux with KVM support
- GCC/Make/standard build tools
- Firecracker binary (auto-installed by `setup-debian.sh`)
- **qemu-user-static** (for ARM64 rootfs cross-compilation)

**Install dependencies**:
```bash
# Debian/Ubuntu
sudo apt-get install qemu-user-static binfmt-support

# RHEL/Fedora
sudo dnf install qemu-user-static

# Arch
sudo pacman -S qemu-user-static qemu-user-static-binfmt
```

### Build Everything

```bash
# 1. Build kernel (Linux only, takes 10-30 minutes)
cd kernel
./build-kernel.sh          # x86_64 (Intel Macs, Linux)
./build-kernel.sh arm64    # ARM64 (Apple Silicon) - cross-compile
cd ..

# 2. Build rootfs (Linux only, requires sudo)
cd rootfs
sudo ./build-rootfs.sh              # Builds both x86_64 and ARM64
# Or build single architecture:
# sudo ./build-rootfs.sh --arch=x86_64
# sudo ./build-rootfs.sh --arch=aarch64
cd ..

# 3. Build platform wrapper
# On macOS:
cd macos
./build.sh
cd ..

# On Linux: nothing to build (shell script)
```

### Run a VM

**macOS**:
```bash
# Apple Silicon (networking requires --no-network for now):
./macos/macos-vm-boot --kernel kernel/vmlinux-arm64 --rootfs rootfs/rootfs-aarch64.ext4 --memory 128 --no-network

# Intel Mac (if you built x86_64):
./macos/macos-vm-boot --kernel kernel/vmlinux --rootfs rootfs/rootfs-x86_64.ext4 --memory 128
```

**Linux** (networking requires TAP setup, use --no-network for console-only):
```bash
./linux/linux-vm-boot --kernel kernel/vmlinux --rootfs rootfs/rootfs-x86_64.ext4 --memory 128 --no-network
```

**Login**: `root` / `root`

Inside the VM, you can run:
```bash
/root/test.sh  # Run system tests
poweroff       # Shutdown the VM (cleanly restores terminal)

## Architecture

```
┌──────────────────────────────────────────────────┐
│              User Interface                       │
│  ./macos-vm-boot OR ./linux-vm-boot              │
│  --kernel vmlinux --rootfs rootfs.ext4 --memory  │
└───────────────┬──────────────────────────────────┘
                │
        ┌───────┴────────┐
        │                │
┌───────▼────────┐  ┌────▼──────────────┐
│ Virtualization │  │   Firecracker     │
│   .framework   │  │                   │
│    (macOS)     │  │     (Linux)       │
└───────┬────────┘  └────┬──────────────┘
        │                │
        └───────┬────────┘
                │
     ┌──────────▼───────────┐
     │  Shared Artifacts    │
     │  • vmlinux (kernel)  │
     │  • rootfs.ext4       │
     └──────────────────────┘
```

### Key Features

- ✅ **Same Interface**: Identical CLI on both platforms
- ✅ **Shared Kernel**: Single `vmlinux` binary works on both
- ✅ **Shared Rootfs**: Single `rootfs.ext4` image works on both
- ✅ **Minimal**: No REST API, no complex abstractions
- ✅ **Fast**: Boots in ~1-2 seconds
- ✅ **Tiny**: ~10-20 MB kernel, ~50 MB rootfs (Alpine Linux)

### Components

1. **Kernel** (`kernel/`): Minimal Linux kernel config with virtio drivers
2. **Rootfs** (`rootfs/`): Alpine Linux-based ext4 root filesystem
3. **macOS Wrapper** (`macos/`): Swift CLI using Virtualization.framework
4. **Linux Wrapper** (`linux/`): Bash script wrapper for Firecracker
5. **Tests** (`tests/`): Boot validation and guest test scripts
6. **CI** (`.github/workflows/`): Automated build and test pipeline

## Directory Structure

```
firecracker_macos/
├── README.md                    # This file
├── docs/
│   ├── ARCHITECTURE.md          # Detailed architecture documentation
│   └── TROUBLESHOOTING.md       # Common issues and solutions
├── kernel/
│   ├── README.md                # Kernel build documentation
│   ├── build-kernel.sh          # Kernel build script
│   ├── microvm-kernel.config    # Minimal kernel configuration
│   └── vmlinux                  # Built kernel (after build)
├── rootfs/
│   ├── README.md                # Rootfs build documentation
│   ├── build-rootfs.sh          # Rootfs build script
│   ├── overlay/                 # Files to copy into rootfs
│   │   └── init                 # Custom init script
│   └── rootfs.ext4              # Built rootfs image (after build)
├── linux/
│   ├── README.md                # Linux wrapper documentation
│   └── linux-vm-boot            # Firecracker wrapper script
├── macos/
│   ├── README.md                # macOS wrapper documentation
│   ├── build.sh                 # Build script
│   ├── Package.swift            # Swift package manifest
│   ├── Sources/
│   │   └── macos-vm-boot/
│   │       ├── main.swift       # CLI argument parsing
│   │       └── VMManager.swift  # VM lifecycle management
│   └── macos-vm-boot            # Built binary (after build)
├── tests/
│   ├── test-boot.sh             # Boot validation script
│   └── guest-test.sh            # Guest VM test script
└── .github/
    └── workflows/
        └── ci.yml               # CI/CD pipeline
```

## Unified CLI Interface

Both wrappers expose the same interface:

```bash
Usage: {macos-vm-boot|linux-vm-boot} --kernel <path> --rootfs <path> --memory <MB> [--cpus <N>]

Options:
  --kernel <path>    Path to the kernel image (vmlinux)
  --rootfs <path>    Path to the root filesystem image (rootfs.ext4)
  --memory <MB>      Amount of memory in megabytes
  --cpus <N>         Number of CPUs (default: 1)
  --help, -h         Show help message
```

This allows:
- Same automation scripts on both platforms
- Easy development environment switching
- Consistent testing and validation

## Platform Requirements

### macOS

- **OS**: macOS 13.0 (Ventura) or later
- **Hardware**: Intel or Apple Silicon (M1/M2/M3)
- **Tools**: Xcode Command Line Tools, Swift 5.9+

### Linux

- **OS**: Any modern Linux distribution
- **Hardware**: x86_64 with KVM support
- **Tools**: 
  - Build: GCC, make, flex, bison, libelf-dev, libssl-dev, bc
  - Runtime: Firecracker v1.0+, KVM access

## Build Instructions

### 1. Build Kernel (Linux)

The kernel must be built on Linux:

```bash
cd kernel
./build-kernel.sh
```

This downloads Linux kernel source (v6.1.112), applies the minimal microVM config, and builds `vmlinux` (~10-20 MB).

**Time**: 10-30 minutes  
**Disk**: ~5-10 GB (source + build artifacts)

See [kernel/README.md](kernel/README.md) for details.

### 2. Build Rootfs (Linux)

The rootfs must be built on Linux with root access:

```bash
cd rootfs
sudo ./build-rootfs.sh  # Builds both x86_64 and ARM64
```

This creates two 256 MB ext4 images with Alpine Linux v3.19:
- `rootfs-x86_64.ext4` - for x86_64 Linux/Firecracker
- `rootfs-aarch64.ext4` - for ARM64 macOS/Apple Silicon

**ARM64 Cross-Compilation**: When building ARM64 on x86_64, the script automatically uses QEMU user-mode emulation to run ARM64 binaries. Requires `qemu-user-static` package (see Prerequisites).

**Time**: 2-4 minutes (both architectures)
**Disk**: ~600 MB (both images)

See [rootfs/README.md](rootfs/README.md) for details.

### 3. Build Platform Wrapper

**macOS**:
```bash
cd macos
./build.sh
```

Produces `macos/macos-vm-boot` binary.

**Linux**:  
The `linux/linux-vm-boot` script is ready to use (no build needed).

## Testing

Run the boot validation test:

```bash
cd tests
./test-boot.sh
```

This validates:
- Argument parsing
- File existence checks
- Error handling

For full VM boot testing, run manually and execute the guest test inside the VM:

```bash
# Start VM (macOS or Linux)
./macos/macos-vm-boot --kernel kernel/vmlinux --rootfs rootfs/rootfs.ext4 --memory 128

# Inside the VM:
/root/test.sh  # Run system tests
poweroff       # Shutdown
```

## CI/CD

The GitHub Actions workflow (`.github/workflows/ci.yml`) automatically:

**Linux job**:
1. Builds kernel and rootfs
2. Installs Firecracker
3. Runs boot tests
4. Uploads artifacts

**macOS job**:
1. Builds Swift wrapper
2. Tests argument parsing
3. Uploads binary

**Cross-platform test**:
1. Downloads artifacts from both platforms
2. Verifies interface compatibility
3. Tests with shared artifacts

## Documentation

- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**: Detailed architecture, design decisions, and internals
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)**: Common issues and solutions

Each component also has its own README:
- [kernel/README.md](kernel/README.md)
- [rootfs/README.md](rootfs/README.md)
- [macos/README.md](macos/README.md)
- [linux/README.md](linux/README.md)

## Use Cases

This project is ideal for:

- **Development**: Consistent VM environments across Mac and Linux workstations
- **Testing**: Validate software in lightweight VMs on any platform
- **CI/CD**: Fast VM-based integration tests
- **Learning**: Understand microVMs and virtualization
- **Prototyping**: Quick VM experiments without complex setup

## Performance

- **Boot time**: ~1-2 seconds from command to shell prompt
- **Memory**: 64-256 MB (configurable)
- **Disk**: 256 MB rootfs (sparse), 10-20 MB kernel
- **Shutdown**: Immediate (or ~1 second for clean shutdown)

## Design Philosophy

1. **Simplicity**: No REST APIs, no complex abstractions, just CLI tools
2. **Portability**: Same artifacts work on both platforms
3. **Minimalism**: Tiny kernel, tiny rootfs, minimal dependencies
4. **Transparency**: Simple shell scripts and straightforward code
5. **Testability**: Automated tests for everything

## Limitations

- No live migration or snapshots (MVP scope)
- No GUI (console only)
- **macOS**: NAT networking works out of the box
- **Linux**: Networking requires manual TAP setup (see PLAN.md); use `--no-network` for console-only
- Not suitable for production workloads (MVP/development use)

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for details on limitations and future enhancements.

## Contributing

Contributions welcome! Areas for improvement:

- Multi-CPU support
- Snapshot/restore functionality
- Automatic network setup on Linux
- Additional rootfs templates (Ubuntu, Debian, etc.)
- Performance optimizations
- Documentation improvements

## License

MIT License - see LICENSE file for details.

## Credits

- [Firecracker](https://github.com/firecracker-microvm/firecracker): Lightweight virtualization on Linux
- [Alpine Linux](https://alpinelinux.org/): Minimal Linux distribution
- Apple [Virtualization.framework](https://developer.apple.com/documentation/virtualization): Native macOS virtualization

## See Also

- [Firecracker Documentation](https://github.com/firecracker-microvm/firecracker/tree/main/docs)
- [Apple Virtualization Framework](https://developer.apple.com/documentation/virtualization)
- [Linux Kernel Documentation](https://www.kernel.org/doc/html/latest/)
- [Alpine Linux Documentation](https://wiki.alpinelinux.org/)