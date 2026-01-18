# MCP Parallel Orchestration

> Installed by [claude-code-mcp-cli-parallel-godmode](https://github.com/yourusername/claude-code-mcp-cli-parallel-godmode)

## MCP Tool Orchestration

**CRITICAL: When making 3+ MCP tool calls, use parallel bash orchestration.**

### Three Layers of Parallelization

1. **Layer 1 (Within Bash):** Use background jobs (`&`) and `wait` in a single Bash call
2. **Layer 2 (Multiple Bash calls):** Issue parallel Bash tool calls in a single message
3. **Layer 3 (Subagents):** Spawn parallel Task agents for complex workflows

### Pattern

1. Identify independent calls (can run simultaneously)
2. Identify dependent calls (need results from earlier calls)
3. Execute in waves using background jobs and synchronization

### Example: Single Bash Call with Parallel MCP Operations

```bash
# Wave 1: Independent calls
mcp-cli call google-workspace/get_events '{"user_google_email":"..."}' > /tmp/events.json &
mcp-cli call google-workspace/list_tasks '{"user_google_email":"..."}' > /tmp/tasks.json &
mcp-cli call google-workspace/search_gmail_messages '{"user_google_email":"..."}' > /tmp/emails.json &
wait

# Extract values for dependent calls
TASK_ID=$(jq -r '.task_lists[0].id' /tmp/tasks.json)

# Wave 2: Dependent calls
mcp-cli call google-workspace/get_task '{"task_id":"'"$TASK_ID"'"}' > /tmp/task.json &
wait

# Output results
jq -r '.content[0].text' /tmp/events.json
```

### What NOT to Do

```bash
# WRONG: Creates new temp directory, loses session context
bash -c 'TMPDIR=$(mktemp -d); mcp-cli call ...'

# WRONG: Sequential calls when they could be parallel
mcp-cli call server/tool1 '{}'
mcp-cli call server/tool2 '{}'
mcp-cli call server/tool3 '{}'
```

### When to Use Each Layer

| Scenario | Layer(s) |
|----------|----------|
| 3+ related MCP calls | Layer 1 |
| Independent data sources | Layer 1 + 2 |
| Complex multi-domain workflows | Layer 1 + 2 + 3 |
| 1-2 simple calls | Sequential is fine |

### Prerequisites

This pattern requires:
```bash
export ENABLE_EXPERIMENTAL_MCP_CLI=true
```

### Verified Performance

| Pattern | Total Calls | Time | Throughput |
|---------|-------------|------|------------|
| Sequential | 1 | 2.28s | 0.44 calls/s |
| **Parallel 1×10** | 10 | 3.01s | 3.32 calls/s |
| **Parallel 1×20** | 20 | 4.52s | 4.42 calls/s |

**10x throughput increase** — 46s workflows complete in 4.5s

---

*Configuration installed from claude-code-mcp-cli-parallel-godmode*
