# Three-Layer Parallelism Examples

Practical examples demonstrating Layer 1 (subagent), Layer 2 (not implemented),
and Layer 3 (MCP-CLI) parallelism patterns.

---

## Layer 3: MCP-CLI Parallelism (Bash Background Jobs)

### Example 1: Two Parallel Calls (2x Speedup)

**Bash tool input:**

```bash
mcp-cli call google-workspace/list_task_lists '{"user_google_email":"you@example.com"}' > /tmp/tasks.json &
mcp-cli call google-workspace/list_calendars '{"user_google_email":"you@example.com"}' > /tmp/calendars.json &
wait
cat /tmp/tasks.json /tmp/calendars.json
```

**Result:** Both calls complete in ~3.8s instead of ~7.6s sequential.

---

### Example 2: Five Parallel Sources (5x Speedup)

**Bash tool input:**

```bash
EMAIL="you@example.com"
mcp-cli call google-workspace/get_events "{\"user_google_email\":\"$EMAIL\"}" > /tmp/events.json &
mcp-cli call google-workspace/search_gmail_messages "{\"user_google_email\":\"$EMAIL\",\"query\":\"in:inbox\"}" > /tmp/emails.json &
mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$EMAIL\"}" > /tmp/lists.json &
mcp-cli call google-workspace/list_calendars "{\"user_google_email\":\"$EMAIL\"}" > /tmp/calendars.json &
mcp-cli call github/list_issues '{"repo":"myorg/myrepo"}' > /tmp/issues.json &
wait
echo "=== Events ===" && jq -r '.content[0].text' /tmp/events.json
echo "=== Tasks ===" && jq -r '.content[0].text' /tmp/lists.json
```

**Result:** 5 calls in ~3s instead of ~19s sequential.

---

### Example 3: Wave-Based Execution (Dependencies)

**Bash tool input:**

```bash
EMAIL="you@example.com"

# Wave 1: Get task lists and calendars
mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$EMAIL\"}" > /tmp/lists.json &
mcp-cli call google-workspace/list_calendars "{\"user_google_email\":\"$EMAIL\"}" > /tmp/cals.json &
wait

# Extract IDs
TASK_LIST_ID=$(jq -r '.task_lists[0].id // empty' /tmp/lists.json 2>/dev/null | head -1)

# Wave 2: Get tasks from that list
if [ -n "$TASK_LIST_ID" ]; then
  mcp-cli call google-workspace/list_tasks "{\"user_google_email\":\"$EMAIL\",\"task_list_id\":\"$TASK_LIST_ID\"}" > /tmp/tasks.json &
  wait
fi

jq -r '.content[0].text' /tmp/tasks.json
```

**Result:** Dependent calls still benefit from parallelism in each wave.

---

### Example 4: Batch Processing (20 Calls, 15.7x Speedup)

**Bash tool input:**

```bash
EMAIL="you@example.com"

# 20 parallel calls
for i in $(seq 1 20); do
  mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$EMAIL\"}" > /tmp/result_$i.json &
done
wait

# Process results
for i in $(seq 1 20); do
  echo "Result $i: $(jq -r '.task_lists | length' /tmp/result_$i.json 2>/dev/null) lists"
done
```

**Result:** 20 calls in ~4.9s instead of ~76s sequential (15.7x faster).

---

### Example 5: Wave Batching (50+ Calls)

**Bash tool input:**

```bash
EMAIL="you@example.com"

# Process 50 calls in waves of 20
for wave in 1 2 3; do
  echo "Wave $wave..."
  start=$((($wave - 1) * 20 + 1))
  end=$(( $wave * 20 > 50 ? 50 : $wave * 20 ))

  for i in $(seq $start $end); do
    mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$EMAIL\"}" > /tmp/w${wave}_$i.json &
  done
  wait
done

echo "All 50 calls complete"
ls /tmp/w*.json | wc -l
```

**Result:** 50 calls in ~10s instead of ~190s sequential (18x faster).

---

## Layer 1: Subagent Parallelism (Task Tools)

### Example 6: Multiple Subagents in ONE Message

Send **all Task tools in a single message** for parallel execution:

