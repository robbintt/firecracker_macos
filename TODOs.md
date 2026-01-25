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

## Medium Priority (Original Intent)

- **Firecracker API shim** — The project name implies Firecracker API compatibility on macOS. Current implementation is a separate CLI with no API compatibility. To close this gap:
  - Implement Firecracker REST API (`/machine-config`, `/boot-source`, `/drives`, `/actions`, etc.)
  - Translate to VZ.framework calls on macOS
  - Existing Firecracker SDKs/tooling then works on macOS
  - See WHY.md "The Lost Thread" for details

- **Rust unified shim** — Single Rust binary to replace Swift (macOS) + Bash (Linux) wrappers. Natural path to API shim above. FFI to VZ.framework on macOS, native Firecracker integration on Linux. Aligns with Firecracker's language.

## Low Priority

- **Rootfs build without sudo** — Explore alternatives to requiring root for rootfs builds (container-based build, libguestfs, user namespaces)
- **Shared folders (virtio-fs)** — Mount host directories in guest
- **Vsock support** — Host↔guest IPC without networking
- **Use Firecracker prebuilt kernels** — Firecracker provides prebuilt vmlinux kernels for x86_64 and aarch64 at `github.com/firecracker-microvm/firecracker/tree/main/resources`. These may work with VZ.framework (same format, virtio drivers included). If so, the entire `kernel/` build process is unnecessary. Test: download `microvm-kernel-arm64-*.bin`, try with `macos-vm-boot`. Could eliminate 10-30 min kernel build step.

- **Container image integration** — Firecracker wants raw kernel + ext4, not Docker images. Options to bridge:
  - **firecracker-containerd** — Official containerd runtime using Firecracker as backend. Runs OCI containers in microVMs. Most mature option.
  - **Kata Containers** — Runs OCI containers inside Firecracker VMs. Heavier abstraction.
  - **Custom converter** — Script: `docker export` → tarball → ext4 image. Simple, no dependencies.
  - **Flintlock** — Creates microVMs from container images. Weaveworks project.

  Conversion flow: Docker image → extract layers → flatten → create ext4 → copy files → boot with kernel.

  For this project: firecracker-containerd is the path if container workflows needed. Current manual rootfs approach gives more control.
