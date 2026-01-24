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

**Linux wrapper:** At parity with macOS.

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
