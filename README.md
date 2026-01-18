# Claude Code MCP-CLI Parallel Orchestration

> **18x throughput** — 3-minute workflows complete in 10 seconds.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-2.1.12+-blue.svg)](https://claude.ai/claude-code)

**Verified January 2026:**
- 50 MCP calls: Sequential 191s → Parallel 10.3s = **18.5x faster**
- 20 MCP calls: Sequential 76s → Parallel 4.9s = **15.5x faster**
- Throughput: 0.26 calls/s → 4.84 calls/s = **18.6x increase**

---

## The Problem

When Claude Code gathers data from multiple MCP sources, it runs calls **sequentially**. Each call takes ~3.8 seconds, so:

- 20 calls = **76 seconds** of waiting
- 50 calls = **3+ minutes** of waiting

This toolkit makes Claude Code run `mcp-cli` calls **in parallel**, turning minutes into seconds.

---

## Verified Performance (Full Range)

All numbers tested on real MCP servers, January 2026.

### Throughput by Configuration

| Configuration | Calls | Time | Throughput | vs Sequential |
|---------------|-------|------|------------|---------------|
| Sequential (baseline) | 1 | 3.82s | 0.26 calls/s | 1x |
| **1×5** | 5 | 2.9s | 1.72 calls/s | **6.6x** |
| **1×10** | 10 | 3.0s | 3.33 calls/s | **12.8x** |
| **1×20 (sweet spot)** | 20 | 4.9s | 4.08 calls/s | **15.7x** |
| **1×30** | 30 | 7.4s | 4.05 calls/s | **15.6x** |
| **1×40** | 40 | 8.5s | 4.68 calls/s | **18.0x** |
| **1×50 (extreme)** | 50 | 10.3s | 4.84 calls/s | **18.6x** |

### Time Savings

| Workflow Size | Sequential | Parallel | Time Saved | Reduction |
|---------------|------------|----------|------------|-----------|
| 10 calls | 38.2s | 3.0s | 35.2s | **92%** |
| 20 calls | 76.4s | 4.9s | 71.5s | **94%** |
| 30 calls | 114.6s | 7.4s | 107.2s | **94%** |
| 50 calls | 191s (3m 11s) | 10.3s | 180.7s | **95%** |

### Work Capacity (Fixed Time Windows)

| Time Window | Sequential | Parallel | Increase |
|-------------|------------|----------|----------|
| 10 seconds | 2.6 calls | 48 calls | **18x** |
| 30 seconds | 7.8 calls | 145 calls | **18x** |
| 60 seconds | 15.7 calls | 290 calls | **18x** |
| 5 minutes | 78 calls | 1,452 calls | **18x** |

### Model Efficiency

| Metric | Sequential (20 calls) | Parallel (1 Bash) | Reduction |
|--------|----------------------|-------------------|-----------|
| Model turns | 20 | 1 | **95%** |
| Output tokens | ~1,600 | ~250 | **84%** |
| API round-trips | 20 | 1 | **95%** |

---

## Configuration Guide

### Choosing the Right Configuration

| Your Scenario | Recommended | Expected Speedup | Notes |
|---------------|-------------|------------------|-------|
| 1-2 calls | Sequential | — | Overhead not worth it |
| 3-10 calls | **1×N** | 6-13x | Sweet spot for small batches |
| 10-20 calls | **1×N** | 13-16x | Optimal efficiency zone |
| 20-50 calls | **1×N** or **2×N** | 15-18x | Near-maximum throughput |
| 50+ calls | **Wave batching** | ~18x | Split into 20-25 call waves |
| Mixed dependencies | **Multi-wave** | 15-18x | Group independent calls |

### Configuration Patterns

**Pattern 1: Simple Parallel (1×N)**
Best for: Independent calls, maximum simplicity
```bash
# All calls run simultaneously
for i in $(seq 1 20); do
  mcp-cli call server/tool '{}' > /tmp/r$i.json &
done
wait
```

**Pattern 2: Wave Batching (for 50+ calls)**
Best for: Large batches, avoiding resource exhaustion
```bash
# Wave 1: First 25
for i in $(seq 1 25); do mcp-cli call ... > /tmp/r$i.json & done
wait

# Wave 2: Next 25
for i in $(seq 26 50); do mcp-cli call ... > /tmp/r$i.json & done
wait
```

**Pattern 3: Dependency Waves**
Best for: Calls that depend on earlier results
```bash
# Wave 1: Independent calls
mcp-cli call server/get_config '{}' > /tmp/config.json &
mcp-cli call server/list_items '{}' > /tmp/items.json &
wait

# Extract values
ITEM_ID=$(jq -r '.items[0].id' /tmp/items.json)

# Wave 2: Dependent calls
mcp-cli call server/get_item "{\"id\":\"$ITEM_ID\"}" > /tmp/item.json &
mcp-cli call server/get_history "{\"id\":\"$ITEM_ID\"}" > /tmp/history.json &
wait
```

**Pattern 4: Multi-Bash Parallel**
Best for: Logical grouping without penalty
```bash
# These can be separate Bash tool calls (Layer 2)
# No performance penalty for splitting into logical groups
```

### Diminishing Returns

| Range | Behavior | Recommendation |
|-------|----------|----------------|
| 1-10 calls | Near-linear speedup | Always parallelize |
| 10-20 calls | Excellent gains | Sweet spot |
| 20-40 calls | Good gains, slight plateau | Still worth it |
| 40-50 calls | Marginal gains | Consider wave batching |
| 50+ calls | Minimal additional benefit | Use wave batching |

**The ceiling is ~18-19x** — beyond 50 parallel calls, gains are negligible.

---

## Three Layers of Parallelization

| Layer | Mechanism | Speedup | Use Case |
|-------|-----------|---------|----------|
| **Layer 1** | Background jobs (`&`) in single Bash | Up to 18x | Primary technique |
| **Layer 2** | Multiple parallel Bash tool calls | Logical grouping | Organize by purpose |
| **Layer 3** | Parallel Task subagents | Isolated contexts | Complex multi-domain workflows |

**Key insight:** Layers compose without penalty. 4×5 performs similarly to 1×20.

### Layer Composition Examples

```
┌─────────────────────────────────────────────────────────┐
│ Layer 3: Parallel Task Subagents                        │
│ ┌─────────────────────┐ ┌─────────────────────┐        │
│ │ Task Agent 1        │ │ Task Agent 2        │        │
│ │ ┌─────────────────┐ │ │ ┌─────────────────┐ │        │
│ │ │ Layer 2: Bash 1 │ │ │ │ Layer 2: Bash 1 │ │        │
│ │ │ mcp-cli & ──┐   │ │ │ │ mcp-cli & ──┐   │ │        │
│ │ │ mcp-cli & ──┼─┐ │ │ │ │ mcp-cli & ──┼─┐ │ │        │
│ │ │ mcp-cli & ──┼─┤ │ │ │ │ mcp-cli & ──┼─┤ │ │        │
│ │ │ wait ───────┴─┘ │ │ │ │ wait ───────┴─┘ │ │        │
│ │ └─────────────────┘ │ │ └─────────────────┘ │        │
│ └─────────────────────┘ └─────────────────────┘        │
└─────────────────────────────────────────────────────────┘
```

---

## Real-World Scenarios

### Scenario 1: Daily Briefing (20 data sources)

**Without parallelization:** 76.4 seconds (noticeable wait)
**With parallelization:** 4.9 seconds (near-instant)

```bash
EMAIL="you@example.com"

# Wave 1: All independent sources (runs in ~5s, not ~76s)
mcp-cli call google-workspace/get_events "{\"user_google_email\":\"$EMAIL\"}" > /tmp/events.json &
mcp-cli call google-workspace/search_gmail_messages "{\"user_google_email\":\"$EMAIL\",\"query\":\"in:inbox\"}" > /tmp/emails.json &
mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$EMAIL\"}" > /tmp/lists.json &
mcp-cli call google-workspace/list_calendars "{\"user_google_email\":\"$EMAIL\"}" > /tmp/calendars.json &
mcp-cli call github/list_issues '{"repo":"myorg/repo1"}' > /tmp/issues1.json &
mcp-cli call github/list_issues '{"repo":"myorg/repo2"}' > /tmp/issues2.json &
mcp-cli call github/list_commits '{"repo":"myorg/repo1"}' > /tmp/commits.json &
# ... more sources
wait

# Wave 2: Dependent calls
TASK_LIST_ID=$(jq -r '.task_lists[0].id' /tmp/lists.json)
mcp-cli call google-workspace/list_tasks "{\"user_google_email\":\"$EMAIL\",\"task_list_id\":\"$TASK_LIST_ID\"}" > /tmp/tasks.json &
wait

# Process all results
jq -s '.' /tmp/*.json
```

### Scenario 2: Multi-Repo Status Check (50 calls)

**Without parallelization:** 3+ minutes
**With parallelization:** ~10 seconds

```bash
# 50 repository checks in 10 seconds
REPOS=(repo1 repo2 repo3 ... repo50)

for repo in "${REPOS[@]}"; do
  mcp-cli call github/list_commits "{\"repo\":\"org/$repo\"}" > /tmp/${repo}_commits.json &
done
wait

# Aggregate results
for repo in "${REPOS[@]}"; do
  echo "=== $repo ==="
  jq -r '.commits[0].message' /tmp/${repo}_commits.json
done
```

### Scenario 3: Batch Email Processing (30 messages)

**Without parallelization:** 114 seconds
**With parallelization:** ~7 seconds

```bash
EMAIL="you@example.com"
MESSAGE_IDS=$(cat /tmp/message_ids.txt)

for id in $MESSAGE_IDS; do
  mcp-cli call google-workspace/get_gmail_message_content "{\"user_google_email\":\"$EMAIL\",\"message_id\":\"$id\"}" > /tmp/msg_${id}.json &
done
wait
```

---

## Quick Start

### Prerequisites

```bash
# Enable experimental mcp-cli (required)
export ENABLE_EXPERIMENTAL_MCP_CLI=true

# Add to shell profile for persistence
echo 'export ENABLE_EXPERIMENTAL_MCP_CLI=true' >> ~/.zshrc
```

### Installation

**Option A: User-Level (All Projects)**
```bash
git clone https://github.com/yourusername/claude-code-mcp-cli-parallel-godmode.git
cd claude-code-mcp-cli-parallel-godmode
./install.sh --user
```

**Option B: Project-Level (Single Project)**
```bash
git clone https://github.com/yourusername/claude-code-mcp-cli-parallel-godmode.git /tmp/mcp-parallel
/tmp/mcp-parallel/install.sh --project /path/to/your/project
```

**Option C: Manual**
```bash
cp CLAUDE.md ~/.claude/CLAUDE.md
cp -r .claude/hooks ~/.claude/hooks
```

---

## How It Works

### Why Background Jobs Preserve Session Context

Background jobs (`&`) inherit the parent shell's environment, including Claude Code's session context. The `mcp-cli` command needs access to session endpoint files — background jobs preserve this access.

**What breaks:**
```bash
# WRONG: New subshell loses session context
bash -c 'TMPDIR=$(mktemp -d); mcp-cli call ...'
# Error: "MCP endpoint file not found"
```

**What works:**
```bash
# CORRECT: Background job inherits session context
mcp-cli call server/tool '{}' > /tmp/result.json &
wait
```

---

## Best Practices

### Do's

1. **Always use `wait`** after background jobs to ensure completion
2. **Redirect output** to temp files (`> /tmp/result.json`) to capture results
3. **Use `jq`** to extract values between waves for dependent calls
4. **Group logically** — waves have no performance penalty
5. **Wave batch 50+ calls** into groups of 20-25

### Don'ts

1. **Don't use `bash -c`** with new temp directories (loses session context)
2. **Don't exceed 50 parallel calls** without wave batching
3. **Don't forget dependencies** — some calls need results from earlier calls
4. **Don't parallelize 1-2 calls** — overhead isn't worth it

### Error Handling

```bash
# Robust pattern with error checking
mcp-cli call server/tool '{}' > /tmp/result.json 2>/tmp/error.log &
PID1=$!

wait $PID1
if [ $? -ne 0 ]; then
  echo "Error in call 1: $(cat /tmp/error.log)"
fi
```

---

## Enforcement Architecture

This toolkit uses **four layers** of enforcement to ensure Claude Code uses parallel MCP orchestration:

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: CLAUDE.md (Model Context)                          │
│   Concise instructions loaded into every conversation       │
│   References rules for detailed enforcement                 │
├─────────────────────────────────────────────────────────────┤
│ Layer 2: Rules (.claude/rules/mcp-parallel.md)              │
│   Detailed enforcement rules auto-loaded by Claude Code     │
│   FORBIDDEN/REQUIRED patterns with examples                 │
├─────────────────────────────────────────────────────────────┤
│ Layer 3: Advisory Hook (mcp-parallel-validator.sh)          │
│   Runtime warning when sequential mcp-cli calls detected    │
│   Suggests parallel pattern without blocking                │
├─────────────────────────────────────────────────────────────┤
│ Layer 4: Guard Hook (mcp-cli-gate.sh)                       │
│   Blocks mcp-cli if ENABLE_EXPERIMENTAL_MCP_CLI not set     │
│   Ensures environment is properly configured                │
└─────────────────────────────────────────────────────────────┘
```

## What Gets Installed

| File | Purpose | Layer |
|------|---------|-------|
| `CLAUDE.md` | Concise instructions (references rules) | Context |
| `.claude/rules/mcp-parallel.md` | Detailed enforcement rules | Rules |
| `.claude/hooks/mcp-parallel-validator.sh` | Advisory: warns on sequential calls | Hook |
| `.claude/hooks/mcp-cli-gate.sh` | Guard: blocks if env var not set | Hook |
| `.claude/hooks.json` | Hook configuration | Config |

---

## Troubleshooting

### "MCP endpoint file not found"

Session context lost. Don't use `bash -c` with new temp directories:

```bash
# WRONG
bash -c 'TMPDIR=$(mktemp -d); mcp-cli call ...'

# CORRECT
mcp-cli call ... &
wait
```

### "mcp-cli: command not found"

```bash
export ENABLE_EXPERIMENTAL_MCP_CLI=true
```

### Results not appearing in temp files

Ensure you're using `wait` after all background jobs:

```bash
mcp-cli call ... > /tmp/r1.json &
mcp-cli call ... > /tmp/r2.json &
wait  # Critical! Don't forget this
cat /tmp/r1.json
```

### High memory usage with 50+ calls

Use wave batching to limit concurrent processes:

```bash
# Process in waves of 20
for wave in 1 2 3; do
  start=$((($wave - 1) * 20 + 1))
  end=$(($wave * 20))
  for i in $(seq $start $end); do
    mcp-cli call ... > /tmp/r$i.json &
  done
  wait
done
```

---

## Comparison with Anthropic's Approach

| Aspect | Anthropic's Approach | This Toolkit |
|--------|---------------------|--------------|
| **Primary goal** | Token efficiency | Throughput/latency |
| **Token savings** | 98.7% (on-demand loading) | 84% (fewer turns) |
| **Time savings** | N/A (token focus) | **95% (18x faster)** |
| **Execution model** | Filesystem code files | Inline bash commands |
| **Best for** | Context window limits | Speed-critical workflows |

**When to use what:**
- **This toolkit**: When speed matters — daily briefings, multi-source queries, batch operations
- **Anthropic's approach**: When token costs matter — large result sets, context window optimization

They're complementary — you can use both.

---

## Reproduce Benchmarks

```bash
export ENABLE_EXPERIMENTAL_MCP_CLI=true
./benchmarks/run-benchmark.sh your@email.com
```

---

## Summary: What You Get

| Metric | Improvement | Verified |
|--------|-------------|----------|
| **Throughput** | 18.6x increase | Yes |
| **Time (20 calls)** | 76s → 4.9s (94% faster) | Yes |
| **Time (50 calls)** | 191s → 10.3s (95% faster) | Yes |
| **Model turns** | 95% reduction | Yes |
| **Output tokens** | 84% reduction | Yes |
| **Work capacity** | 18x more calls/minute | Yes |

**Bottom line:** Complete 290 MCP calls in the time it takes to do 16 sequentially.

---

## Uninstallation

```bash
./install.sh --uninstall --user        # User-level
./install.sh --uninstall --project /p  # Project-level
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

MIT License. See [LICENSE](LICENSE).

---

## Related

- [Anthropic: Code execution with MCP](https://www.anthropic.com/engineering/code-execution-with-mcp) — Token efficiency through code execution
- [Claude Code](https://claude.ai/claude-code) — Anthropic's CLI
- [Model Context Protocol](https://modelcontextprotocol.io/) — MCP specification

---

*Created by [AIntelligent Technologies](https://aintelligenttech.com) — January 2026*
