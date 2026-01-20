# MCP Parallel Orchestration Rules — Three-Layer Architecture

**MANDATORY: All mcp-cli operations with 2+ calls MUST use parallel
orchestration patterns.**

This applies to **both** `mcp-cli info` (schema checks) and `mcp-cli call` (tool
invocations).

---

## The Three Layers

Claude Code has an architectural gap: the Claude API supports parallel tool
calls, but Claude Code does not implement this. We compensate with three layers:

| Layer | What                             | Status             | Multiplier |
| ----- | -------------------------------- | ------------------ | ---------- |
| L1    | Subagent parallelism (Task tool) | ✅ Works           | 6-8x       |
| L2    | Tool call parallelism            | ❌ Not implemented | N/A        |
| L3    | MCP-CLI parallelism (Bash `&`)   | ✅ Works           | 18x        |

**Combined effect:** L1 × L3 = **100+ parallel operations**

---

## Rule: Never Sequential MCP Operations

When making 2+ MCP operations (info OR call), you MUST use parallel bash
orchestration. Sequential operations are PROHIBITED.

### FORBIDDEN Pattern

```bash
# NEVER DO THIS - sequential operations waste 50%+ of time (even for just 2)
mcp-cli info server/tool1
mcp-cli info server/tool2
mcp-cli call server/tool1 '{}'
mcp-cli call server/tool2 '{}'
```

### REQUIRED Pattern

```bash
# ALWAYS DO THIS - parallel operations with background jobs (even for 2)
# Wave 1: Schema checks in parallel
mcp-cli info server/tool1 > /tmp/i1.json &
mcp-cli info server/tool2 > /tmp/i2.json &
wait

# Wave 2: Tool calls in parallel
mcp-cli call server/tool1 '{}' > /tmp/r1.json &
mcp-cli call server/tool2 '{}' > /tmp/r2.json &
wait

# Then process results
cat /tmp/r1.json /tmp/r2.json
```

---

## Rule: Use Layer 1 (Subagent Parallelism)

**Launch multiple subagents in ONE message:**

```yaml
# ONE message containing multiple Task tools:

Task:
  subagent_type: google-workspace-scanner
  prompt: |
    Scan all Google Workspace data.
    Email: tony@example.com
    Use parallel MCP-CLI (& and wait).
    Output to /tmp/gws/*.json

Task:
  subagent_type: vault-scanner
  prompt: |
    Read: GOALS.md, COMMITMENTS.md, CLIENTS.md
    Return structured YAML. Target: 400-600 tokens.

Task:
  subagent_type: git-scanner
  prompt: |
    Analyze 25 repos with parallel git commands.
    Output to /tmp/git/*.txt
```

**Result:** All three agents execute IN PARALLEL (Layer 1), each using internal
parallelism (Layer 3).

---

## Rule: Batch Aggressively (20-25 calls per wave)

Before every Bash tool call, assess how many independent MCP operations can be
batched together.

**Target:** 20-25 parallel MCP operations per Bash invocation. For larger
batches (50-100+), use wave batching.

```bash
# Good: 20 schema checks in one Bash call
mcp-cli info google-workspace/get_events > /tmp/i1.json &
mcp-cli info google-workspace/search_gmail_messages > /tmp/i2.json &
mcp-cli info google-workspace/list_task_lists > /tmp/i3.json &
# ... continue for all independent schemas
mcp-cli info github/list_issues > /tmp/i20.json &
wait
```

---

## Rule: File System as Communication Channel

Output to temp files, then use parallel Read tools:

```bash
# Subagent or main session Bash call:
mcp-cli call google-workspace/get_events '{}' > /tmp/cal.json &
mcp-cli call google-workspace/search_gmail '{}' > /tmp/email.json &
mcp-cli call google-workspace/list_tasks '{}' > /tmp/tasks.json &
wait
```

```
# Main session (multiple Read tools in one message):
Read: /tmp/cal.json    ─┐
Read: /tmp/email.json   │  ALL EXECUTE IN PARALLEL
Read: /tmp/tasks.json  ─┘
```

**Why this works:**

1. MCP-CLI outputs to predictable temp files
2. `wait` ensures all writes complete
3. Multiple Read tools in one message execute in parallel
4. File contents return to main session efficiently

---

## Rule: Consolidated Agents for Maximum L3 Parallelism

Instead of multiple separate agents making individual calls, use ONE agent with
many parallel calls:

