# Real-World Patterns: Tested January 2026

This document captures MCP-CLI parallelization patterns verified through
production testing with the AI Co-Founder system.

---

## Executive Summary

| Pattern                   | Sequential | Parallel | Speedup     |
| ------------------------- | ---------- | -------- | ----------- |
| **MCP Data Gathering**    | ~60s       | ~9s      | **6-7x**    |
| Full Briefing (end-to-end)| 2-3 min    | ~90s     | ~2x (*)     |

**Key Finding:** Level 1 parallelization (background jobs within Bash) provides
6-7x speedup for MCP operations specifically. Combined with Level 2 (multiple
Bash calls in one Claude message), MCP data gathering completes in ~9 seconds.

> **(*) Important Scope Clarification:** The ~9 second metric applies to **MCP
> data gathering only** (~15 operations). A full end-to-end briefing includes
> additional layers (subagent orchestration, git analysis, synthesis) that add
> 60-90 seconds. See [Scope & Limitations](#scope--limitations) below.

---

## Scope & Limitations

### What These Patterns Optimize

✅ **MCP-CLI operations** — Calls to Google Workspace, GitHub, claude-mem, etc.
✅ **File reads** — Parallel Read tool invocations
✅ **Wave architecture** — Dependency-aware batching

### What These Patterns Do NOT Optimize

❌ **Subagent lifecycle overhead** — Each `Task` tool invocation has ~2-3s
startup latency
❌ **Internal agent operations** — Agents like `historical-git-scanner` run
125+ bash operations internally
❌ **Token processing time** — Synthesis of 30k+ tokens takes additional time
❌ **Multi-wave orchestration** — Sequential dependency chains between phases

### Full Briefing Breakdown

A complete AI Co-Founder briefing (~2-3 minutes) includes:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Layer 1: MCP Data Gathering (~9 seconds with parallelization)          │
│  ───────────────────────────────────────────────────────────────────────│
│  • 9 calendar queries                                                   │
│  • 5 task list queries                                                  │
│  • Gmail search + batch content                                         │
│  • 4 claude-mem queries                                                 │
│  • 4-6 vault file reads                                                 │
│  Total: ~25-30 MCP operations                                           │
├─────────────────────────────────────────────────────────────────────────┤
│  Layer 2: Subagent Orchestration (~20-30 seconds overhead)              │
│  ───────────────────────────────────────────────────────────────────────│
│  • 6 tier-1 agents spawned (vault, calendar, email, tasks, memory, git) │
│  • Each agent: ~2-3s startup + prompt processing                        │
│  • Sequential spawning (Claude Code limitation)                         │
├─────────────────────────────────────────────────────────────────────────┤
│  Layer 3: Historical Git Analysis (~30-60 seconds)                      │
│  ───────────────────────────────────────────────────────────────────────│
│  • 25 repositories analyzed                                             │
│  • 5-6 git commands per repo (log, diff, status)                        │
│  • AgentOS context extraction                                           │
│  • Total: 125-150 bash operations                                       │
├─────────────────────────────────────────────────────────────────────────┤
│  Layer 4: Synthesis & Output (~20-40 seconds)                           │
│  ───────────────────────────────────────────────────────────────────────│
│  • 30k+ token context processing                                        │
│  • Five Cs dashboard generation                                         │
│  • Briefing document creation                                           │
│  • Task flagging and updates                                            │
└─────────────────────────────────────────────────────────────────────────┘
```

**Bottom line:** MCP parallelization saves ~50 seconds per briefing (from ~60s
to ~9s for MCP layer), but the full briefing still takes 90-180 seconds due to
other layers.

---

## Pattern 1: Combined Execute + Read

**Problem:** Separate Bash calls for executing MCP operations and reading
results wastes time.

**Before (2 tool calls):**

```bash
# Tool call 1: Execute
mcp-cli call server/tool1 '{}' > /tmp/r1.json &
mcp-cli call server/tool2 '{}' > /tmp/r2.json &
wait

# Tool call 2: Read (separate invocation = sequential wait)
cat /tmp/r1.json
cat /tmp/r2.json
```

**After (1 tool call):**

```bash
# Single tool call: Execute + Read combined
mcp-cli call server/tool1 '{}' > /tmp/r1.json &
mcp-cli call server/tool2 '{}' > /tmp/r2.json &
wait
cat /tmp/r1.json /tmp/r2.json  # Combined in same block
```

**Savings:** Eliminates one round-trip per batch.

---

## Pattern 2: Wave Architecture for MCP Operations

Real-world data gathering typically needs data from multiple sources with
dependencies. Use a **two-wave architecture**:

### Wave 1: Discovery + Static Data (Parallel)

All independent operations in one message:

```bash
# Bash Tool 1: Google Workspace Discovery
EMAIL="you@example.com"
mcp-cli call google-workspace/list_calendars "{\"user_google_email\":\"$EMAIL\"}" > /tmp/calendars.json &
mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$EMAIL\"}" > /tmp/task_lists.json &
mcp-cli call google-workspace/search_gmail_messages "{\"user_google_email\":\"$EMAIL\",\"query\":\"in:inbox newer_than:7d\"}" > /tmp/gmail.json &
wait
cat /tmp/calendars.json /tmp/task_lists.json /tmp/gmail.json
```

```bash
# Bash Tool 2: Memory/History (runs in parallel with Tool 1)
mcp-cli call claude-mem/search '{"query":"recent decisions","limit":5}' > /tmp/mem.json &
git log --oneline -15 --since="7 days ago" > /tmp/git.json &
wait
cat /tmp/mem.json /tmp/git.json
```

```
# Read Tools 3-6: Vault Files (parallel with Bash Tools 1-2)
Read: GOALS.md, COMMITMENTS.md, CLIENTS.md, EXPENSES.md
```

**Wave 1 Result:** All discovery data + vault context in ~3 seconds.

### Wave 2: Data Fetch with Extracted IDs

Using IDs from Wave 1 (calendars, task lists, email message IDs):

```bash
# Bash Tool 1: Calendar Events (9 calendars)
mcp-cli call google-workspace/get_events "{\"calendar_id\":\"$CAL1\",...}" > /tmp/cal1.json &
mcp-cli call google-workspace/get_events "{\"calendar_id\":\"$CAL2\",...}" > /tmp/cal2.json &
# ... 7 more calendars
wait
cat /tmp/cal*.json
```

```bash
# Bash Tool 2: Task Lists (5 lists) - parallel with Tool 1
mcp-cli call google-workspace/list_tasks "{\"task_list_id\":\"$LIST1\"}" > /tmp/tasks1.json &
mcp-cli call google-workspace/list_tasks "{\"task_list_id\":\"$LIST2\"}" > /tmp/tasks2.json &
# ... 3 more lists
wait
cat /tmp/tasks*.json
```

**Wave 2 Result:** All detailed data in ~6 seconds.

**MCP Layer Total: 2 Claude messages, ~9 seconds for ~25-30 MCP operations.**

---

## Pattern 3: ID Caching

Calendar IDs and task list IDs rarely change. Cache them:

```bash
# First briefing of session: Full discovery
mcp-cli call google-workspace/list_calendars '{}' > /tmp/calendars.json &
wait
# Extract and cache IDs for future calls
CALENDAR_IDS=$(jq -r '.[].id' /tmp/calendars.json)
```

```bash
# Subsequent briefings: Skip discovery, use cached IDs directly
for CAL_ID in $CALENDAR_IDS; do
  mcp-cli call google-workspace/get_events "{\"calendar_id\":\"$CAL_ID\"}" > /tmp/cal_${CAL_ID}.json &
done
wait
```

**Savings:** Reduces from 2 waves to 1 wave after first briefing.

---

## Pattern 4: Level 2 Optimization

**Key Insight:** Claude Code processes multiple Bash tool calls in a single
message **truly in parallel**, not queued.

### Measured Performance (MCP Layer Only)

| Configuration  | Time | Operations |
| -------------- | ---- | ---------- |
| 1 Bash × 5 MCP | 1.5s | 5          |
| 3 Bash × 5 MCP | 2.0s | 15         |
| 4 Bash × 5 MCP | 2.5s | 20         |

**Observation:** Adding more Bash tools only marginally increases total time.
The multiplicative effect is real.

### When to Use Level 2

| Scenario       | Recommendation                    |
| -------------- | --------------------------------- |
| 2-10 MCP calls | Level 1 only (single Bash)        |
| 10-20 MCP calls| Level 2 with 2-3 Bash tools       |
| 20-50 MCP calls| Level 2 with 3-4 Bash tools       |
| 50+ MCP calls  | Wave batch with Level 2           |

### Domain Separation

Level 2 works best when different Bash tools handle different domains:

```
Message with 3 parallel Bash tools:

Bash 1: Google Calendars  │  Bash 2: Google Tasks  │  Bash 3: Gmail + Git
─────────────────────────┼──────────────────────────┼───────────────────────
get_events (cal1) &      │  list_tasks (list1) &   │  search_gmail &
get_events (cal2) &      │  list_tasks (list2) &   │  get_gmail_batch &
get_events (cal3) &      │  list_tasks (list3) &   │  git log &
wait && cat              │  wait && cat            │  wait && cat
```

---

## Pattern 5: Read Tool Parallelization

The Read tool in Claude Code also runs in parallel when multiple are sent in the
same message.

**Optimal Pattern:**

```
Single message with:
- Bash Tool 1: MCP calls for calendars
- Bash Tool 2: MCP calls for tasks
- Read Tool 3: GOALS.md
- Read Tool 4: COMMITMENTS.md
- Read Tool 5: CLIENTS.md
- Read Tool 6: RECURRING-PAYMENTS.md
```

All 6 tools execute in parallel, results return together.

---

## Anti-Patterns Observed

### Anti-Pattern 1: Sequential Result Reading

```bash
# WRONG: 4 separate tool calls to read results
cat /tmp/r1.json  # Tool call 1
cat /tmp/r2.json  # Tool call 2
cat /tmp/r3.json  # Tool call 3
cat /tmp/r4.json  # Tool call 4
```

**Fix:** Combine into one:

```bash
cat /tmp/r1.json /tmp/r2.json /tmp/r3.json /tmp/r4.json
```

### Anti-Pattern 2: Level 1 Only for Large Batches

```bash
# WRONG: 20 MCP calls in single Bash tool
mcp-cli call ... > /tmp/r1.json &
# ... 19 more
wait
```

**Fix:** Split across 3-4 parallel Bash tools (Level 2):

```bash
# Bash 1: Calls 1-7
# Bash 2: Calls 8-14
# Bash 3: Calls 15-20
```

### Anti-Pattern 3: Forgetting Schema Checks

```bash
# WRONG: Call without checking schema first
mcp-cli call google-workspace/search_gmail_messages '{"max_results": 20}' # Error: wrong param name
```

**Fix:** Always parallel-batch schema checks:

```bash
mcp-cli info google-workspace/search_gmail_messages > /tmp/schema.json &
wait
# Schema shows 'limit' not 'max_results'
```

---

## Real-World Test Results (January 2026)

### Test Configuration

- **Platform:** macOS Darwin 25.x
- **Claude Code:** 2.1.12+
- **MCP Servers:** google-workspace, github, claude-mem

### MCP Data Gathering (Validated)

| Phase   | Operations       | Time | Pattern            |
| ------- | ---------------- | ---- | ------------------ |
| Wave 1  | 5 MCP + 4 files  | ~3s  | Level 1 + Level 2  |
| Wave 2  | 10 MCP           | ~6s  | Level 1 + Level 2  |
| **Total MCP Layer** | **15 MCP + 4 files** | **~9s** | |

### Full Briefing Timing (Observed)

| Component              | Time     | Notes                              |
| ---------------------- | -------- | ---------------------------------- |
| MCP data gathering     | ~9s      | Parallelized (this toolkit)        |
| Subagent orchestration | ~20-30s  | 6 agents × ~3-5s each (sequential) |
| Historical git analysis| ~30-60s  | 25 repos × 5-6 commands            |
| Synthesis              | ~20-40s  | Token processing + output          |
| **End-to-End Total**   | **90-180s** | ~2-3 minutes                    |

### What This Toolkit Improves

| Metric                  | Before (Sequential MCP) | After (Parallel MCP) | Improvement |
| ----------------------- | ----------------------- | -------------------- | ----------- |
| MCP layer time          | ~60s                    | ~9s                  | **6.7x**    |
| Tool calls for MCP      | ~12                     | 6                    | **2x fewer**|
| Context usage           | Higher                  | Lower                | Reduced     |
| **End-to-end briefing** | **~3-4 min**            | **~2-3 min**         | **~1.5x**   |

---

## Summary: What This Toolkit Achieves

```
┌─────────────────────────────────────────────────────────────────────────┐
│  MCP DATA GATHERING (optimized by this toolkit)                         │
│                                                                         │
│  Bash 1: Calendars (9x)  │ Bash 2: Tasks (5x)  │ Bash 3: Gmail+Git     │
│  All get_events &        │ All list_tasks &    │ search + batch &      │
│  wait && cat all         │ wait && cat all     │ wait && cat all       │
│                          │                     │                       │
│  Read: GOALS.md          │ Read: CLIENTS.md    │ Read: RECURRING.md    │
│  Read: COMMITMENTS.md    │ Read: EXPENSES.md   │                       │
│                                                                         │
│  Time: ~9 seconds for ~25-30 operations                                 │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  ADDITIONAL LAYERS (not optimized by this toolkit)                      │
│                                                                         │
│  • Subagent orchestration: ~20-30s (sequential, architectural limit)    │
│  • Git analysis: ~30-60s (125+ bash ops, internal to agent)             │
│  • Synthesis: ~20-40s (token processing)                                │
│                                                                         │
│  Additional time: ~70-130 seconds                                       │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                        END-TO-END: ~90-180 seconds
```

**Bottom Line:**

- ✅ MCP parallelization provides **6-7x speedup** for data gathering
- ✅ Saves ~50 seconds per briefing on MCP layer
- ⚠️ Full briefing still takes ~2-3 minutes due to other layers
- 📊 Measured 45.5% MCP parallel adoption, 9.3 min/day saved across all sessions

---

## Future Optimization Opportunities

### Currently Not Parallelizable

1. **Subagent spawning** — Claude Code spawns Task tools sequentially
2. **Internal agent operations** — Each agent runs its own operations
3. **Token synthesis** — Processing 30k+ tokens is inherently sequential

### Potential Improvements

1. **Replace subagents with direct MCP calls** — Eliminates agent overhead
2. **Pre-fetch git data** — Cache repo status to avoid repeated analysis
3. **Incremental synthesis** — Process results as they arrive

---

_Document created: January 20, 2026_
_Revised: January 20, 2026 — Added scope clarification and accurate end-to-end metrics_
_Based on production testing with AI Co-Founder system_
