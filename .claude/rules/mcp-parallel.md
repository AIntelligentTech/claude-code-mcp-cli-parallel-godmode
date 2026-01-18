# MCP Parallel Orchestration Rules

**MANDATORY: All mcp-cli operations with 2+ calls MUST use parallel orchestration patterns.**

## Rule: Never Sequential MCP Calls

When making 2+ MCP tool calls, you MUST use parallel bash orchestration. Sequential calls are PROHIBITED.

### FORBIDDEN Pattern

```bash
# NEVER DO THIS - sequential calls waste 50%+ of time (even for just 2 calls)
mcp-cli call server/tool1 '{}'
mcp-cli call server/tool2 '{}'
```

### REQUIRED Pattern

```bash
# ALWAYS DO THIS - parallel calls with background jobs (even for 2 calls)
mcp-cli call server/tool1 '{}' > /tmp/r1.json &
mcp-cli call server/tool2 '{}' > /tmp/r2.json &
wait

# Then process results
cat /tmp/r1.json
```

## Rule: Wave-Based Execution for Dependencies

When calls depend on earlier results, use wave-based execution.

```bash
# Wave 1: Independent calls
mcp-cli call server/list_items '{}' > /tmp/items.json &
mcp-cli call server/get_config '{}' > /tmp/config.json &
wait

# Extract dependent value
ITEM_ID=$(jq -r '.items[0].id' /tmp/items.json)

# Wave 2: Dependent calls
mcp-cli call server/get_item "{\"id\":\"$ITEM_ID\"}" > /tmp/item.json &
mcp-cli call server/get_history "{\"id\":\"$ITEM_ID\"}" > /tmp/history.json &
wait
```

## Rule: Wave Batching for Large Operations

For 50+ calls, batch into waves of 20-25 to avoid resource exhaustion.

```bash
# Process 60 calls in 3 waves
for wave in 1 2 3; do
  start=$((($wave - 1) * 20 + 1))
  end=$(($wave * 20))
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
mcp-cli call ... > /tmp/r1.json &
mcp-cli call ... > /tmp/r2.json &
wait  # MANDATORY - ensures all calls complete

# Now safe to read results
cat /tmp/r1.json
```

## Rule: Redirect Output to Temp Files

Parallel calls MUST redirect output to capture results.

```bash
# CORRECT - output captured
mcp-cli call server/tool '{}' > /tmp/result.json &

# WRONG - output lost in background
mcp-cli call server/tool '{}' &
```

## Performance Expectations

| Configuration | Expected Speedup |
|---------------|------------------|
| 2 calls | **2x faster** |
| 3-10 calls | 6-13x faster |
| 10-20 calls | 13-16x faster |
| 20-50 calls | 15-18x faster |

Failure to use parallel orchestration wastes up to 95% of execution time.

## Exceptions

Sequential calls are acceptable ONLY when:
1. Making exactly 1 MCP call
2. Debugging a specific call in isolation
3. Explicitly requested by user

**For 2+ calls, parallel orchestration is MANDATORY.**