```bash
# google-workspace-scanner: 17 parallel MCP calls in ONE agent
EMAIL="tony@example.com"
DATA_DIR="/tmp/gws-$(date +%Y%m%d)"
mkdir -p "$DATA_DIR"

# 9 calendar calls + 3 email calls + 5 task calls = 17 parallel
mcp-cli call google-workspace/get_events "{\"calendar_id\":\"cal1\"}" > "$DATA_DIR/cal1.json" &
mcp-cli call google-workspace/get_events "{\"calendar_id\":\"cal2\"}" > "$DATA_DIR/cal2.json" &
# ... 7 more calendars
mcp-cli call google-workspace/search_gmail_messages '{}' > "$DATA_DIR/inbox.json" &
mcp-cli call google-workspace/search_gmail_messages '{"query":"from:me"}' > "$DATA_DIR/outbox.json" &
# ... 1 more email query
mcp-cli call google-workspace/list_tasks '{"task_list_id":"list1"}' > "$DATA_DIR/tasks1.json" &
# ... 4 more task lists
wait

cat "$DATA_DIR"/*.json | jq -s '.'
```

**Performance:** ~3.2 seconds for 17 calls (vs ~65 seconds sequential)

---

## Rule: Wave-Based Execution for Dependencies

When calls depend on earlier results, use waves:

```bash
# Wave 1: Independent schema checks + initial data
mcp-cli info server/list_items > /tmp/schema.json &
mcp-cli call server/list_items '{}' > /tmp/items.json &
mcp-cli call server/get_config '{}' > /tmp/config.json &
wait

# Extract dependent value
ITEM_ID=$(jq -r '.items[0].id' /tmp/items.json)

# Wave 2: Dependent calls (still parallel with each other)
mcp-cli call server/get_item "{\"id\":\"$ITEM_ID\"}" > /tmp/item.json &
mcp-cli call server/get_history "{\"id\":\"$ITEM_ID\"}" > /tmp/history.json &
wait
```

---

## Rule: Include Token Budgets (Model Bug Workaround)

**Known bug:** Subagent model selection doesn't work reliably.

**Workaround:** Include explicit token budget in prompts:

```yaml
Task:
  subagent_type: data-scanner
  # model: haiku  # Don't rely on this
  prompt: |
    Scan data sources and return summary.

    IMPORTANT: Target output 400-600 tokens maximum.
    Return structured YAML, not verbose prose.
    Do NOT include explanations.
```

---

## Rule: Wave Batching for Very Large Operations

For 100+ calls, batch into waves of 50-75 to balance throughput and resource
usage:

```bash
# Process 150 calls in 3 waves of 50
for wave in 1 2 3; do
  start=$((($wave - 1) * 50 + 1))
  end=$(($wave * 50))
  for i in $(seq $start $end); do
    mcp-cli call server/tool '{}' > /tmp/r$i.json &
  done
  wait
done
```

---

## Rule: Never Break Session Context

Background jobs (`&`) inherit session context. The following patterns BREAK
context:

```bash
# FORBIDDEN - loses session context
bash -c 'TMPDIR=$(mktemp -d); mcp-cli call ...'
bash -c 'cd /tmp && mcp-cli call ...'

# CORRECT - preserves session context
mcp-cli call server/tool '{}' > /tmp/result.json &
wait
```

---

## Rule: Always Use `wait`

Every parallel batch MUST end with `wait` to ensure completion before processing
results.

```bash
mcp-cli info ... > /tmp/i1.json &
mcp-cli call ... > /tmp/r1.json &
mcp-cli call ... > /tmp/r2.json &
wait  # MANDATORY - ensures all operations complete

# Now safe to read results
cat /tmp/r1.json
```

---

## Rule: Redirect Output to Temp Files

Parallel operations MUST redirect output to capture results.

```bash
# CORRECT - output captured
mcp-cli call server/tool '{}' > /tmp/result.json &

# WRONG - output lost in background
mcp-cli call server/tool '{}' &
```

---

## Performance Expectations

### L3: Genuine Speedup (Same Work, Less Time)

| Parallel Calls | Speedup   |
| -------------- | --------- |
| 2              | **2x**    |
| 5              | **5x**    |
| 10             | **9.7x**  |
| 20             | **15.5x** |
| 50 (batched)   | **18x**   |

### L1: Throughput Scaling (Not Speedup)

| Configuration            | Operations | Wall-Clock |
| ------------------------ | ---------- | ---------- |
| 1 agent, 17 L3 ops       | 17         | ~3.2s      |
| 3 agents, 17 L3 ops each | 51         | ~3.5s      |
| 6 agents, 17 L3 ops each | 102        | ~4.0s      |

**Important:** L1 does NOT make L3 faster. It allows more operations at similar
latency. Don't conflate throughput with speedup.

Failure to use L3 parallel orchestration wastes up to 95% of execution time.

---

## Exceptions

Sequential operations are acceptable ONLY when:

1. Making exactly 1 MCP operation
2. Debugging a specific operation in isolation
3. Explicitly requested by user

**For 2+ operations, parallel orchestration is MANDATORY.**

---

_Three-Layer Parallelism Architecture — January 2026_
