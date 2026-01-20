# Real-World Patterns: Tested January 2026

This document captures MCP-CLI parallelization patterns verified through
production testing with the AI Co-Founder system.

---

## Executive Summary

| Pattern                        | Old (Subagents) | New (Direct MCP) | Speedup     |
| ------------------------------ | --------------- | ---------------- | ----------- |
| **Data Gathering (MCP + Git)** | ~90s            | ~15s             | **6x**      |
| **Full Briefing (end-to-end)** | 2-3 min         | ~35-55s          | **3-4x**    |

**Key Finding:** Direct parallel MCP calls **replace tier-1 subagents entirely**,
eliminating ~20-30 seconds of agent startup overhead. Combined with parallel git
analysis in the same Claude message, data gathering drops from ~90 seconds to
~15 seconds.

**Architecture Shift:**
- **Old:** 6 sequential subagent spawns → each runs MCP/git → synthesis
- **New:** Single message with parallel MCP + Git + Reads → synthesis

See [Scope & Limitations](#scope--limitations) for full breakdown.

---

## Scope & Limitations

### What These Patterns Optimize

✅ **MCP-CLI operations** — Calls to Google Workspace, GitHub, claude-mem, etc.
✅ **File reads** — Parallel Read tool invocations
✅ **Git analysis** — Can run in parallel with MCP calls
✅ **Eliminates subagent overhead** — Direct calls replace tier-1 agent spawning

### What These Patterns Do NOT Optimize

❌ **Token processing time** — Synthesis of 30k+ tokens is inherently sequential
❌ **Dependent operations** — Some calls depend on results of previous waves

### Key Insight: Direct MCP Replaces Most Tier-1 Agents

The tier-1 subagent architecture had significant overhead:

| Old Agent | What It Did | Replaced By | Overhead Eliminated |
|-----------|-------------|-------------|---------------------|
| calendar-scanner | MCP calls | Direct parallel MCP | ~3-5s startup |
| email-scanner | MCP calls | Direct parallel MCP | ~3-5s startup |
| tasks-scanner | MCP calls | Direct parallel MCP | ~3-5s startup |
| historical-memory-scanner | MCP calls | Direct parallel MCP | ~3-5s startup |
| vault-scanner | File reads | Parallel Read tools | ~3-5s startup |
| historical-git-scanner | Git commands | Parallel Bash tool | ~3-5s startup |

**Total subagent overhead eliminated: ~20-30 seconds**

### Optimized Architecture: Single Parallel Wave

With direct MCP calls, MCP gathering and git analysis run **in parallel**:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  SINGLE CLAUDE MESSAGE — ALL PARALLEL (~15 seconds total)               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Bash 1: All MCP (~9s)   │  Bash 2: Git Analysis   │  Read: Vault       │
│  ──────────────────────  │  (~10-15s, internal &)  │  ─────────────     │
│  9 calendar calls &      │  25 repos analyzed      │  GOALS.md          │
│  5 task list calls &     │  5-6 git cmds each      │  COMMITMENTS.md    │
│  Gmail search + batch &  │  Uses background jobs   │  CLIENTS.md        │
│  4 claude-mem calls &    │  internally             │  EXPENSES.md       │
│  wait                    │  wait                   │                    │
│                                                                         │
│  Wall-clock time: max(9s, 15s, 1s) = ~15 seconds                        │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  SYNTHESIS & OUTPUT (~20-40 seconds)                                    │
│  ───────────────────────────────────────────────────────────────────────│
│  • 30k+ token context processing                                        │
│  • Five Cs dashboard generation                                         │
│  • Briefing document creation                                           │
│  • Task flagging and updates                                            │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                        TOTAL: ~35-55 seconds
```

**Bottom line:** With direct MCP + parallel git analysis, data gathering takes
~15 seconds (not 90-180s). Full briefing including synthesis: ~35-55 seconds.

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

### Optimized Briefing Timing (Direct MCP + Parallel Git)

| Component                | Time     | Notes                              |
| ------------------------ | -------- | ---------------------------------- |
| MCP data gathering       | ~9s      | Parallel (this toolkit)            |
| Git analysis             | ~10-15s  | Parallel with MCP, internal jobs   |
| Vault file reads         | ~1s      | Parallel Read tools                |
| **Data gathering total** | **~15s** | max(9s, 15s, 1s) — all parallel    |
| Synthesis                | ~20-40s  | Token processing + output          |
| **End-to-End Total**     | **~35-55s** |                                 |

### Comparison: Old (Subagents) vs New (Direct MCP)

| Metric                  | Old (Subagents)  | New (Direct MCP) | Improvement |
| ----------------------- | ---------------- | ---------------- | ----------- |
| Subagent overhead       | ~20-30s          | 0s               | **Eliminated** |
| MCP + Git + Reads       | ~60s (sequential)| ~15s (parallel)  | **4x**      |
| Synthesis               | ~20-40s          | ~20-40s          | Same        |
| **End-to-end briefing** | **~2-3 min**     | **~35-55s**      | **3-4x**    |

---

## Summary: What This Toolkit Achieves

```
┌─────────────────────────────────────────────────────────────────────────┐
│  SINGLE PARALLEL WAVE (all in one Claude message)                       │
│                                                                         │
│  Bash 1: All MCP (~9s)   │  Bash 2: Git (~10-15s) │  Read: Vault (~1s) │
│  ──────────────────────  │  ────────────────────  │  ───────────────── │
│  9 calendar calls &      │  25 repos analyzed     │  GOALS.md          │
│  5 task list calls &     │  5-6 git cmds each     │  COMMITMENTS.md    │
│  Gmail search + batch &  │  Uses background jobs  │  CLIENTS.md        │
│  4 claude-mem calls &    │  internally            │  EXPENSES.md       │
│  wait                    │  wait                  │                    │
│                                                                         │
│  Wall-clock time: max(9s, 15s, 1s) = ~15 seconds                        │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  SYNTHESIS (~20-40 seconds)                                             │
│  • 30k+ token processing — inherently sequential                        │
│  • Five Cs dashboard, briefing doc, task updates                        │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                        END-TO-END: ~35-55 seconds
```

**Bottom Line:**

- ✅ Direct MCP **replaces tier-1 subagents** — eliminates ~20-30s overhead
- ✅ MCP + Git + Reads run **in parallel** — ~15s instead of ~90s sequential
- ✅ Full briefing: **~35-55 seconds** (down from 2-3 minutes)
- ✅ **3-4x end-to-end speedup**

---

## Architecture Transition

### From Subagents to Direct MCP

| Old Pattern (Subagents) | New Pattern (Direct MCP) |
|-------------------------|--------------------------|
| Spawn calendar-scanner → wait | Direct `mcp-cli call google-workspace/get_events &` |
| Spawn email-scanner → wait | Direct `mcp-cli call google-workspace/search_gmail_messages &` |
| Spawn tasks-scanner → wait | Direct `mcp-cli call google-workspace/list_tasks &` |
| Spawn memory-scanner → wait | Direct `mcp-cli call claude-mem/search &` |
| Spawn vault-scanner → wait | Direct `Read: GOALS.md, CLIENTS.md, ...` |
| Spawn git-scanner → wait | Direct `git log ... & git status ... & wait` |
| **Sequential: ~90s** | **Parallel: ~15s** |

### What Remains Sequential

1. **Synthesis** — LLM token processing is inherently sequential (~20-40s)
2. **Dependent waves** — When call B needs result of call A

### Fully Optimized Briefing

```bash
# Single Claude message with 3 parallel Bash tools + multiple Read tools

# Bash 1: All MCP operations
EMAIL="tony.deverill@aintelligenttech.com"
mcp-cli call google-workspace/get_events "{\"user_google_email\":\"$EMAIL\",\"calendar_id\":\"$CAL1\"}" > /tmp/cal1.json &
# ... 8 more calendars
mcp-cli call google-workspace/list_tasks "{\"user_google_email\":\"$EMAIL\",\"task_list_id\":\"$LIST1\"}" > /tmp/tasks1.json &
# ... 4 more task lists
mcp-cli call google-workspace/search_gmail_messages "{\"user_google_email\":\"$EMAIL\",\"query\":\"is:unread\"}" > /tmp/gmail.json &
mcp-cli call claude-mem/search '{"query":"recent decisions"}' > /tmp/mem.json &
wait

# Bash 2: Git analysis (all repos in parallel internally)
for repo in /path/to/repo{1..25}; do
  (cd "$repo" && git log --oneline -10 --since="7 days" && git status -s) > "/tmp/git_$(basename $repo).txt" &
done
wait

# Read tools (parallel with Bash tools)
Read: GOALS.md, COMMITMENTS.md, CLIENTS.md, EXPENSES.md
```

---

_Document created: January 20, 2026_
_Revised: January 20, 2026 — Added scope clarification and accurate end-to-end metrics_
_Based on production testing with AI Co-Founder system_
