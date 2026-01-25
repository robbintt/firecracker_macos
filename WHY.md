# Why This Project?

Honest assessment of when to use this vs Lima/Colima.

## The Lost Thread

**Original intent** (implied by name "firecracker_macos"):
> Firecracker API, shimmed to VZ.framework on macOS.

**What was actually built:**
> Separate CLI tool that also boots VMs. No API compatibility.

### What Firecracker Provides

- REST API for VM management (`/machine-config`, `/boot-source`, `/drives`, etc.)
- Snapshot/restore via API
- Rate limiters, vsock, metrics
- Ecosystem: SDKs, orchestrators, tooling that speaks the API

### What a Real Shim Would Look Like

```
Firecracker REST API (port 8080)
         │
         ▼
    ┌─────────┐
    │  Shim   │ ← Translates API calls to native backend
    └────┬────┘
         │
    ┌────▼─────────────────┐
    │ VZ.framework (macOS) │
    │ Firecracker (Linux)  │
    └──────────────────────┘
```

Existing Firecracker SDKs and tools would just work on macOS.

### What We Have Instead

```
┌─────────────────┐     ┌─────────────────┐
│ macos-vm-boot   │     │ linux-vm-boot   │
│ (Swift CLI)     │     │ (Bash script)   │
└────────┬────────┘     └────────┬────────┘
         │                       │
    VZ.framework            Firecracker
```

Two separate tools. Similar flags. No API compatibility. No shim.

### Gap to Close

To fulfill the original intent:

1. Implement Firecracker REST API in the macOS wrapper
2. Translate API calls to VZ.framework equivalents
3. Existing Firecracker tooling works on macOS

The **Rust unified shim** in TODOs.md is the path here - single binary that:
- Exposes Firecracker API on both platforms
- Uses native backend (VZ.framework or Firecracker)
- Enables ecosystem compatibility

## Comparison

| This Project | Lima/Colima |
|--------------|-------------|
| ~500 lines, readable | Thousands of lines, complex |
| You control everything | Someone else's abstractions |
| Bugs are your problem | Bugs are community's problem |
| No file sharing, port forwarding | Built-in, works |
| Educational | Production-ready |
| Foundation for custom work | General-purpose |

## Real Advantages

1. **Customization** - If you build the fan-out orchestrator from `*_disk_ideas.md`, you need control Lima doesn't give you
2. **Simplicity** - When something breaks, you can read all 500 lines
3. **No abstractions** - Direct VZ.framework/Firecracker, no YAML configs
4. **Learning** - You understand how macOS VMs actually work

## When to Bail and Use Lima

- You just want Docker on Mac → use Colima
- You need file sharing now → use Lima
- You're not building the orchestrator → use Lima
- You don't want to fix the issues in FIXES_NEEDED.md → use Lima

## When to Keep This

- You're building toward the multi-agent fan-out system
- You want a minimal base you fully understand
- Lima's 50+ YAML options annoy you
- This is a learning/research project

## Bottom Line

If the fan-out orchestration is the goal, keep this as the foundation. If you just need VMs, use Lima - it's mature and works. Don't maintain infrastructure you don't need.