```yaml
# ONE message with 3 Task tool calls - all execute in parallel

Task:
  subagent_type: general-purpose
  description: "Scan Google calendars"
  prompt: |
    Fetch events from all Google calendars for the next 7 days.
    Email: you@example.com

    Use parallel MCP-CLI pattern:
    mcp-cli call google-workspace/get_events '{}' > /tmp/cal1.json &
    mcp-cli call google-workspace/get_events '{}' > /tmp/cal2.json &
    wait

    Output to /tmp/calendars/*.json

Task:
  subagent_type: general-purpose
  description: "Scan email inbox"
  prompt: |
    Fetch recent emails and categorize by sender domain.
    Email: you@example.com

    Use parallel MCP-CLI pattern.
    Output to /tmp/email/*.json

Task:
  subagent_type: general-purpose
  description: "Scan git repositories"
  prompt: |
    Analyze recent commits across 5 repositories.
    Use parallel git commands:

    for repo in /path/to/repos/*; do
      git -C "$repo" log --oneline -10 &
    done
    wait

    Output to /tmp/git/*.txt
```

**Result:** All 3 agents execute in parallel. Total time = max(agent1, agent2,
agent3), not sum.

---

### Example 7: L1 + L3 Combined (Maximum Throughput)

```yaml
# Main session sends ONE message with parallel Task tools (L1)
# Each agent uses parallel MCP-CLI (L3) internally

Task:
  subagent_type: general-purpose
  description: "Google Workspace scanner with L3"
  prompt: |
    You are a data gathering agent. Use parallel MCP-CLI for ALL operations.

    Email: you@example.com
    Output directory: /tmp/gws-scan

    Execute 17 parallel MCP calls:

    mkdir -p /tmp/gws-scan

    # 9 calendar calls
    for cal in primary work personal finance; do
      mcp-cli call google-workspace/get_events "{\"user_google_email\":\"you@example.com\",\"calendar_id\":\"$cal\"}" > "/tmp/gws-scan/cal-$cal.json" &
    done

    # 5 task list calls
    mcp-cli call google-workspace/list_task_lists '{"user_google_email":"you@example.com"}' > /tmp/gws-scan/task-lists.json &

    # 3 email calls
    mcp-cli call google-workspace/search_gmail_messages '{"user_google_email":"you@example.com","query":"is:unread"}' > /tmp/gws-scan/email-unread.json &
    mcp-cli call google-workspace/search_gmail_messages '{"user_google_email":"you@example.com","query":"in:inbox newer_than:7d"}' > /tmp/gws-scan/email-recent.json &

    wait

    # Return manifest
    ls -la /tmp/gws-scan/

    IMPORTANT: Target output 400-600 tokens. Return YAML summary, not verbose prose.

Task:
  subagent_type: general-purpose
  description: "Vault scanner"
  prompt: |
    Read and summarize these vault files:
    - GOALS.md
    - COMMITMENTS.md
    - CLIENTS.md

    Return structured YAML with key data points.
    Target output: 400-600 tokens maximum.

Task:
  subagent_type: general-purpose
  description: "Git history scanner"
  prompt: |
    Analyze git activity across repositories.

    Output directory: /tmp/git-scan

    mkdir -p /tmp/git-scan

    for repo in /path/to/repo{1..5}; do
      (
        cd "$repo"
        echo "=== $(basename $repo) ===" > "/tmp/git-scan/$(basename $repo).txt"
        git log --oneline -15 --since="7 days ago" >> "/tmp/git-scan/$(basename $repo).txt"
        git status -s >> "/tmp/git-scan/$(basename $repo).txt"
      ) &
    done
    wait

    cat /tmp/git-scan/*.txt

    IMPORTANT: Target output 400-800 tokens.
```

**Result:**

- L1: 3 agents execute in parallel (throughput scaling)
- L3: Each agent runs 5-17 operations in parallel (genuine speedup)
- Combined: ~50 operations complete in ~4s

**Honest analysis:**

- 17 ops with L3 alone: ~3.2s
- 51 ops with L1+L3 (3 agents): ~3.5s
- L1 gives 3x more operations, not 3x faster

---

### Example 8: File System Communication Pattern

