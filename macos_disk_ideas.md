# macOS Disk Strategy for Multi-Agent Fan-Out

This document mirrors the Linux disk_ideas.md approach but uses macOS-native primitives.

## Goal

1 base state (codebase at main HEAD) → fan out to N agents → each needs isolated filesystem → don't copy N× the data.

## Platform Primitives

### APFS Clones (Copy-on-Write Disk Images)

APFS supports instant, zero-copy file clones. Cloning a 10GB disk image takes milliseconds and consumes no additional space until writes diverge.

```bash
# Create base image (one-time)
hdiutil create -size 10g -fs APFS -volname base base.dmg

# Instant CoW clone for each agent
cp -c base.dmg agent-1.dmg
cp -c base.dmg agent-2.dmg
# ... etc
```

Each clone shares blocks with base until written. Writes allocate new blocks, base stays immutable.

### Virtualization.framework Snapshots

macOS Virtualization.framework supports pausing VMs and saving state:

```swift
// Pause VM
try await vm.pause()

// Save state to file
try await vm.saveMachineStateTo(url: snapshotURL)

// Later: restore
try await vm.restoreMachineStateFrom(url: snapshotURL)
```

This captures CPU/memory state. Combined with APFS clones for disk, we get full VM snapshots.

### Vsock

Same as Linux—`VZVirtioSocketDeviceConfiguration` provides host↔guest IPC without networking. Protocol can be identical across platforms.

## Fan-Out Workflow

```
1. Prepare base:
   - Boot VM with base.dmg
   - git checkout main && npm install (or equivalent)
   - Pause VM, save state → base.vmstate
   - Shutdown

2. Fan-out:
   for i in 1..N:
     - cp -c base.dmg agent-${i}.dmg        # instant
     - Boot VM with agent-${i}.dmg
     - Restore from base.vmstate
     - Send task via vsock
     - VM executes, streams results via vsock
     - Shutdown, discard or save agent-${i}.dmg

3. Collect results:
   - Compare N outputs
   - Select winner
   - Optionally preserve winning agent's disk
```

## Timing Expectations

| Operation | Time |
|-----------|------|
| APFS clone (10GB image) | <100ms |
| VM state restore | ~200-500ms |
| Total per-agent overhead | <1 second |

Note: Virtualization.framework restore is slower than Firecracker (~50-100ms), but still fast enough for practical fan-out.

## Comparison to Linux Approach

| Aspect | Linux (Firecracker) | macOS (Virtualization.framework) |
|--------|---------------------|----------------------------------|
| Disk CoW | overlayfs | APFS clones |
| VM snapshots | Firecracker native | `saveMachineStateTo` |
| Restore speed | ~50-100ms | ~200-500ms |
| vsock | ✅ | ✅ |
| Nested VMs | ✅ | ❌ |

## Limitations

1. **No nested virtualization** — Can't run Firecracker inside a macOS VM. Each platform uses its native hypervisor.

2. **Restore speed** — Virtualization.framework is ~2-5× slower than Firecracker for snapshot restore. For 10 agents this adds ~2-4 seconds total, acceptable for most workflows.

3. **ARM64 only** (Apple Silicon) — Intel Macs use older Hypervisor.framework with different APIs.

## Implementation Checklist

- [ ] Vsock support in macOS wrapper (`VZVirtioSocketDeviceConfiguration`)
- [ ] Snapshot save/restore in macOS wrapper
- [ ] APFS clone helper script
- [ ] Unified fan-out API that dispatches to platform-native implementation

## Abstraction Layer

User-facing API should hide platform differences:

```
Orchestrator.fan_out(
    base: Snapshot,
    count: 10,
    task: TaskDefinition
) -> [Result]
```

Internally:
- Detects platform
- Uses overlayfs + Firecracker on Linux
- Uses APFS clones + Virtualization.framework on macOS
- Same vsock protocol for task dispatch on both
