# Bash Tool Call Examples

These examples show how Claude Code uses the Bash tool for parallel MCP orchestration.

## Example 1: Two Parallel Calls (2x Speedup)

**Bash tool input:**
```bash
mcp-cli call google-workspace/list_task_lists '{"user_google_email":"you@example.com"}' > /tmp/tasks.json &
mcp-cli call google-workspace/list_calendars '{"user_google_email":"you@example.com"}' > /tmp/calendars.json &
wait
cat /tmp/tasks.json /tmp/calendars.json
```

**Result:** Both calls complete in ~3.8s instead of ~7.6s sequential.

---

## Example 2: Daily Briefing (5 Parallel Sources)

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

## Example 3: Wave-Based Execution (Dependencies)

**Bash tool input:**
```bash
EMAIL="you@example.com"

# Wave 1: Get task lists
mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$EMAIL\"}" > /tmp/lists.json &
mcp-cli call google-workspace/list_calendars "{\"user_google_email\":\"$EMAIL\"}" > /tmp/cals.json &
wait

# Extract task list ID
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

## Example 4: Batch Processing (20 Calls)

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

## Example 5: Wave Batching (50+ Calls)

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

## Anti-Patterns (What NOT to Do)

### WRONG: Sequential calls
```bash
mcp-cli call server/tool1 '{}'
mcp-cli call server/tool2 '{}'
mcp-cli call server/tool3 '{}'
```
**Problem:** Each call waits for the previous one. 3 calls = 3x time.

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