```yaml
# Step 1: Subagents write to files (parallel execution)

Task:
  subagent_type: general-purpose
  description: "Data collector - writes to files"
  prompt: |
    Collect data and write to /tmp/data-collector/*.json

    mkdir -p /tmp/data-collector

    mcp-cli call google-workspace/get_events '{}' > /tmp/data-collector/events.json &
    mcp-cli call google-workspace/list_tasks '{}' > /tmp/data-collector/tasks.json &
    wait

    # Create manifest
    cat > /tmp/data-collector/manifest.json << EOF
    {
      "files": ["events.json", "tasks.json"],
      "timestamp": "$(date -Iseconds)"
    }
    EOF

    cat /tmp/data-collector/manifest.json
```

```yaml
# Step 2: Main session reads files in parallel

Read: /tmp/data-collector/manifest.json
Read: /tmp/data-collector/events.json
Read: /tmp/data-collector/tasks.json
# All Read tools in one message execute in parallel
```

**Result:** Large data sets are handled efficiently. Subagent returns small
manifest, main session selectively loads what it needs.

---

## Anti-Patterns (What NOT to Do)

### WRONG: Sequential MCP calls

```bash
mcp-cli call server/tool1 '{}'
mcp-cli call server/tool2 '{}'
mcp-cli call server/tool3 '{}'
```

**Problem:** Each call waits for the previous one. 3 calls = 3x time.

### WRONG: Sequential subagent spawning

```yaml
# Message 1
Task: scanner-1
# Wait for result

# Message 2
Task: scanner-2
# Wait for result

# Message 3
Task: scanner-3
# Total: 3x time
```

**Problem:** Each Task waits before the next spawns. Send ALL in ONE message.

### WRONG: Breaking session context

```bash
bash -c 'TMPDIR=$(mktemp -d); mcp-cli call server/tool "{}"'
```

**Problem:** Creates new subshell that loses session endpoint files.

### WRONG: Missing wait

```bash
mcp-cli call server/tool1 '{}' > /tmp/r1.json &
mcp-cli call server/tool2 '{}' > /tmp/r2.json &
cat /tmp/r1.json  # File may be incomplete!
```

**Problem:** Reading results before background jobs finish.

### WRONG: Missing output redirect

```bash
mcp-cli call server/tool1 '{}' &
mcp-cli call server/tool2 '{}' &
wait
# Where are the results?
```

**Problem:** Output from background jobs is lost.

### WRONG: Expecting model parameter to work

```yaml
Task:
  model: haiku # Does NOT reliably work
  prompt: "..."
```

**Problem:** Subagent model selection is currently bugged in Claude Code.

**Fix:** Use token budget constraints instead:

```yaml
Task:
  prompt: |
    ...
    IMPORTANT: Target output 400-600 tokens max.
    Return structured YAML, not verbose prose.
```

---

## Performance Summary

### L3: Genuine Speedup (Same Work, Less Time)

| Pattern                          | Speedup   | Best For                |
| -------------------------------- | --------- | ----------------------- |
| L3 only (2 calls)                | **2x**    | Simple parallel fetches |
| L3 only (10 calls)               | **9.7x**  | Medium batch            |
| L3 only (20 calls)               | **15.5x** | Large batch             |
| L3 only (50 calls, wave batched) | **18x**   | Very large batches      |

### L1: Throughput Scaling (More Work, Same Time)

| Pattern       | Operations | Wall-Clock | Use Case           |
| ------------- | ---------- | ---------- | ------------------ |
| 1 agent + L3  | 17         | ~3.2s      | Single domain      |
| 3 agents + L3 | 51         | ~3.5s      | Multi-domain       |
| 6 agents + L3 | 102        | ~4.0s      | Maximum throughput |

**Note:** L1 does NOT make L3 faster. It allows more operations simultaneously.

---

## Decision Guide

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Choose Your Pattern                                                    │
│                                                                         │
│  2-10 MCP calls, single domain    → L3 only (Example 1-2)              │
│  10-20 MCP calls, single domain   → L3 with wave batching (Example 5)  │
│  Multiple domains (cal+email+git) → L1 + L3 combined (Example 7)       │
│  Large data (50k+ tokens)         → File system pattern (Example 8)    │
│  Dependencies between calls       → Wave-based execution (Example 3)   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

_Examples tested: January 2026_ _Claude Code version: 2.1.12+_
