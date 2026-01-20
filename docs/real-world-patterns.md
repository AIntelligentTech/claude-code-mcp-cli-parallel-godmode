# Real-World Patterns: Three-Layer Parallelism in Production

Production-tested patterns for maximizing throughput using the Three-Layer
Parallelism architecture. Based on extensive testing with the AI Co-Founder
system (January 2026).

---

## Executive Summary

### L3: Genuine Speedup (Same Work, Less Time)

| Parallel Calls | Sequential | Parallel | Speedup     |
| -------------- | ---------- | -------- | ----------- |
| 10             | ~38s       | ~3.9s    | **9.7x**    |
| 20             | ~76s       | ~4.9s    | **15.5x**   |
| 50 (batched)   | ~190s      | ~10.5s   | **18.1x**   |

### L1: Throughput Scaling (More Work, Same Time)

| Configuration            | Operations Completed | Wall-Clock |
| ------------------------ | -------------------- | ---------- |
| 1 agent, 17 L3 ops       | 17                   | ~3.2s      |
| 3 agents, 17 L3 ops each | 51                   | ~3.5s      |
| 6 agents, 17 L3 ops each | 102                  | ~4.0s      |

**Key Finding:** L3 provides genuine speedup (2x-18x). L1 provides horizontal
throughput scaling (~6x more operations at similar latency). These are different
metrics — don't conflate them.

---

## Three-Layer Architecture Recap

```
Layer 1: SUBAGENT PARALLELISM
═════════════════════════════
Main session invokes multiple Task tools in ONE message
All subagents execute concurrently (6-8x multiplier)

Layer 2: TOOL CALL PARALLELISM (NOT IMPLEMENTED)
═══════════════════════════════════════════════
Claude API supports this, but Claude Code doesn't use it
Each subagent's tool calls are sequential within a turn

Layer 3: MCP-CLI PARALLELISM
════════════════════════════
Background jobs within Bash tool calls (18x multiplier)
mcp-cli call A > /tmp/a.json &
mcp-cli call B > /tmp/b.json &
wait
```

**Important distinction:**
- L3 = speedup (same operations, less time)
- L1 = throughput scaling (more operations, similar time)
- L1 does NOT multiply L3's speedup

---

## Pattern 1: Maximum Parallelism (Daily Briefing)

The most demanding real-world pattern: gather data from multiple sources and
synthesize into a comprehensive briefing.

### Architecture: L1 + L3 Combined

```yaml
# Main session sends ONE message with 3 Task tool calls (L1 parallelism)

Task:
  subagent_type: google-workspace-scanner
  prompt: |
    Scan all Google Workspace data.
    Email: tony.deverill@aintelligenttech.com

    Use parallel MCP-CLI (& and wait) for all calls.
    Output to /tmp/gws-$(date +%Y%m%d)/*.json

    Operations:
    - 9 calendar fetches (parallel)
    - 3 email searches (parallel)
    - 5 task list fetches (parallel)

    Return: manifest.json with file paths and summaries

Task:
  subagent_type: vault-scanner
  prompt: |
    Read and summarize vault documents:
    - GOALS.md
    - COMMITMENTS.md
    - CLIENTS.md

    Target output: 400-600 tokens (structured YAML)

Task:
  subagent_type: historical-git-scanner
  prompt: |
    Analyze recent activity across repositories.
    Repos: [list of 5-6 repos]

    Use parallel git commands internally.
    Output to /tmp/git-$(date +%Y%m%d)/*.txt

    Target output: 400-800 tokens
```

### Execution Timeline

