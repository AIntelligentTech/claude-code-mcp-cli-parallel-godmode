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
curl -fsSL https://raw.githubusercontent.com/yourusername/claude-code-mcp-cli-parallel-godmode/main/get.sh | bash
```

**Install (current project only):**
```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/claude-code-mcp-cli-parallel-godmode/main/get.sh | bash -s -- --project .
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
git clone --depth 1 https://github.com/yourusername/claude-code-mcp-cli-parallel-godmode.git /tmp/mcp-parallel
/tmp/mcp-parallel/install.sh --user
rm -rf /tmp/mcp-parallel
```

</details>

---

## Why This Exists

Claude Code runs MCP calls **sequentially** by default — each call waits for the previous one to complete:

```
Default:  [call 1: 3.8s] → [call 2: 3.8s] → [call 3: 3.8s] → ... = 76s for 20 calls
```

This toolkit enables **two levels of parallelization**:

### Level 1: Parallel calls within a single Bash invocation

Using background jobs (`&`) and `wait`, multiple MCP calls run simultaneously:

```
Single Bash call:  [call 1 ─┬─ call 2 ─┬─ call 3 ─┬─ ...] = 4.9s for 20 calls
                            └──────────┴──────────┘
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

## Performance

<details>
<summary><strong>Verified benchmarks (January 2026)</strong></summary>

### Throughput

| Calls | Sequential | Parallel | Speedup |
|------:|-----------:|---------:|--------:|
| 2 | 7.6s | 3.8s | **2x** |
| 10 | 38s | 3.0s | **12.8x** |
| 20 | 76s | 4.9s | **15.5x** |
| 50 | 191s | 10.3s | **18.5x** |

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
│  reminder.sh        │  pattern for mcp-cli calls    │
└─────────────────────────────────────────────────────┘
```

Claude Code learns to transform this:

```bash
# Before: Sequential (76 seconds)
mcp-cli call server/tool1 '{}'
mcp-cli call server/tool2 '{}'
# ... 18 more calls
```

Into this:

```bash
# After: Parallel (4.9 seconds)
mcp-cli call server/tool1 '{}' > /tmp/r1.json &
mcp-cli call server/tool2 '{}' > /tmp/r2.json &
# ... 18 more calls
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

### Basic: Parallel Calls

```bash
# Run 3 calls in parallel, wait for all to complete
mcp-cli call server/tool1 '{}' > /tmp/r1.json &
mcp-cli call server/tool2 '{}' > /tmp/r2.json &
mcp-cli call server/tool3 '{}' > /tmp/r3.json &
wait

# Process results
jq -s '.' /tmp/r1.json /tmp/r2.json /tmp/r3.json
```

### Dependency Waves

When calls depend on earlier results, use waves:

```bash
# Wave 1: Independent calls run in parallel
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

### Large Batches (50+ calls)

Batch into waves of 20-25 to avoid resource exhaustion:

```bash
# Process 60 items in 3 waves
ITEMS=$(seq 1 60)
BATCH_SIZE=20

for item in $ITEMS; do
  mcp-cli call server/process "{\"id\":$item}" > "/tmp/r${item}.json" &
  # Every BATCH_SIZE items, wait for batch to complete
  [ $((item % BATCH_SIZE)) -eq 0 ] && wait
done
wait  # Final batch
```

### With Error Handling

```bash
# Capture stdout and stderr separately
mcp-cli call server/tool '{}' > /tmp/result.json 2> /tmp/error.log &
pid=$!
wait $pid || echo "Call failed: $(cat /tmp/error.log)"
```

---

## Real-World Example

### Daily Briefing (20 sources in 5 seconds)

```bash
EMAIL="you@example.com"

# All sources in parallel
mcp-cli call google-workspace/get_events "{\"user_google_email\":\"$EMAIL\"}" > /tmp/events.json &
mcp-cli call google-workspace/search_gmail_messages "{\"user_google_email\":\"$EMAIL\",\"query\":\"is:unread\"}" > /tmp/emails.json &
mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$EMAIL\"}" > /tmp/tasks.json &
mcp-cli call github/list_issues '{"repo":"myorg/repo1"}' > /tmp/issues.json &
mcp-cli call github/list_pull_requests '{"repo":"myorg/repo1"}' > /tmp/prs.json &
wait

# Process results
jq -s '.' /tmp/*.json
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
<summary><strong>High memory with 50+ calls</strong></summary>

Use wave batching — see [Large Batches](#large-batches-wave-batching-50-calls) above.

</details>

---

## Best Practices

| Do | Don't |
|----|-------|
| Always use `wait` after `&` jobs | Forget `wait` before reading results |
| Redirect output to temp files | Let output go to stdout |
| Wave batch 50+ calls | Run 100 calls simultaneously |
| Use `jq` between waves for dependencies | Guess at dependent values |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT License. See [LICENSE](LICENSE).

---

<div align="center">

**[Report Bug](https://github.com/yourusername/claude-code-mcp-cli-parallel-godmode/issues)** · **[Request Feature](https://github.com/yourusername/claude-code-mcp-cli-parallel-godmode/issues)**

*Created by [AIntelligent Technologies](https://aintelligenttech.com) · January 2026*

</div>
