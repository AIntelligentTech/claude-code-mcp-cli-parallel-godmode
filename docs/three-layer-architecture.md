# Three-Layer Parallelism Architecture — Deep Dive

This document provides the technical foundation for the Three-Layer Parallelism
Architecture, developed through production testing with AI Co-Founder systems
in January 2026.

---

## Executive Summary

Claude Code has an architectural gap: **the Claude API supports parallel tool
calls, but Claude Code does not implement this capability**. We discovered this
through analysis of 113 sessions showing 0/3,441 tool calls executed in parallel
within a single agent turn.

We compensate with **three layers of parallelism**:

| Layer | Mechanism                        | Status             | Effect              |
| ----- | -------------------------------- | ------------------ | ------------------- |
| L1    | Subagent parallelism (Task tool) | ✅ Works           | ~6x throughput      |
| L2    | Tool call parallelism (per turn) | ❌ Not implemented | N/A                 |
| L3    | MCP-CLI parallelism (Bash `&`)   | ✅ Works           | 2x-18x speedup      |

**Key distinction:**
- L3 provides **speedup** (2x-18x for same work)
- L1 provides **throughput** (~6x more work at similar latency)
- These are different metrics — don't multiply them

---

## The Discovery: Layer 2 Gap

### What We Observed

```
Observed behavior in Claude Code:
─────────────────────────────────
Turn 1: [Read file] → wait → result
Turn 2: [Bash cmd] → wait → result
Turn 3: [Read file] → wait → result
Turn 4: [Edit file] → wait → result

ALL SEQUENTIAL. Never multiple tools in one turn.
```

### What the API Supports

According to Anthropic's official documentation:

> "Claude 4 models have built-in token-efficient tool use and improved parallel
> tool calling."

> "When Claude makes parallel tool calls, it outputs multiple tool_use blocks
> in a single response."

### Verification

Analysis of 113 Claude Code sessions:
- **3,441 tool calls** examined
- **0 parallel tool calls** within a single turn
- **100% sequential** execution within agent turns

**Conclusion:** The API capability exists, but Claude Code's implementation
doesn't utilize it.

---

## The Three Layers Explained

### Layer 1: Subagent Parallelism

**Mechanism:** Launch multiple Task tools in ONE message.

```
Main Session Message:
┌─────────────────────────────────────────────────────────────────┐
│ Task: google-workspace-scanner                                  │
│ Task: vault-scanner                                            │
│ Task: git-scanner                                              │
│ Task: memory-scanner                                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ALL EXECUTE IN PARALLEL
                              ↓
┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐
│ Agent 1    │  │ Agent 2    │  │ Agent 3    │  │ Agent 4    │
│ running    │  │ running    │  │ running    │  │ running    │
└────────────┘  └────────────┘  └────────────┘  └────────────┘
```

**Key insight:** Claude Code DOES support invoking multiple Task tools in one
message. This is Layer 1 parallelism.

**Effect:** Multiple agents in parallel = ~6x throughput (not speedup)

### Layer 2: Tool Call Parallelism (NOT IMPLEMENTED)

**What it would be:** Within a single agent turn, invoke multiple tools
simultaneously.

```
What L2 SHOULD be (but isn't implemented):
──────────────────────────────────────────
Single turn:
┌─────────────────────────────────────────────────────────────────┐
│ [Read file A]  [Read file B]  [Bash cmd 1]  [Bash cmd 2]       │
│       ↓              ↓              ↓              ↓           │
│   ALL PARALLEL                                                 │
└─────────────────────────────────────────────────────────────────┘

What actually happens:
──────────────────────
[Read file A] → wait → [Read file B] → wait → [Bash cmd 1] → wait → ...
```

**Current status:** API supports it, Claude Code doesn't implement it.

**Impact:** Each subagent's tools execute sequentially within a turn.

### Layer 3: MCP-CLI Parallelism

**Mechanism:** Bash background jobs (`&` and `wait`).

```bash
# Single Bash tool call with internal parallelism:
mcp-cli call server/tool1 '{}' > /tmp/r1.json &  ─┐
mcp-cli call server/tool2 '{}' > /tmp/r2.json &   │
mcp-cli call server/tool3 '{}' > /tmp/r3.json &   │ ALL PARALLEL
...                                               │ (~3s total)
mcp-cli call server/tool17 '{}' > /tmp/r17.json & ─┘
wait
cat /tmp/r*.json
```

**Multiplier:** 17+ calls in parallel = 18x faster than sequential

---

## Combined Architecture