```
┌─────────────────────────────────────────────────────────────────────────┐
│  LAYER 1: Subagent Parallelism (~5s total)                              │
│                                                                         │
│  Time →   0s    1s    2s    3s    4s    5s                              │
│           │─────────────────────────────│                               │
│  Agent 1: google-workspace-scanner      │                               │
│           │ L3: 17 MCP calls parallel   │                               │
│           └─────────────────────────────┘                               │
│           │───────────────│                                             │
│  Agent 2: vault-scanner   │ (file reads)                                │
│           └───────────────┘                                             │
│           │─────────────────────│                                       │
│  Agent 3: git-scanner           │ (parallel git cmds)                   │
│           └─────────────────────┘                                       │
│                                                                         │
│  All complete at: max(5s, 2s, 4s) = ~5 seconds                          │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  MAIN SESSION: Read results + Synthesize (~25-35s)                      │
│  ──────────────────────────────────────────────────────────────────────│
│  • Read /tmp/gws-*/*.json (parallel Read tools)                        │
│  • Read /tmp/git-*/*.txt (parallel Read tools)                         │
│  • Process 30k+ tokens (inherently sequential)                         │
│  • Generate Five Cs dashboard + briefing                               │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                        TOTAL: ~30-40 seconds
                        (vs ~180s sequential = 4.5-6x faster)
```

### Google Workspace Scanner Internal (L3)

```bash
# Inside google-workspace-scanner subagent
EMAIL="tony.deverill@aintelligenttech.com"
DATA_DIR="/tmp/gws-$(date +%Y%m%d)"
mkdir -p "$DATA_DIR"

# 17 parallel MCP calls (L3 parallelism within L1 agent)
# Calendars (9 calls)
mcp-cli call google-workspace/get_events "{\"user_google_email\":\"$EMAIL\",\"calendar_id\":\"primary\"}" > "$DATA_DIR/cal-primary.json" &
mcp-cli call google-workspace/get_events "{\"user_google_email\":\"$EMAIL\",\"calendar_id\":\"rituals\"}" > "$DATA_DIR/cal-rituals.json" &
mcp-cli call google-workspace/get_events "{\"user_google_email\":\"$EMAIL\",\"calendar_id\":\"finance\"}" > "$DATA_DIR/cal-finance.json" &
# ... 6 more calendars

# Email (3 calls)
mcp-cli call google-workspace/search_gmail_messages "{\"user_google_email\":\"$EMAIL\",\"query\":\"is:unread\"}" > "$DATA_DIR/email-unread.json" &
mcp-cli call google-workspace/search_gmail_messages "{\"user_google_email\":\"$EMAIL\",\"query\":\"in:inbox newer_than:7d\"}" > "$DATA_DIR/email-recent.json" &
mcp-cli call google-workspace/get_gmail_messages_content_batch "{\"user_google_email\":\"$EMAIL\",\"message_ids\":[\"...\"]}" > "$DATA_DIR/email-content.json" &

# Tasks (5 calls)
mcp-cli call google-workspace/list_tasks "{\"user_google_email\":\"$EMAIL\",\"task_list_id\":\"list1\"}" > "$DATA_DIR/tasks-1.json" &
mcp-cli call google-workspace/list_tasks "{\"user_google_email\":\"$EMAIL\",\"task_list_id\":\"list2\"}" > "$DATA_DIR/tasks-2.json" &
# ... 3 more task lists

wait

# Create manifest for main session
cat > "$DATA_DIR/manifest.json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "files": {
    "calendars": $(ls -1 "$DATA_DIR"/cal-*.json | jq -R . | jq -s .),
    "emails": $(ls -1 "$DATA_DIR"/email-*.json | jq -R . | jq -s .),
    "tasks": $(ls -1 "$DATA_DIR"/tasks-*.json | jq -R . | jq -s .)
  }
}
EOF

cat "$DATA_DIR/manifest.json"
```

**Performance:** ~3.2 seconds for 17 MCP calls (vs ~51s sequential = 16x faster)

---

## Pattern 2: Direct MCP (No Subagents)

For simpler operations where subagent overhead isn't justified.

### When to Use Direct MCP

