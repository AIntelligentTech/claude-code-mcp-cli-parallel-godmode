# MCP Parallel Orchestration Rules

**MANDATORY: All mcp-cli operations with 2+ calls MUST use parallel orchestration patterns.**

This applies to **both** `mcp-cli info` (schema checks) and `mcp-cli call` (tool invocations).

## Rule: Never Sequential MCP Operations

When making 2+ MCP operations (info OR call), you MUST use parallel bash orchestration. Sequential operations are PROHIBITED.

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

## Rule: Batch Aggressively (20-25 calls per wave)

Before every Bash tool call, assess how many independent MCP operations can be batched together.

**Target:** 20-25 parallel MCP operations per Bash invocation. For larger batches (50-100+), use wave batching.

```bash
# Good: 20 schema checks in one Bash call
mcp-cli info google-workspace/get_events > /tmp/i1.json &
mcp-cli info google-workspace/search_gmail_messages > /tmp/i2.json &
mcp-cli info google-workspace/list_task_lists > /tmp/i3.json &
# ... continue for all independent schemas
mcp-cli info github/list_issues > /tmp/i20.json &
wait
```

## Rule: Level 2 Parallelization

Claude Code can invoke multiple Bash tools in parallel. Combine this with Level 1 (parallel calls within each Bash) for multiplicative effect.

```bash
# Bash call 1 (runs in parallel with Bash call 2)
mcp-cli call google-workspace/get_events '{"calendar_id":"cal1"}' > /tmp/cal1.json &
mcp-cli call google-workspace/get_events '{"calendar_id":"cal2"}' > /tmp/cal2.json &
# ... 20 more
wait
```

```bash
# Bash call 2 (runs in parallel with Bash call 1)
mcp-cli call github/list_issues '{"repo":"repo1"}' > /tmp/gh1.json &
mcp-cli call github/list_issues '{"repo":"repo2"}' > /tmp/gh2.json &
# ... 20 more
wait
```

**Result:** 40+ MCP calls execute in the time of ~1 sequential call.

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

## Rule: Subagent Best Practices

When spawning subagents that will make MCP calls:

### Pre-batch Schemas in Parent Session

```bash
# In parent session: gather all schemas subagents will need
mcp-cli info google-workspace/get_events > /tmp/schema_events.json &
mcp-cli info google-workspace/search_gmail_messages > /tmp/schema_gmail.json &
mcp-cli info google-workspace/list_tasks > /tmp/schema_tasks.json &
wait

# Pass schemas to subagent prompt
SCHEMAS=$(cat /tmp/schema_*.json | jq -s '.')
```

### Avoid Context Thrashing

- **Don't spawn many small subagents** — each spawn has overhead
- **Batch work into fewer subagents** — give each agent substantial work
- **Pre-fetch data in parent** — reduce redundant MCP calls across agents
- **Use haiku for exploration** — reserve opus/sonnet for complex reasoning

### Include Parallelization Rules in Subagent Prompts

When spawning subagents, explicitly include:
```
IMPORTANT: Use parallel MCP orchestration. Batch all mcp-cli calls using:
mcp-cli call ... > /tmp/r1.json &
mcp-cli call ... > /tmp/r2.json &
wait
```

## Rule: Wave Batching for Very Large Operations

For 100+ calls, batch into waves of 50-75 to balance throughput and resource usage:

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

## Rule: Never Break Session Context

Background jobs (`&`) inherit session context. The following patterns BREAK context:

```bash
# FORBIDDEN - loses session context
bash -c 'TMPDIR=$(mktemp -d); mcp-cli call ...'
bash -c 'cd /tmp && mcp-cli call ...'

# CORRECT - preserves session context
mcp-cli call server/tool '{}' > /tmp/result.json &
wait
```

## Rule: Always Use `wait`

Every parallel batch MUST end with `wait` to ensure completion before processing results.

```bash
mcp-cli info ... > /tmp/i1.json &
mcp-cli call ... > /tmp/r1.json &
mcp-cli call ... > /tmp/r2.json &
wait  # MANDATORY - ensures all operations complete

# Now safe to read results
cat /tmp/r1.json
```

## Rule: Redirect Output to Temp Files

Parallel operations MUST redirect output to capture results.

```bash
# CORRECT - output captured
mcp-cli call server/tool '{}' > /tmp/result.json &

# WRONG - output lost in background
mcp-cli call server/tool '{}' &
```

## Performance Expectations

| Configuration | Expected Speedup |
|---------------|------------------|
| 2 operations | **2x faster** |
| 3-10 operations | 6-13x faster |
| 10-20 operations | 13-16x faster |
| 20-50 operations | 15-18x faster |
| 50-100 operations | 18-20x faster |

Failure to use parallel orchestration wastes up to 95% of execution time.

## Exceptions

Sequential operations are acceptable ONLY when:
1. Making exactly 1 MCP operation
2. Debugging a specific operation in isolation
3. Explicitly requested by user

**For 2+ operations, parallel orchestration is MANDATORY.**