### Execution Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              MAIN SESSION (Opus/Sonnet)                          │
│                                                                                 │
│  ONE MESSAGE with multiple Task tools:                                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                 │
│  │ Task: gws-      │  │ Task: vault-    │  │ Task: git-      │   L1            │
│  │ scanner         │  │ scanner         │  │ scanner         │   PARALLEL      │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘                 │
│           │                    │                    │                           │
│           ▼                    ▼                    ▼                           │
│  ┌────────────────┐   ┌────────────────┐   ┌────────────────┐                  │
│  │ Haiku Agent    │   │ Haiku Agent    │   │ Haiku Agent    │                  │
│  │                │   │                │   │                │                  │
│  │ ┌────────────┐ │   │ ┌────────────┐ │   │ ┌────────────┐ │                  │
│  │ │ Bash:      │ │   │ │ Read:      │ │   │ │ Bash:      │ │   L3            │
│  │ │ mcp-cli &  │ │   │ │ GOALS.md   │ │   │ │ git log &  │ │   PARALLEL      │
│  │ │ mcp-cli &  │ │   │ │ COMMIT.md  │ │   │ │ git log &  │ │   (internal)    │
│  │ │ mcp-cli &  │ │   │ │ CLIENTS.md │ │   │ │ git log &  │ │                  │
│  │ │ (×17)      │ │   │ │ (×6)       │ │   │ │ (×25 repos)│ │                  │
│  │ │ wait       │ │   │ └────────────┘ │   │ │ wait       │ │                  │
│  │ └────────────┘ │   │                │   │ └────────────┘ │                  │
│  │ Output: JSON   │   │ Output: YAML   │   │ Output: text   │                  │
│  └────────────────┘   └────────────────┘   └────────────────┘                  │
│           │                    │                    │                           │
│           └────────────────────┴────────────────────┘                           │
│                              ▼                                                  │
│                Wall clock: max(3s, 1s, 15s) = 15 seconds                        │
└─────────────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              SYNTHESIS PHASE                                     │
│  • Process context (30k+ tokens)                                                │
│  • Generate output                                                              │
│  • Update tasks                                                                 │
│  Time: ~30 seconds (sequential, LLM-bound)                                      │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Mathematical Model

```
Total parallel operations = L1 × L2 × L3

Where:
  L1 = Number of parallel subagents (6-8)
  L2 = Tool calls per agent turn (1, because not implemented)
  L3 = MCP-CLI calls per Bash (17+)

Current:  6 × 1 × 17 = 102 parallel operations
Future:   6 × 4 × 17 = 408 parallel operations (if L2 implemented)
```

---

## Compensation Strategies

### Strategy 1: Consolidated Agents

Instead of 3 separate agents making 5-6 calls each, use ONE agent with 17 calls:

```
Before (3 separate agents):
───────────────────────────
calendar-scanner: 9 MCP calls  → agent overhead + 9 calls
email-scanner:    3 MCP calls  → agent overhead + 3 calls
tasks-scanner:    5 MCP calls  → agent overhead + 5 calls
                               ────────────────────────────
                               3× agent overhead + 17 calls

After (1 consolidated agent):
────────────────────────────
google-workspace-scanner: 17 parallel MCP calls
                          ─────────────────────
                          1× agent overhead + 17 calls (all parallel)
```

**Benefit:** Eliminates 2x agent startup overhead (~6-10 seconds).

### Strategy 2: File System Communication

Use temp files as communication channel between subagents and main session:

```bash
# Subagent writes to files:
mcp-cli call server/tool1 '{}' > /tmp/data/result1.json &
mcp-cli call server/tool2 '{}' > /tmp/data/result2.json &
mcp-cli call server/tool3 '{}' > /tmp/data/result3.json &
wait

# Create manifest for main session:
cat > /tmp/data/manifest.json << 'EOF'
{
  "files": ["result1.json", "result2.json", "result3.json"],
  "summary": { "total": 3, "success": 3 }
}
EOF
```

Main session reads manifest first (fast), then selectively reads detailed files.

### Strategy 3: Token Budget Constraints

**Known bug:** Subagent model selection doesn't work reliably.

**Workaround:** Include explicit constraints in prompts:

```yaml
Task:
  subagent_type: data-scanner
  # model: haiku  # Don't rely on this
  prompt: |
    Scan data sources.

    CONSTRAINTS:
    - Target output: 400-600 tokens maximum
    - Format: Structured YAML only
    - No explanatory text
    - No verbose descriptions
```

---

## Performance Analysis

### Important Distinction: Speedup vs Throughput

| Metric        | Definition                              | Layer |
|---------------|----------------------------------------|-------|
| **Speedup**   | Same work, less wall-clock time        | L3    |
| **Throughput**| More work at similar wall-clock time   | L1    |

