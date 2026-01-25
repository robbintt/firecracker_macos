# Why This Project?

Honest assessment of when to use this vs Lima/Colima.

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
