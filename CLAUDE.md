# MCP Parallel Orchestration

> Installed by [claude-code-mcp-cli-parallel-godmode](https://github.com/yourusername/claude-code-mcp-cli-parallel-godmode)

## MCP Tool Orchestration

**CRITICAL: When making 3+ MCP tool calls, use parallel bash orchestration for up to 18x throughput.**

### Verified Performance (January 2026)

| Configuration | Calls | Time | Throughput | vs Sequential |
|---------------|-------|------|------------|---------------|
| Sequential | 1 | 3.82s | 0.26 calls/s | 1x |
| **1×10** | 10 | 3.0s | 3.33 calls/s | **12.8x** |
| **1×20 (sweet spot)** | 20 | 4.9s | 4.08 calls/s | **15.7x** |
| **1×50 (extreme)** | 50 | 10.3s | 4.84 calls/s | **18.6x** |

**Result:** 3-minute workflows complete in 10 seconds.

### Configuration Guide

| Scenario | Recommended | Expected Speedup |
|----------|-------------|------------------|
| 1-2 calls | Sequential | — |
| 3-10 calls | **1×N** | 6-13x |
| 10-20 calls | **1×N** | 13-16x |
| 20-50 calls | **1×N** | 15-18x |
| 50+ calls | **Wave batching** | ~18x |

### Three Layers of Parallelization

1. **Layer 1 (Within Bash):** Background jobs (`&`) + `wait` — up to 18x throughput
2. **Layer 2 (Multiple Bash calls):** Parallel Bash tool calls — logical grouping, no penalty
3. **Layer 3 (Subagents):** Parallel Task agents — isolated contexts

**Key insight:** Layers compose without penalty. 4×5 ≈ 1×20.

### Pattern: Wave-Based Execution

```bash
# Wave 1: Independent calls (runs in ~5s, not ~76s for 20 calls)
mcp-cli call google-workspace/get_events '{"user_google_email":"..."}' > /tmp/events.json &
mcp-cli call google-workspace/list_tasks '{"user_google_email":"..."}' > /tmp/tasks.json &
mcp-cli call google-workspace/search_gmail_messages '{"user_google_email":"..."}' > /tmp/emails.json &
wait

# Extract values for dependent calls
TASK_ID=$(jq -r '.task_lists[0].id' /tmp/tasks.json)

# Wave 2: Dependent calls
mcp-cli call google-workspace/get_task '{"task_id":"'"$TASK_ID"'"}' > /tmp/task.json &
wait

# Process results
jq -r '.content[0].text' /tmp/events.json
```

### What NOT to Do

```bash
# WRONG: Creates new temp directory, loses session context
bash -c 'TMPDIR=$(mktemp -d); mcp-cli call ...'

# WRONG: Sequential calls when they could be parallel
mcp-cli call server/tool1 '{}'
mcp-cli call server/tool2 '{}'
mcp-cli call server/tool3 '{}'
```

### Wave Batching (50+ calls)

```bash
# Process in waves of 20-25 to avoid resource exhaustion
for wave in 1 2 3; do
  start=$((($wave - 1) * 20 + 1))
  end=$(($wave * 20))
  for i in $(seq $start $end); do
    mcp-cli call ... > /tmp/r$i.json &
  done
  wait
done
```

### Prerequisites

```bash
export ENABLE_EXPERIMENTAL_MCP_CLI=true
```

### Summary

| Metric | Improvement |
|--------|-------------|
| Throughput | **18.6x** increase |
| Time (20 calls) | 76s → 4.9s (**94% faster**) |
| Time (50 calls) | 191s → 10.3s (**95% faster**) |
| Model turns | **95%** reduction |
| Work capacity | **18x** more calls/minute |

---

*Configuration installed from claude-code-mcp-cli-parallel-godmode*