| Scenario          | Use Pattern       | Why                               |
| ----------------- | ----------------- | --------------------------------- |
| 2-10 MCP calls    | Direct L3 only    | Subagent overhead exceeds benefit |
| Single domain     | Direct L3 only    | No parallelization opportunity    |
| Quick lookup      | Direct sequential | Simplicity > speed                |
| 10+ mixed sources | L1 + L3 combined  | Maximize throughput               |

### Direct L3 Pattern

```bash
# Single Bash tool call with L3 parallelism
EMAIL="tony.deverill@aintelligenttech.com"

mcp-cli call google-workspace/get_events "{\"user_google_email\":\"$EMAIL\"}" > /tmp/events.json &
mcp-cli call google-workspace/list_tasks "{\"user_google_email\":\"$EMAIL\",\"task_list_id\":\"primary\"}" > /tmp/tasks.json &
mcp-cli call google-workspace/search_gmail_messages "{\"user_google_email\":\"$EMAIL\",\"query\":\"is:unread\"}" > /tmp/email.json &
wait

cat /tmp/events.json /tmp/tasks.json /tmp/email.json
```

**Performance:** ~3s for 3 calls (vs ~12s sequential = 4x faster)

---

## Pattern 3: File System Communication

Subagents write to predictable temp paths; main session reads in parallel.

### The Pattern

```
┌─────────────────────────────────────────────────────────────────────────┐
│  SUBAGENT EXECUTION                                                     │
│                                                                         │
│  google-workspace-scanner:                                              │
│    Writes to /tmp/gws-YYYYMMDD/*.json                                   │
│    Returns manifest.json with file paths                                │
│                                                                         │
│  vault-scanner:                                                         │
│    Returns inline YAML (small output)                                   │
│                                                                         │
│  git-scanner:                                                           │
│    Writes to /tmp/git-YYYYMMDD/*.txt                                    │
│    Returns summary with file paths                                      │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  MAIN SESSION                                                           │
│                                                                         │
│  # Parse manifest, read files in parallel                               │
│  Read: /tmp/gws-20260120/manifest.json                                  │
│  Read: /tmp/gws-20260120/cal-primary.json                               │
│  Read: /tmp/gws-20260120/cal-finance.json                               │
│  Read: /tmp/git-20260120/repo1.txt                                      │
│  # All Read tools execute in parallel                                   │
└─────────────────────────────────────────────────────────────────────────┘
```

### Benefits

1. **Large data handling** — Subagents can process 100k+ tokens, return 500-token summary
2. **Selective loading** — Main session reads only what it needs
3. **Persistent results** — Files remain for debugging/reuse
4. **Parallel reads** — Multiple Read tools in one message execute concurrently

---

## Pattern 4: Wave-Based Execution

When operations have dependencies, use waves.

### Two-Wave Pattern

```bash
# Wave 1: Discovery (all parallel)
mcp-cli call google-workspace/list_calendars '{}' > /tmp/calendars.json &
mcp-cli call google-workspace/list_task_lists '{}' > /tmp/task_lists.json &
wait

# Extract IDs
CAL_IDS=$(jq -r '.[].id' /tmp/calendars.json)
TASK_LIST_IDS=$(jq -r '.[].id' /tmp/task_lists.json)

# Wave 2: Fetch data using discovered IDs (all parallel)
for CAL in $CAL_IDS; do
  mcp-cli call google-workspace/get_events "{\"calendar_id\":\"$CAL\"}" > "/tmp/cal-$CAL.json" &
done
for LIST in $TASK_LIST_IDS; do
  mcp-cli call google-workspace/list_tasks "{\"task_list_id\":\"$LIST\"}" > "/tmp/tasks-$LIST.json" &
done
wait

cat /tmp/cal-*.json /tmp/tasks-*.json
```

### When to Use Waves

| Scenario                        | Waves Needed |
| ------------------------------- | ------------ |
| Static IDs (cached)             | 1            |
| Discovery required              | 2            |
| Dependent data (A → B → C)      | 3+           |

---

## Pattern 5: Batch Operations

For bulk modifications (10+ operations), use batch operators.

### Calendar Batch Pattern

