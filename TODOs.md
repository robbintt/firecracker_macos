# TODOs

## Completed

- [x] **ARM64 macOS support** — Boot Linux VMs on Apple Silicon via Virtualization.framework
- [x] **Dual-arch rootfs** — Build both x86_64 and aarch64 rootfs images from x86_64 Linux host
- [x] **QEMU cross-compilation** — ARM64 rootfs builds via qemu-user-static on x86_64
- [x] **Console echo fix** — stty -echo for hvc0 to prevent double-echo on macOS
- [x] **--no-network flag** — Console-only mode for macOS VM boot
- [x] **setup-debian.sh update** — Installs qemu-user-static for cross-compilation

## In Progress

- [ ] **Linux networking** — TAP device setup script for Firecracker

## Low Priority

- **Rootfs build without sudo** — Explore alternatives to requiring root for rootfs builds (container-based build, libguestfs, user namespaces)
- **Shared folders (virtio-fs)** — Mount host directories in guest
- **Vsock support** — Host↔guest IPC without networking
- **Rust unified shim** — Single Rust binary to replace Swift (macOS) + Bash (Linux) wrappers. Enables shared orchestration logic, type-safe cross-platform code, and aligns with Firecracker's language. Beneficial for multi-agent fan-out workflows (`*_disk_ideas.md`) where duplicating orchestration in two languages adds friction. FFI to Virtualization.framework on macOS, direct Firecracker API on Linux.