These are different metrics. Do not conflate them.

### L3: Genuine Speedup (Verified Benchmarks)

| Parallel Calls | Sequential Time | Parallel Time | Speedup     |
|----------------|-----------------|---------------|-------------|
| 2              | ~7.6s           | ~3.8s         | **2.0x**    |
| 10             | ~38s            | ~3.9s         | **9.7x**    |
| 20             | ~76s            | ~4.9s         | **15.5x**   |
| 50 (batched)   | ~190s           | ~10.5s        | **18.1x**   |

L3 reduces wall-clock time for a fixed number of operations.

### L1: Throughput Scaling (Not Speedup)

| Configuration            | Operations Completed | Wall-Clock | vs 1 Agent |
|--------------------------|---------------------|------------|------------|
| 1 agent, 17 L3 ops       | 17                  | ~3.2s      | baseline   |
| 3 agents, 17 L3 ops each | 51                  | ~3.5s      | 3x ops     |
| 6 agents, 17 L3 ops each | 102                 | ~4.0s      | 6x ops     |

L1 does NOT make L3 faster. It allows more operations simultaneously.

### End-to-End Briefing (Practical Example)

| Phase               | Sequential | With L3    | Notes                      |
|---------------------|------------|------------|----------------------------|
| MCP data (17 calls) | ~65s       | ~3.2s      | L3 speedup: **20x**        |
| Git analysis        | ~45s       | ~10s       | Parallel git commands      |
| Vault reads         | ~10s       | ~2s        | Parallel Read tools        |
| **Data gathering**  | **~120s**  | **~15s**   | **L3: ~8x speedup**        |
| Synthesis           | ~30s       | ~30s       | LLM-bound, sequential      |
| **End-to-end**      | **~150s**  | **~45s**   | **~3.3x improvement**      |

### Why L1 Doesn't Multiply L3's Speedup

1. **L3 already parallelizes** — 17 ops in one agent take ~3.2s
2. **L1 adds overhead** — Each agent has startup cost (~1-2s)
3. **Wall-clock is max()** — 3 agents at ~3.5s each = ~3.5s total, not 1.2s
4. **Value is throughput** — 102 ops in ~4s (L1+L3) vs 17 ops in ~3.2s (L3 alone)

L1's real value: process 6x more data at similar latency, not 6x faster.

---

## Implementation Patterns

### Pattern 1: Consolidated Google Workspace Scanner

```bash
#!/bin/bash
# google-workspace-scanner.sh
# 17 parallel MCP calls in ONE agent

EMAIL="$1"
DATE=$(date +%Y%m%d)
DATA_DIR="/tmp/gws-$DATE"
mkdir -p "$DATA_DIR"

echo "Scanning Google Workspace for $EMAIL..."

# === 9 CALENDAR QUERIES (parallel) ===
for cal in personal finance operations marketing content engineering consultations rituals product; do
  mcp-cli call google-workspace/get_events "{
    \"user_google_email\": \"$EMAIL\",
    \"calendar_id\": \"$(get_calendar_id $cal)\"
  }" > "$DATA_DIR/cal-$cal.json" 2>&1 &
done

# === 3 EMAIL QUERIES (parallel with above) ===
mcp-cli call google-workspace/search_gmail_messages "{
  \"user_google_email\": \"$EMAIL\",
  \"query\": \"newer_than:3d -from:me\"
}" > "$DATA_DIR/email-inbound.json" 2>&1 &

mcp-cli call google-workspace/search_gmail_messages "{
  \"user_google_email\": \"$EMAIL\",
  \"query\": \"from:me newer_than:7d\"
}" > "$DATA_DIR/email-outbound.json" 2>&1 &

# === 5 TASK LIST QUERIES (parallel with above) ===
for list in flagged today ideas commitments mytasks; do
  mcp-cli call google-workspace/list_tasks "{
    \"user_google_email\": \"$EMAIL\",
    \"task_list_id\": \"$(get_task_list_id $list)\"
  }" > "$DATA_DIR/tasks-$list.json" 2>&1 &
done

# === WAIT FOR ALL 17 QUERIES ===
wait

echo "Scan complete: $DATA_DIR"
ls -la "$DATA_DIR"

# Return combined results
cat "$DATA_DIR"/*.json | jq -s '.'
```

### Pattern 2: Subagent Orchestration