```yaml
Task:
  subagent_type: calendar-batch-operator
  prompt: |
    Create the following events on Finance calendar:
    - Jan 25: "Domain renewal - example.com" £15
    - Feb 1: "Subscription - Service X" £29
    - Feb 15: "Insurance payment" £120

    Use wave batching (20 operations per wave).
    Email: tony.deverill@aintelligenttech.com
```

### Tasks Batch Pattern

```yaml
Task:
  subagent_type: tasks-batch-operator
  prompt: |
    Mark the following tasks complete:
    - Task ID 1
    - Task ID 2
    - Task ID 3

    Update status for:
    - Task ID 4: Add note "In progress"
    - Task ID 5: Change due date to tomorrow

    Use parallel operations (& and wait).
```

---

## Pattern 6: Repository Cluster Analysis

For multi-repository development context.

### Git Scanner Pattern

```yaml
# Launch multiple git scanners in parallel (L1)
Task:
  subagent_type: historical-git-scanner
  prompt: |
    Analyze repos: [repo1, repo2, repo3, repo4, repo5]
    Output to /tmp/git-cluster1/
    Use internal parallelism for git commands.

Task:
  subagent_type: historical-git-scanner
  prompt: |
    Analyze repos: [repo6, repo7, repo8, repo9, repo10]
    Output to /tmp/git-cluster2/
    Use internal parallelism for git commands.
```

### Internal Git Parallelism (L3)

```bash
# Inside git-scanner subagent
OUTPUT_DIR="/tmp/git-cluster1"
mkdir -p "$OUTPUT_DIR"

for repo in /path/to/repo{1..5}; do
  (
    cd "$repo"
    echo "=== $(basename $repo) ===" > "$OUTPUT_DIR/$(basename $repo).txt"
    git log --oneline -20 --since="7 days ago" >> "$OUTPUT_DIR/$(basename $repo).txt"
    git status -s >> "$OUTPUT_DIR/$(basename $repo).txt"
    git diff --stat HEAD~5..HEAD >> "$OUTPUT_DIR/$(basename $repo).txt"
  ) &
done
wait

# Create summary
cat "$OUTPUT_DIR"/*.txt
```

---

## Anti-Patterns

### Anti-Pattern 1: Sequential Subagent Spawning

```yaml
# WRONG: Each Task waits for previous
Task: calendar-scanner   # 5s
# wait
Task: email-scanner      # 5s
# wait
Task: tasks-scanner      # 5s
# Total: 15s
```

**Fix:** Send all Task tools in ONE message:

```yaml
# CORRECT: All execute in parallel
Task: calendar-scanner   # ─┐
Task: email-scanner      #  │ All parallel = ~5s
Task: tasks-scanner      # ─┘
```

### Anti-Pattern 2: L3 Without L1 for Large Operations

```bash
# WRONG: Single Bash with 50+ MCP calls
mcp-cli call server/tool1 '{}' > /tmp/r1.json &
# ... 49 more in same Bash
wait
# Limited by single agent's Bash throughput
```

**Fix:** Use L1 + L3 combined:

```yaml
# CORRECT: Split across parallel subagents
Task: scanner-1  # L3: calls 1-17
Task: scanner-2  # L3: calls 18-34
Task: scanner-3  # L3: calls 35-50
# L1 parallelism × L3 parallelism = faster
```

### Anti-Pattern 3: Expecting Model Selection to Work

```yaml
# WRONG: Model parameter doesn't reliably work
Task:
  model: haiku  # Won't consistently use Haiku
  prompt: "..."
```

**Fix:** Use token budget constraints:

```yaml
# CORRECT: Constrain output verbosity
Task:
  prompt: |
    ...
    IMPORTANT: Target output 400-600 tokens max.
    Return structured YAML, not verbose prose.
```

### Anti-Pattern 4: Not Using File System for Large Data

```yaml
# WRONG: Returning 50k tokens inline
Task:
  prompt: |
    Fetch all calendar events and return them.
    # Returns massive inline JSON
```

