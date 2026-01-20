# Claude Code MCP Parallel Orchestration

<div align="center">

**Transform sequential MCP operations into parallel execution**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-2.1.12+-blue.svg)](https://claude.ai/claude-code)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-lightgrey.svg)](#requirements)

</div>

---

## What This Does

This toolkit enables **parallel execution** of MCP-CLI operations within Claude
Code, reducing wall-clock time by **up to 18x** for batch operations.

```bash
# Without this toolkit (sequential): ~76 seconds for 20 calls
mcp-cli call server/tool1 '{}'   # 3.8s
mcp-cli call server/tool2 '{}'   # 3.8s
# ... 18 more calls

# With this toolkit (parallel): ~4.9 seconds for 20 calls
mcp-cli call server/tool1 '{}' > /tmp/r1.json &
mcp-cli call server/tool2 '{}' > /tmp/r2.json &
# ... 18 more calls
wait
```

---

## Performance: Honest Numbers

### Layer 3: MCP-CLI Parallelism (Core Technique)

This is the primary value of this toolkit. Verified benchmarks:

| Parallel Calls | Sequential Time | Parallel Time | Speedup   |
| -------------- | --------------- | ------------- | --------- |
| 2              | ~7.6s           | ~3.8s         | **2.0x**  |
| 5              | ~19s            | ~3.8s         | **5.0x**  |
| 10             | ~38s            | ~3.9s         | **9.7x**  |
| 20             | ~76s            | ~4.9s         | **15.5x** |
| 50 (batched)   | ~190s           | ~10.5s        | **18.1x** |

**Key insight:** Speedup is genuine time reduction for the same work. 20 MCP
calls that took 76 seconds now take 4.9 seconds.

### Layer 1: Subagent Parallelism (Horizontal Scaling)

Claude Code's Task tool allows spawning multiple subagents in one message.
**This is throughput scaling, not speedup.**

| Configuration            | What It Does            | Wall-Clock Time |
| ------------------------ | ----------------------- | --------------- |
| 1 agent, 17 L3 ops       | 17 operations complete  | ~3.2s           |
| 3 agents, 17 L3 ops each | 51 operations complete  | ~3.5s           |
| 6 agents, 17 L3 ops each | 102 operations complete | ~4.0s           |

**Important distinction:**

- L1 does NOT make L3 faster
- L1 allows MORE operations to happen simultaneously
- Same wall-clock time, ~6x more total operations processed

### Combined Effect: What You Actually Get

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│  HONEST PERFORMANCE CLAIMS                                                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  L3 (MCP-CLI Parallelism):                                                      │
│  ─────────────────────────                                                      │
│  • Speedup: 2x-18x depending on batch size                                      │
│  • Same operations, less wall-clock time                                        │
│  • Diminishing returns above ~50 parallel calls                                 │
│                                                                                 │
│  L1 (Subagent Parallelism):                                                     │
│  ─────────────────────────                                                      │
│  • Throughput: ~6x more operations per wall-clock second                        │
│  • Horizontal scaling, not vertical speedup                                     │
│  • Adds startup overhead (~1-2s per agent)                                      │
│                                                                                 │
│  L1 + L3 Combined:                                                              │
│  ─────────────────                                                              │
│  • Process 100+ operations in ~5s                                               │
│  • Sequential baseline for same work: ~400s                                     │
│  • Effective speedup for large workloads: ~80x                                  │
│  • But most of this comes from L3 alone                                         │
│                                                                                 │
│  WHAT L1 ACTUALLY ADDS TO L3:                                                   │
│  ─────────────────────────────                                                  │
│  • For fixed operations: marginal improvement (~1.2-1.5x)                       │
│  • For variable operations: ~6x more throughput at similar latency              │
│  • Primary value: domain separation (calendar agent, email agent, git agent)    │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## The Three-Layer Architecture

### Why Three Layers?

Through testing, we discovered that Claude Code doesn't implement parallel tool
calls within a single agent turn, despite the API supporting it. We compensate
with layers we CAN control:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        THREE-LAYER PARALLELISM ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  LAYER 1: SUBAGENT PARALLELISM                                                  │
│  ═══════════════════════════════                                                │
│  Main session spawns multiple Task tools in ONE message                         │
│  Effect: Horizontal scaling (more agents working simultaneously)                │
│  NOT a speedup for fixed work — it's throughput scaling                         │
│                                                                                 │
│  LAYER 2: TOOL CALL PARALLELISM                                                 │
│  ═════════════════════════════════                                              │
│  ⚠️  API supports this. Claude Code DOES NOT implement it.                      │
│  We cannot control this layer.                                                  │
│                                                                                 │
│  LAYER 3: MCP-CLI PARALLELISM                                                   │
│  ════════════════════════════════                                               │
│  Background jobs within Bash: `mcp-cli ... &`                                   │
│  Effect: Genuine speedup (2x-18x for same operations)                           │
│  THIS IS THE PRIMARY VALUE of this toolkit                                      │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Layer Comparison

| Layer | What It Provides    | Speedup for Fixed Work | Throughput Scaling |
| ----- | ------------------- | ---------------------- | ------------------ |
| L1    | Parallel subagents  | ~1x (marginal)         | **~6x**            |
| L2    | Parallel tool calls | N/A (not implemented)  | N/A                |
| L3    | Parallel MCP-CLI    | **2x-18x**             | ~1x                |

---

## Quick Start

**Install (user-level, all projects):**

```bash
curl -fsSL https://raw.githubusercontent.com/AIntelligentTech/claude-code-mcp-cli-parallel-godmode/main/get.sh | bash
```

**Install (current project only):**

```bash
curl -fsSL https://raw.githubusercontent.com/AIntelligentTech/claude-code-mcp-cli-parallel-godmode/main/get.sh | bash -s -- --project .
```

Then restart Claude Code.

<details>
<summary>Manual install</summary>

```bash
git clone --depth 1 https://github.com/AIntelligentTech/claude-code-mcp-cli-parallel-godmode.git /tmp/mcp-parallel
/tmp/mcp-parallel/install.sh --user
rm -rf /tmp/mcp-parallel
```

</details>

---

## Core Pattern: L3 Parallelism

The primary technique. Use background jobs with `&` and `wait`:

```bash
# Execute operations in parallel
mcp-cli call google-workspace/get_events '{}' > /tmp/events.json &
mcp-cli call google-workspace/list_tasks '{}' > /tmp/tasks.json &
mcp-cli call google-workspace/search_gmail_messages '{}' > /tmp/email.json &
wait

# Process results
cat /tmp/events.json /tmp/tasks.json /tmp/email.json
```

### Required Elements

| Element            | Purpose                                    |
| ------------------ | ------------------------------------------ |
| `&`                | Run command in background                  |
| `> /tmp/file.json` | Capture output (background jobs need this) |
| `wait`             | Block until all background jobs complete   |

### Wave Batching for Large Operations

For 50+ operations, batch into waves to avoid resource exhaustion:

```bash
# Process 100 operations in waves of 25
for wave in 1 2 3 4; do
  start=$((($wave - 1) * 25 + 1))
  end=$(($wave * 25))

  for i in $(seq $start $end); do
    mcp-cli call server/tool "{\"id\":$i}" > /tmp/r$i.json &
  done
  wait  # Complete wave before starting next
done
```

---

## Advanced Pattern: L1 + L3 (Throughput Scaling)

When you need to process many operations across different domains, use subagents
for **horizontal scaling**:

```yaml
# Main session sends ONE message with multiple Task tools
# All agents execute in parallel (L1), each using parallel MCP (L3)

Task:
  subagent_type: general-purpose
  description: "Calendar scanner"
  prompt: |
    Fetch calendar events using parallel MCP-CLI.

    mcp-cli call google-workspace/get_events '{"calendar_id":"cal1"}' > /tmp/cal1.json &
    mcp-cli call google-workspace/get_events '{"calendar_id":"cal2"}' > /tmp/cal2.json &
    wait

    Target output: 400-600 tokens (structured YAML).

Task:
  subagent_type: general-purpose
  description: "Email scanner"
  prompt: |
    Fetch recent emails using parallel MCP-CLI.

    mcp-cli call google-workspace/search_gmail_messages '{"query":"is:unread"}' > /tmp/unread.json &
    mcp-cli call google-workspace/search_gmail_messages '{"query":"in:inbox"}' > /tmp/inbox.json &
    wait

    Target output: 400-600 tokens.

Task:
  subagent_type: general-purpose
  description: "Git analyzer"
  prompt: |
    Analyze git repositories with parallel commands.

    for repo in /path/to/repos/*; do
      git -C "$repo" log --oneline -10 &
    done
    wait

    Target output: 400-800 tokens.
```

**Result:**

- 3 agents run in parallel (L1)
- Each agent runs 2-10 operations in parallel (L3)
- Total: ~20 operations complete in ~4s
- Sequential baseline: ~80s

**Note:** This is throughput scaling. The same 20 operations with L3 alone would
take ~4s. L1's value here is domain separation and cleaner code, not additional
speedup.

---

## File System Communication Pattern

For large data sets, have subagents write to files, then read selectively:

```bash
# Subagent writes data to temp files
mcp-cli call google-workspace/get_events '{}' > /tmp/data/events.json &
mcp-cli call google-workspace/list_tasks '{}' > /tmp/data/tasks.json &
wait

# Create manifest summarizing what was collected
cat > /tmp/data/manifest.json << 'EOF'
{
  "files": ["events.json", "tasks.json"],
  "summary": {"events": 15, "tasks": 8}
}
EOF
```

```yaml
# Main session reads manifest first, then selectively loads
Read: /tmp/data/manifest.json
Read: /tmp/data/events.json  # Only if needed based on manifest
```

**Benefit:** Subagent can process 100k+ tokens; main session loads only what it
needs.

---

## Known Issues

### Issue 1: Subagent Model Selection Bug

Setting `model: haiku` in Task tool doesn't reliably use the specified model.

**Workaround:** Use token budget constraints in prompts:

```yaml
Task:
  prompt: |
    ...
    IMPORTANT: Target output 400-600 tokens maximum.
    Return structured YAML, not verbose prose.
```

### Issue 2: Layer 2 Not Implemented

Claude API supports parallel tool calls within a turn. Claude Code doesn't use
this capability. We compensate with L1 and L3.

### Issue 3: Session Context Loss

Don't use `bash -c` with mcp-cli — it loses session context:

```bash
# WRONG - loses MCP session context
bash -c 'mcp-cli call server/tool "{}"'

# CORRECT - preserves session
mcp-cli call server/tool '{}' > /tmp/result.json &
wait
```

---

## Anti-Patterns

### Sequential MCP calls

```bash
# WRONG: 3x time
mcp-cli call server/tool1 '{}'
mcp-cli call server/tool2 '{}'
mcp-cli call server/tool3 '{}'

# RIGHT: 1x time (parallel)
mcp-cli call server/tool1 '{}' > /tmp/r1.json &
mcp-cli call server/tool2 '{}' > /tmp/r2.json &
mcp-cli call server/tool3 '{}' > /tmp/r3.json &
wait
```

### Missing output redirect

```bash
# WRONG: output lost
mcp-cli call server/tool '{}' &
wait
# Where did the output go?

# RIGHT: output captured
mcp-cli call server/tool '{}' > /tmp/result.json &
wait
cat /tmp/result.json
```

### Forgetting wait

```bash
# WRONG: results incomplete
mcp-cli call server/tool1 '{}' > /tmp/r1.json &
mcp-cli call server/tool2 '{}' > /tmp/r2.json &
cat /tmp/r1.json  # File may not exist or be incomplete!

# RIGHT: wait for completion
mcp-cli call server/tool1 '{}' > /tmp/r1.json &
mcp-cli call server/tool2 '{}' > /tmp/r2.json &
wait
cat /tmp/r1.json /tmp/r2.json
```

### Claiming L1 provides speedup

```yaml
# MISLEADING: "6x faster with subagents"
# L1 provides throughput scaling, not speedup for fixed work

# ACCURATE: "6x more operations in same wall-clock time"
```

---

## Requirements

| Dependency              | Install                                                |
| ----------------------- | ------------------------------------------------------ |
| **jq**                  | `brew install jq` (macOS) / `apt install jq` (Ubuntu)  |
| **bash 4.0+**           | Pre-installed on macOS/Linux                           |
| **Claude Code 2.1.12+** | [claude.ai/claude-code](https://claude.ai/claude-code) |

**Environment variable:**

```bash
export ENABLE_EXPERIMENTAL_MCP_CLI=true
```

---

## Documentation

| Document                                                             | Content                          |
| -------------------------------------------------------------------- | -------------------------------- |
| [docs/three-layer-architecture.md](docs/three-layer-architecture.md) | Technical architecture deep-dive |
| [docs/real-world-patterns.md](docs/real-world-patterns.md)           | Production-tested patterns       |
| [examples/README.md](examples/README.md)                             | Code examples                    |

---

## Contributing

Contributions welcome. Please ensure claims are backed by reproducible
benchmarks.

## License

MIT License. See [LICENSE](LICENSE).

---

<div align="center">

**[Report Bug](https://github.com/AIntelligentTech/claude-code-mcp-cli-parallel-godmode/issues)**
·
**[Request Feature](https://github.com/AIntelligentTech/claude-code-mcp-cli-parallel-godmode/issues)**

_Created by [AIntelligent Technologies](https://aintelligenttech.com) · January
2026_

</div>
