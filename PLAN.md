# PLAN.md

## Current State

**Wired up (macOS):**
- CPU (configurable via `--cpus`)
- Memory (configurable)
- Block device (virtio, rw)
- Console (virtio, stdin/stdout)
- Entropy (`/dev/random`)
- Memory balloon
- Networking (NAT)
- ARM64 kernel boot (Apple Silicon) ✅
- `--no-network` flag for console-only mode ✅

**Linux wrapper:** At parity with macOS.

**Dual-architecture rootfs build:**
- `rootfs-x86_64.ext4` for x86_64 Linux/Firecracker ✅
- `rootfs-aarch64.ext4` for ARM64 macOS/Apple Silicon ✅
- Cross-compilation via QEMU user-mode emulation ✅
- Console echo fix for hvc0 (stty -echo) ✅

## Recent Progress

- **2024-01**: ARM64 VM successfully boots on macOS Apple Silicon
  - Kernel: `vmlinux-arm64` (Image format, not bzImage)
  - Rootfs: Alpine Linux aarch64 via QEMU cross-compilation
  - Console: virtio hvc0 with echo fix
  - Setup: `setup-debian.sh` installs `qemu-user-static` for cross-builds

## TODO

### High Priority

1. **Linux networking**
   - TAP device setup script
   - Document network config for Firecracker

2. **Shared folders (virtio-fs)**
   - `VZVirtioFileSystemDeviceConfiguration` on macOS
   - Useful for dev workflows (share code into VM)
   - Add `--share <host_path>:<guest_mount>` flag

### Medium Priority

3. **Vsock support**
   - `VZVirtioSocketDeviceConfiguration` on macOS
   - Host↔guest IPC without networking
   - Firecracker also supports vsock

4. **Snapshots/restore**
   - Virtualization.framework supports this
   - Firecracker supports snapshots too

### Low Priority

5. **Rosetta for Linux** (Apple Silicon only)
   - Run x86 binaries on ARM VMs
   - `VZLinuxRosettaDirectoryShare`

6. **GPU/display**
   - `VZVirtioGraphicsDeviceConfiguration`
   - Only if GUI use cases emerge

7. **Audio**
   - `VZVirtioSoundDeviceConfiguration`
   - Low priority for server/dev VMs

## Observations

- Networking already works on macOS (NAT) - README was outdated
- Linux is the build host for kernel/rootfs; macOS just runs them
- Consider pre-built artifact downloads for macOS-only users