```yaml
# Main session sends ONE message with multiple Task tools:

Task:
  subagent_type: google-workspace-scanner
  prompt: |
    Scan all Google Workspace data.
    Email: tony.deverill@aintelligenttech.com

    EXECUTION:
    - Use parallel MCP-CLI pattern (& and wait)
    - Output to /tmp/gws-[date]/*.json

    CONSTRAINTS:
    - Return structured YAML summary
    - Target: 800-1200 tokens
    - Include flaggable items array

Task:
  subagent_type: vault-scanner
  prompt: |
    Read and summarize vault documents:
    - 10-strategy/operations/GOALS.md
    - 10-strategy/operations/COMMITMENTS.md
    - 20-sales/CLIENTS.md
    - 20-sales/expenses/RECURRING-PAYMENTS.md

    CONSTRAINTS:
    - Return structured YAML
    - Target: 400-600 tokens
    - Focus on active items only

Task:
  subagent_type: git-scanner
  prompt: |
    Analyze recent activity across repositories:
    /path/to/repo1, /path/to/repo2, ... (25 repos)

    EXECUTION:
    - Use parallel git commands with background jobs
    - Output to /tmp/git-[date]/*.txt

    CONSTRAINTS:
    - Return structured summary
    - Target: 400-800 tokens
    - Focus on last 7 days

# All three execute IN PARALLEL (Layer 1)
# Each uses internal parallelism (Layer 3)
```

### Pattern 3: Wave-Based Dependencies

```bash
# WAVE 1: Discovery (parallel)
mcp-cli call google-workspace/list_calendars '{}' > /tmp/w1/calendars.json &
mcp-cli call google-workspace/list_task_lists '{}' > /tmp/w1/task_lists.json &
mcp-cli call google-workspace/list_gmail_labels '{}' > /tmp/w1/labels.json &
wait

# Extract IDs for Wave 2
CAL_IDS=$(jq -r '.[].id' /tmp/w1/calendars.json)
LIST_IDS=$(jq -r '.[].id' /tmp/w1/task_lists.json)

# WAVE 2: Data fetch (parallel)
for cal_id in $CAL_IDS; do
  mcp-cli call google-workspace/get_events "{\"calendar_id\":\"$cal_id\"}" > "/tmp/w2/cal_$cal_id.json" &
done
for list_id in $LIST_IDS; do
  mcp-cli call google-workspace/list_tasks "{\"task_list_id\":\"$list_id\"}" > "/tmp/w2/tasks_$list_id.json" &
done
wait

# WAVE 3: Dependent enrichment (if needed)
# ...
```

---

## Known Issues and Workarounds

### Issue 1: Model Selection Bug

**Problem:** `model: haiku` in Task tool doesn't reliably use Haiku.

**Workaround:** Include explicit token budget in prompt:
```
IMPORTANT: Target output 400-600 tokens maximum.
Return structured YAML, not prose.
```

### Issue 2: Layer 2 Gap

**Problem:** Tool calls within an agent turn are sequential.

**Workaround:** Maximize L1 (more subagents) and L3 (more MCP-CLI per Bash).

### Issue 3: Session Context Loss

**Problem:** `bash -c 'cd /tmp && mcp-cli ...'` loses session.

**Workaround:** Never use `bash -c` with directory changes. Always:
```bash
mcp-cli call ... > /tmp/result.json &
wait
```

### Issue 4: Temp File Collisions

**Problem:** Multiple sessions may collide on `/tmp/result.json`.

**Workaround:** Include date/session ID in paths:
```bash
DATA_DIR="/tmp/gws-$(date +%Y%m%d)-$$"
mkdir -p "$DATA_DIR"
```

---

## Future Improvements

### If Layer 2 Gets Implemented

```
Current:  6 agents × 1 tool/turn × 17 MCP/bash = 102 parallel ops
Future:   6 agents × 4 tools/turn × 17 MCP/bash = 408 parallel ops

Potential additional speedup: 4x
```

### Optimal Configuration (Future)

```yaml
Main Session:
  - Launch 6 subagents in parallel (L1)

Each Subagent:
  - Execute 4 Bash tools in parallel (L2, future)
  - Each Bash: 20 parallel MCP calls (L3)

Total: 6 × 4 × 20 = 480 parallel operations
```

---

## Appendix: Verification Data

### Session Analysis (January 2026)

| Metric | Value |
|--------|-------|
| Sessions analyzed | 113 |
| Total tool calls | 3,441 |
| Parallel tool calls | 0 |
| Parallel percentage | 0% |

### Benchmark Environment

| Component | Version/Value |
|-----------|---------------|
| Claude Code | 2.1.12+ |
| macOS | Darwin 25.x |
| bash | 5.2+ |
| jq | 1.7+ |
| MCP servers | google-workspace, github, claude-mem |

---

_Three-Layer Parallelism Architecture_
_Developed through production testing with AI Co-Founder system_
_January 2026_