**Fix:** Write to files, return manifest:

```yaml
# CORRECT: Write to files, return summary
Task:
  prompt: |
    Fetch all calendar events.
    Write to /tmp/cal-data/*.json
    Return manifest with file paths (not content).
```

---

## Performance Reference

### L3 Speedup (Verified Benchmarks)

| Parallel Calls | Sequential Time | Parallel Time | Speedup     |
| -------------- | --------------- | ------------- | ----------- |
| 2              | ~7.6s           | ~3.8s         | **2.0x**    |
| 5              | ~19s            | ~3.8s         | **5.0x**    |
| 10             | ~38s            | ~3.9s         | **9.7x**    |
| 20             | ~76s            | ~4.9s         | **15.5x**   |
| 50 (batched)   | ~190s           | ~10.5s        | **18.1x**   |

### L1 Throughput Scaling

| Configuration            | Operations Completed | Wall-Clock | vs 1 Agent |
| ------------------------ | -------------------- | ---------- | ---------- |
| 1 agent, 17 L3 ops       | 17                   | ~3.2s      | baseline   |
| 3 agents, 17 L3 ops each | 51                   | ~3.5s      | 3x ops     |
| 6 agents, 17 L3 ops each | 102                  | ~4.0s      | 6x ops     |

**Note:** L1 does NOT reduce time for fixed work. It increases total operations
processed at similar latency.

### Daily Briefing (Practical Example)

| Phase               | Sequential | With L3    | Notes                      |
| ------------------- | ---------- | ---------- | -------------------------- |
| MCP data (17 calls) | ~65s       | ~3.2s      | L3 speedup: **20x**        |
| Git analysis        | ~45s       | ~10s       | Parallel git commands      |
| Vault reads         | ~10s       | ~2s        | Parallel Read tools        |
| **Data gathering**  | **~120s**  | **~10s**   | **L3: ~12x speedup**       |
| Synthesis           | ~30s       | ~30s       | LLM-bound, cannot parallelize |
| **End-to-end**      | **~150s**  | **~40s**   | **~3.75x improvement**     |

Adding L1 (multiple agents) would process more data in similar time, not faster.

---

## Decision Guide: Which Pattern to Use

```
┌─────────────────────────────────────────────────────────────────────────┐
│  How many MCP operations?                                               │
│                                                                         │
│  1 operation       → Sequential (no parallelism needed)                 │
│  2-10 operations   → L3 only (direct parallel MCP)                      │
│  10-20 operations  → L3 with wave batching OR L1+L3                     │
│  20-50 operations  → L1+L3 combined (2-3 subagents)                     │
│  50+ operations    → L1+L3 with wave batching                           │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  Do you need different domains?                                         │
│                                                                         │
│  Single domain (e.g., just calendars) → L3 only                         │
│  Multiple domains (cal + email + git) → L1+L3 (domain per agent)        │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  How much data will be returned?                                        │
│                                                                         │
│  Small (< 5k tokens)  → Return inline                                   │
│  Medium (5-20k)       → Return inline or file                           │
│  Large (> 20k)        → File system + manifest pattern                  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Known Issues

### Subagent Model Selection Bug

**Issue:** Setting `model: haiku` in Task tool doesn't reliably use the
specified model.

**Workaround:** Include explicit token budget in prompts:

```yaml
prompt: |
  ...
  IMPORTANT: Target output 400-600 tokens maximum.
  Return structured YAML, not verbose prose.
  Do NOT include explanations or commentary.
```

### Layer 2 Gap

**Issue:** Claude API supports parallel tool calls within a message turn, but
Claude Code doesn't implement this capability.

**Workaround:** Maximize L1 (subagent) and L3 (MCP-CLI) parallelism to
compensate.

---

_Document created: January 20, 2026_
_Revised: January 20, 2026 — Updated for Three-Layer Parallelism architecture_
_Based on production testing with AI Co-Founder system_
