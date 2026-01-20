# Real-World Patterns: Tested January 2026

This document captures patterns verified through production testing with the AI
Co-Founder system, which gathers data from Google Workspace, GitHub, and local
vault files.

---

## Executive Summary

| Pattern | Sequential | Level 1 Only | Level 1 + Level 2 |
| ------- | ---------- | ------------ | ----------------- |
| Briefing Data Gathering | ~3-4 min | ~90s | **~9s** |
| Speedup vs Sequential | — | 2-3x | **20x+** |

**Key Finding:** Level 2 parallelization (multiple Bash tool calls in a single
Claude message) provides multiplicative speedup on top of Level 1 (background
jobs within each Bash call).

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

## Pattern 2: Wave Architecture for Briefings

Real-world briefings typically need data from multiple sources with
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

**Total: 2 Claude messages, ~9 seconds, complete briefing data.**

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

### Measured Performance

| Configuration | Time | Operations |
| ------------- | ---- | ---------- |
| 1 Bash × 5 MCP | 1.5s | 5 |
| 3 Bash × 5 MCP | 2.0s | 15 |
| 4 Bash × 5 MCP | 2.5s | 20 |

**Observation:** Adding more Bash tools only marginally increases total time.
The multiplicative effect is real.

### When to Use Level 2

| Scenario | Recommendation |
| -------- | -------------- |
| 2-10 MCP calls | Level 1 only (single Bash) |
| 10-20 MCP calls | Level 2 with 2-3 Bash tools |
| 20-50 MCP calls | Level 2 with 3-4 Bash tools |
| 50+ MCP calls | Wave batch with Level 2 |

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

### Briefing Data Gathering

| Phase | Operations | Time | Pattern |
| ----- | ---------- | ---- | ------- |
| Phase 1 | 5 MCP + 4 files | ~3s | Level 1 + Level 2 |
| Phase 2 | 10 MCP + git | ~6s | Level 1 + Level 2 |
| **Total** | **15 MCP + 4 files + git** | **~9s** | |

### Comparison to Previous Approach

| Metric | Level 1 Only | Level 1 + Level 2 | Improvement |
| ------ | ------------ | ----------------- | ----------- |
| Time | ~90s | ~9s | **10x** |
| Tool Calls | ~12 | 6 | **2x fewer** |
| Context Usage | Higher | Lower | Reduced |

---

## Summary: Optimal Briefing Pattern

```
┌─────────────────────────────────────────────────────────────────────────┐
│  SINGLE WAVE (if IDs cached from previous session)                      │
│                                                                         │
│  Bash 1: Calendars (9x)  │ Bash 2: Tasks (5x)  │ Bash 3: Gmail+Git     │
│  All get_events &        │ All list_tasks &    │ search + batch &      │
│  wait && cat all         │ wait && cat all     │ wait && cat all       │
│                          │                     │                       │
│  Read: GOALS.md          │ Read: CLIENTS.md    │ Read: RECURRING.md    │
│  Read: COMMITMENTS.md    │ Read: EXPENSES.md   │                       │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                        SYNTHESIS (~1 second)
```

**Predicted time with cached IDs: 3-5 seconds total**

---

_Document created: January 20, 2026_
_Based on production testing with AI Co-Founder system_
