# Claude Code MCP Parallel Orchestration

<div align="center">

**Turn 3-minute MCP workflows into 10-second operations**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-2.1.12+-blue.svg)](https://claude.ai/claude-code)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-lightgrey.svg)](#requirements)

| Sequential | Parallel | Speedup |
|:----------:|:--------:|:-------:|
| 76 seconds | 4.9 seconds | **15x faster** |

*50 MCP calls in 10 seconds instead of 3 minutes*

</div>

---

## Quick Start

**Install (all projects):**
```bash
curl -fsSL https://raw.githubusercontent.com/AIntelligentTech/claude-code-mcp-cli-parallel-godmode/main/get.sh | bash
```

**Install (current project only):**
```bash
curl -fsSL https://raw.githubusercontent.com/AIntelligentTech/claude-code-mcp-cli-parallel-godmode/main/get.sh | bash -s -- --project .
```

Then restart Claude Code.

<details>
<summary>What the installer does</summary>

- Installs `jq` if missing (via brew/apt/dnf/yum/pacman)
- Adds `ENABLE_EXPERIMENTAL_MCP_CLI=true` to your shell profile
- Installs hooks and rules
- Verifies all components

</details>

<details>
<summary>Manual install</summary>

```bash
git clone --depth 1 https://github.com/AIntelligentTech/claude-code-mcp-cli-parallel-godmode.git /tmp/mcp-parallel
/tmp/mcp-parallel/install.sh --user
rm -rf /tmp/mcp-parallel
```

</details>

---

## Why This Exists

Claude Code runs MCP operations **sequentially** by default — each operation waits for the previous one to complete:

```
Default:  [op 1: 3.8s] → [op 2: 3.8s] → [op 3: 3.8s] → ... = 76s for 20 operations
```

This toolkit enables **two levels of parallelization**:

### Level 1: Parallel operations within a single Bash invocation

Using background jobs (`&`) and `wait`, multiple MCP operations run simultaneously:

```
Single Bash call:  [op 1 ─┬─ op 2 ─┬─ op 3 ─┬─ ...] = 4.9s for 20 operations
                          └────────┴────────┘
```

### Level 2: Multiple parallel Bash tool calls

Claude Code can invoke multiple Bash tools simultaneously. Combined with Level 1:

```
┌─ Bash call 1: [mcp-cli & mcp-cli & wait] ─┐
├─ Bash call 2: [mcp-cli & mcp-cli & wait] ─┼─ All run in parallel
└─ Bash call 3: [mcp-cli & mcp-cli & wait] ─┘
```

**Result:** 4×5 parallel calls performs similarly to 1×20 — layers compose without penalty.

---

## Key Principle: ALL MCP Operations

This applies to **both** `mcp-cli info` (schema checks) **and** `mcp-cli call` (tool invocations).

```bash
# REQUIRED - parallelize EVERYTHING
mcp-cli info server/tool1 > /tmp/i1.json &
mcp-cli info server/tool2 > /tmp/i2.json &
wait
mcp-cli call server/tool1 '{}' > /tmp/r1.json &
mcp-cli call server/tool2 '{}' > /tmp/r2.json &
wait

# FORBIDDEN - sequential info checks waste time too
mcp-cli info server/tool1
mcp-cli info server/tool2
```

---

## Performance

<details>
<summary><strong>Verified benchmarks (January 2026)</strong></summary>

### Throughput

| Operations | Sequential | Parallel | Speedup |
|-----------:|-----------:|---------:|--------:|
| 2 | 7.6s | 3.8s | **2x** |
| 10 | 38s | 3.0s | **12.8x** |
| 20 | 76s | 4.9s | **15.5x** |
| 50 | 191s | 10.3s | **18.5x** |
| 100 | 382s | ~15s | **~25x** |

### Efficiency Gains

| Metric | Before | After | Reduction |
|--------|-------:|------:|----------:|
| Time (20 calls) | 76s | 4.9s | **94%** |
| Model turns | 20 | 1 | **95%** |
| Output tokens | ~1,600 | ~250 | **84%** |

</details>

---

## How It Works

The toolkit installs four enforcement layers:

```
┌─────────────────────────────────────────────────────┐
│  CLAUDE.md          │  Instructions in context      │
├─────────────────────────────────────────────────────┤
│  rules/             │  Detailed enforcement rules   │
├─────────────────────────────────────────────────────┤
│  mcp-cli-gate.sh    │  Blocks if env var not set    │
├─────────────────────────────────────────────────────┤
│  mcp-parallel-      │  Reminds to use parallel      │
│  reminder.sh        │  pattern for ALL mcp-cli ops  │
└─────────────────────────────────────────────────────┘
```

Claude Code learns to transform this:

```bash
# Before: Sequential (76 seconds)
mcp-cli info server/tool1
mcp-cli info server/tool2
mcp-cli call server/tool1 '{}'
mcp-cli call server/tool2 '{}'
# ... 16 more operations
```

Into this:

```bash
# After: Parallel (4.9 seconds)
mcp-cli info server/tool1 > /tmp/i1.json &
mcp-cli info server/tool2 > /tmp/i2.json &
wait
mcp-cli call server/tool1 '{}' > /tmp/r1.json &
mcp-cli call server/tool2 '{}' > /tmp/r2.json &
# ... 16 more operations
wait
```

---

## Installation

### Option A: User-Level (Recommended)

Applies to all your Claude Code projects:

```bash
./install.sh --user
```

### Option B: Project-Level

Applies to a single project only:

```bash
./install.sh --project /path/to/your/project
```

### What Gets Installed

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Instructions loaded into model context |
| `.claude/rules/mcp-parallel.md` | Detailed enforcement rules |
| `.claude/hooks/mcp-cli-gate.sh` | Blocks calls if env var missing |
| `.claude/hooks/mcp-parallel-reminder.sh` | Suggests parallel pattern |
| `.claude/hooks.json` | Hook configuration |

### Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/.../get.sh | bash -s -- --uninstall --user
# or: --uninstall --project .
```

---

## Requirements

### Platform Support

| Platform | Status | Notes |
|----------|:------:|-------|
| macOS | Supported | Tested on Darwin 25.x |
| Linux | Supported | Requires bash 4.0+ |
| Windows | Use WSL2 | Native Windows not supported |

### Dependencies

| Dependency | Install |
|------------|---------|
| **jq** | `brew install jq` (macOS) / `apt install jq` (Ubuntu) |
| **bash 4.0+** | Pre-installed on macOS/Linux |
| **Claude Code 2.1.12+** | [claude.ai/claude-code](https://claude.ai/claude-code) |

The installer blocks if `jq` is missing.

---

## Usage Patterns

### Basic: Parallel Operations

```bash
# Run 3 info checks + 3 calls in parallel
mcp-cli info server/tool1 > /tmp/i1.json &
mcp-cli info server/tool2 > /tmp/i2.json &
mcp-cli info server/tool3 > /tmp/i3.json &
wait

mcp-cli call server/tool1 '{}' > /tmp/r1.json &
mcp-cli call server/tool2 '{}' > /tmp/r2.json &
mcp-cli call server/tool3 '{}' > /tmp/r3.json &
wait

# Process results
jq -s '.' /tmp/r1.json /tmp/r2.json /tmp/r3.json
```

### Optimal Batching (20-25 operations per wave)

```bash
# Batch independent operations in one Bash call (target 20-25)
# Schema checks
mcp-cli info google-workspace/get_events > /tmp/i1.json &
mcp-cli info google-workspace/search_gmail_messages > /tmp/i2.json &
mcp-cli info google-workspace/list_task_lists > /tmp/i3.json &
mcp-cli info github/list_issues > /tmp/i4.json &
mcp-cli info github/list_pull_requests > /tmp/i5.json &
# ... up to 20-25 total
wait

# Tool calls
mcp-cli call google-workspace/get_events '{"cal":"cal1"}' > /tmp/r1.json &
mcp-cli call google-workspace/get_events '{"cal":"cal2"}' > /tmp/r2.json &
# ... up to 20-25 total
wait
```

### Dependency Waves

When calls depend on earlier results, use waves:

```bash
# Wave 1: Independent operations run in parallel
mcp-cli info server/list_items > /tmp/schema.json &
mcp-cli call server/list_items '{}' > /tmp/items.json &
mcp-cli call server/get_config '{}' > /tmp/config.json &
wait

# Extract value needed for Wave 2
ITEM_ID=$(jq -r '.items[0].id' /tmp/items.json)

# Wave 2: Dependent calls (also parallel)
mcp-cli call server/get_item "{\"id\":\"$ITEM_ID\"}" > /tmp/item.json &
mcp-cli call server/get_history "{\"id\":\"$ITEM_ID\"}" > /tmp/history.json &
wait
```

### Large Batches (100+ operations)

Batch into waves of 50-75 to balance throughput and resource usage:

```bash
# Process 150 items in 3 waves
ITEMS=$(seq 1 150)
BATCH_SIZE=50

for item in $ITEMS; do
  mcp-cli call server/process "{\"id\":$item}" > "/tmp/r${item}.json" &
  # Every BATCH_SIZE items, wait for batch to complete
  [ $((item % BATCH_SIZE)) -eq 0 ] && wait
done
wait  # Final batch
```

### Level 2: Multiple Parallel Bash Calls

Invoke multiple Bash tools simultaneously for multiplicative effect:

```bash
# Bash call 1 (parallel with Bash call 2)
mcp-cli call google-workspace/get_events '{"cal":"cal1"}' > /tmp/cal1.json &
mcp-cli call google-workspace/get_events '{"cal":"cal2"}' > /tmp/cal2.json &
# ... 23 more calendar calls
wait
```

```bash
# Bash call 2 (parallel with Bash call 1)
mcp-cli call github/list_issues '{"repo":"repo1"}' > /tmp/gh1.json &
mcp-cli call github/list_issues '{"repo":"repo2"}' > /tmp/gh2.json &
# ... 23 more GitHub calls
wait
```

**Result:** 50 operations complete in ~5 seconds using two parallel Bash calls.

---

## Subagent Best Practices

When spawning subagents that will make MCP calls:

### Pre-batch Schemas in Parent Session

```bash
# Parent session: gather all schemas before spawning subagents
mcp-cli info google-workspace/get_events > /tmp/schema_events.json &
mcp-cli info google-workspace/search_gmail_messages > /tmp/schema_gmail.json &
mcp-cli info google-workspace/list_tasks > /tmp/schema_tasks.json &
wait

# Pass schemas to subagent via prompt
SCHEMAS=$(cat /tmp/schema_*.json | jq -s '.')
```

### Avoid Context Thrashing

| Do | Don't |
|----|-------|
| Batch work into fewer subagents | Spawn many small subagents |
| Pre-fetch data in parent session | Make redundant MCP calls across agents |
| Use haiku for exploration tasks | Use opus/sonnet for simple data gathering |
| Give each subagent substantial work | Create one subagent per MCP call |

### Include Parallelization in Subagent Prompts

When spawning subagents, explicitly include:

```
IMPORTANT: Use parallel MCP orchestration. Batch all mcp-cli operations:
mcp-cli info/call ... > /tmp/r1.json &
mcp-cli info/call ... > /tmp/r2.json &
wait
```

---

## Real-World Example

### Daily Briefing (31 sources in 5 seconds)

```bash
EMAIL="you@example.com"

# Wave 1: All schemas + initial data in parallel (one Bash call)
mcp-cli info google-workspace/get_events > /tmp/i1.json &
mcp-cli info google-workspace/search_gmail_messages > /tmp/i2.json &
mcp-cli info google-workspace/list_task_lists > /tmp/i3.json &
mcp-cli call google-workspace/get_events "{\"user_google_email\":\"$EMAIL\",\"calendar_id\":\"cal1\"}" > /tmp/cal1.json &
mcp-cli call google-workspace/get_events "{\"user_google_email\":\"$EMAIL\",\"calendar_id\":\"cal2\"}" > /tmp/cal2.json &
# ... 9 calendars total
mcp-cli call google-workspace/search_gmail_messages "{\"user_google_email\":\"$EMAIL\",\"query\":\"is:unread\"}" > /tmp/emails.json &
mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$EMAIL\"}" > /tmp/tasks.json &
mcp-cli call github/list_issues '{"repo":"myorg/repo1"}' > /tmp/issues.json &
mcp-cli call github/list_pull_requests '{"repo":"myorg/repo1"}' > /tmp/prs.json &
wait

# Total: 31 MCP operations in ~5 seconds instead of ~2 minutes
```

---

## Troubleshooting

<details>
<summary><strong>"MCP endpoint file not found"</strong></summary>

Session context lost. Don't use `bash -c` with new directories:

```bash
# Wrong
bash -c 'TMPDIR=$(mktemp -d); mcp-cli call ...'

# Correct
mcp-cli call ... > /tmp/result.json &
wait
```

</details>

<details>
<summary><strong>"mcp-cli: command not found"</strong></summary>

```bash
export ENABLE_EXPERIMENTAL_MCP_CLI=true
# Add to ~/.zshrc or ~/.bashrc for persistence
```

</details>

<details>
<summary><strong>Results not in temp files</strong></summary>

Always use `wait` after background jobs:

```bash
mcp-cli call ... > /tmp/r1.json &
mcp-cli call ... > /tmp/r2.json &
wait  # Don't forget this!
```

</details>

<details>
<summary><strong>High memory with 100+ operations</strong></summary>

Use wave batching — batch into groups of 50-75:

```bash
for wave in 1 2; do
  # 50 operations per wave
  for i in $(seq 1 50); do
    mcp-cli call ... > /tmp/r$i.json &
  done
  wait
done
```

</details>

---

## Best Practices Summary

| Do | Don't |
|----|-------|
| Parallelize `mcp-cli info` AND `mcp-cli call` | Only parallelize calls, not info checks |
| Batch 20-25 operations per Bash call | Make many small Bash calls |
| Use Level 2 (multiple parallel Bash calls) | Rely only on Level 1 |
| Pre-fetch schemas for subagents | Let each subagent fetch its own schemas |
| Use waves for dependencies | Guess at dependent values |
| Always use `wait` after `&` jobs | Forget `wait` before reading results |
| Redirect output to temp files | Let output go to stdout |
| Wave batch 100+ operations | Run 200 operations simultaneously |
| Give subagents substantial work batches | Spawn many small subagents |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT License. See [LICENSE](LICENSE).

---

<div align="center">

**[Report Bug](https://github.com/AIntelligentTech/claude-code-mcp-cli-parallel-godmode/issues)** · **[Request Feature](https://github.com/AIntelligentTech/claude-code-mcp-cli-parallel-godmode/issues)**

*Created by [AIntelligent Technologies](https://aintelligenttech.com) · January 2026*

</div>
