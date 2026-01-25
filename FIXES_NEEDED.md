# Fixes Needed

Critical issues and session followups.

## Critical Issues

### 1. No Signal Handling (Swift)

**File:** `macos/Sources/macos-vm-boot/VMManager.swift`

**Problem:** Ctrl+C kills the host process immediately. VM doesn't shut down cleanly. Orphaned resources possible.

**Fix:**
- Catch SIGINT/SIGTERM
- Send ACPI shutdown to VM (or `vm.stop()`)
- Wait for clean exit
- Restore terminal state

### 2. Busy-Wait Polling Loop

**File:** `macos/Sources/macos-vm-boot/VMManager.swift:59-61`

**Problem:**
```swift
while !shouldStop {
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1s polling - wastes CPU
}
```

**Fix:** Use async continuation or semaphore:
```swift
await withCheckedContinuation { continuation in
    self.stopContinuation = continuation
}
// In guestDidStop delegate: stopContinuation?.resume()
```

### 3. No Terminal Save/Restore (Swift)

**File:** `macos/Sources/macos-vm-boot/VMManager.swift`

**Problem:** If VM crashes or is killed, terminal is left in corrupted state. Linux wrapper has `stty sane` in trap, Swift has nothing.

**Fix:**
- Save terminal state on start (`tcgetattr`)
- Restore on exit (including signal handlers)
- Set raw mode for proper key passthrough

### 4. No Raw Terminal Mode

**Problem:** Special keys (arrows, Ctrl sequences) may not work correctly in guest because terminal isn't in raw mode.

**Fix:** Use `cfmakeraw()` equivalent in Swift to configure terminal for VM console.

### 5. Rootfs Mutable Without CoW

**Problem:** Direct read-write to rootfs image. Running two VMs or crashing mid-write = corruption.

**Fix (short-term):** Warn user if rootfs is in use.

**Fix (long-term):** Implement CoW overlays as described in `*_disk_ideas.md`.

### 6. Console Echo Workaround

**File:** `rootfs/build-rootfs.sh` (serial-console init script)

**Problem:** We added `stty -F /dev/hvc0 -echo` as a workaround. Real fix is proper terminal setup on host side.

**Fix:** Handle terminal configuration in Swift wrapper, not guest init scripts.

---

## Session Followups

### Files Modified This Session

- `rootfs/build-rootfs.sh` - Dual-arch build (x86_64 + aarch64), QEMU cross-compilation, echo fix
- `setup-debian.sh` - Added qemu-user-static dependency
- `README.md` - Updated for dual-arch rootfs
- `PLAN.md` - Added ARM64 progress, current state
- `TODOs.md` - Added completed items, Rust shim idea

### Files to Sync to Debian Build Machine

The updated `build-rootfs.sh` must be synced before rebuilding:
```bash
rsync -avz rootfs/build-rootfs.sh USER@DEBIAN:~/firecracker_macos/rootfs/
```

### Rebuild Required

After syncing, rebuild ARM64 rootfs with echo fix:
```bash
cd rootfs && sudo ./build-rootfs.sh --arch=aarch64 --force
```

Then sync back to Mac:
```bash
rsync -avz rootfs/rootfs-aarch64.ext4 USER@MAC:~/firecracker_macos/rootfs/
```

### Testing Pending

- [ ] Verify `stty -echo` fix works after rootfs rebuild
- [ ] Test x86_64 rootfs on Linux/Firecracker
- [ ] Test graceful shutdown (`poweroff` in guest)

---

## Priority Order

1. **Signal handling** - Users will Ctrl+C, this must work
2. **Terminal save/restore** - Corrupted terminal is frustrating
3. **Polling loop** - CPU waste, less urgent
4. **Raw terminal mode** - Usability issue
5. **Rootfs CoW** - Data safety, requires more work
