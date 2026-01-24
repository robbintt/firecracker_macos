The Challenge:
1 base state (codebase at main HEAD) → fan out to 10 agents → each needs isolated filesystem → don't copy 10x the data.

Solution: Copy-on-Write Block Devices

---

Approach 1: Firecracker Snapshot + CoW Volumes (Recommended)
How it works:

    Boot VM, checkout main HEAD, install deps → checkpoint

Snapshot creates base disk image (immutable)Spawn 10 VMs, each gets CoW overlay on top of base disk

    Each VM writes to its own overlay (base stays read-only)

After task completes, throw away overlays or merge changes
Tech stack:

    dm-snapshot (Linux device mapper) for CoW

Firecracker snapshots for VM stateqcow2 or raw + overlayfs for block storage

Setup:

# 1. Create base image (main HEAD + deps installed)
firecracker --config base.json
# ... install deps, checkout main ...
# Checkpoint VM state
curl -X PUT firecracker-api/snapshot/create --data '{"snapshot_path": "base.snap", "mem_file_path": "base.mem"}'

# 2. Create CoW overlay for each agent
for i in {1..10}; do
  # Create overlay device
  qemu-img create -f qcow2 -b base.img agent-${i}.qcow2
  
  # Restore VM from snapshot with unique overlay
  firecracker --config agent-${i}.json \
    --snapshot base.snap \
    --mem-file base.mem \
    --drive agent-${i}.qcow2
done



Pros:

    Near-instant fan-out (no data copying)

Each agent sees full codebase + can modify independently

    Base image immutable (safe for concurrent access)

Firecracker native (no external deps)
Cons:

    qcow2 has overhead (~10-15% slower than raw)

Merging changes back to base requires logic
---

Approach 2: overlayfs (Union Mount) - Faster, Linux-Native
How it works:

    Base rootfs (read-only layer) with codebase at main HEAD

Each VM gets unique upper layer (writable)overlayfs merges base + upper → VM sees unified viewAll writes go to upper layer, base untouched
Setup:

# Base layer (read-only, shared)
mkdir -p /mnt/base-rootfs
# ... codebase at main HEAD ...

# Per-agent overlays
for i in {1..10}; do
  mkdir -p /mnt/overlay-${i}/{upper,work}
  
  # Mount overlay for VM
  mount -t overlay overlay \
    -o lowerdir=/mnt/base-rootfs,upperdir=/mnt/overlay-${i}/upper,workdir=/mnt/overlay-${i}/work \
    /mnt/vm-${i}
  
  # Attach /mnt/vm-${i} as block device to Firecracker VM

done



Pros:

    Fastest (no qcow2 overhead, kernel-native)

True CoW (only changed blocks stored in upper)Easy cleanup (rm -rf /mnt/overlay-*)Can merge changes: rsync upper → base
Cons:

    Requires host filesystem support (ext4/xfs work fine)

Slightly more complex setup than qcow2
---

Approach 3: BTRFS/ZFS Snapshots - Enterprise-Grade
How it works:

    Base subvolume with codebase

Instant snapshot → 10 clones (CoW)Each VM gets dedicated snapshot

Setup (BTRFS):

# Base subvolume
btrfs subvolume create /mnt/base-codebase
# ... populate with main HEAD ...

# Instant clones
for i in {1..10}; do
  btrfs subvolume snapshot /mnt/base-codebase /mnt/agent-${i}
done

Pros:

    Instant snapshots (copy-on-write at filesystem level)

Reliable, battle-testedCan diff snapshots easily
Cons:

    Requires BTRFS/ZFS filesystem (can't use ext4)

Heavier than overlayfs
---

Data Transport at Boundary
Inbound (Agent → VM):

    Task definition, git ref, test commands

Transport: vsock (structured JSON)
Outbound (VM → Agent):

    Test results, build artifacts, diffs

Transport: vsock (structured) or shared volume (file-based)
Checkpoint State:

    VM memory snapshot (base.mem)

Block device snapshot (base.img or overlayfs base)Restore time: <100ms (Firecracker specialty)
---

Fan-Out Workflow

1. Agent receives task: "Try 10 variations of refactor X"

2. Prepare base:
   - Boot VM
   - git checkout main
   - npm install (or build cache)
   - Checkpoint VM → base.snap + base.mem
   - Shutdown

3. Fan-out:
   for i in 1..10:
     - Create CoW overlay (overlayfs or qcow2)
     - Restore VM from base.snap
     - Send variation #i instructions via vsock
     - VM applies changes, runs tests
     - Results streamed back via vsock
     - VM exits, overlay destroyed or saved

4. Collect results:
   - Agent compares 10 outputs
   - Select best variation
   - Commit winning diff



Timing:

    Base checkpoint: 1-2 seconds (one-time)

Per-agent restore: 50-100msTotal fan-out overhead: <1 second for 10 agents
---

Recommendation
Use overlayfs for speed + simplicity:

    Base rootfs = main HEAD + deps (read-only)

Upper layers = per-agent scratch spaceFirecracker boots with overlayfs-mounted rootfsAfter run: save diffs from upper layer or discard
Why not qcow2? Overhead. You want raw speed for coding agents.
Why not BTRFS? Unless you're already on it, don't add filesystem complexity.

Implementation:

    Build Debian/Alpine rootfs with overlayfs support

Script to create N overlays from baseFirecracker boot script takes overlay path as argvsock server for task dispatch + result collection

Want me to draft the overlay setup script or the vsock protocol spec?
