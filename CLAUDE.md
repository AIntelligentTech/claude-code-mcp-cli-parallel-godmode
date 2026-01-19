# MCP Parallel Orchestration

**MANDATORY: Use parallel orchestration for ALL mcp-cli operations (2+ calls).**

This applies to **both** `mcp-cli info` and `mcp-cli call` commands.

See `.claude/rules/mcp-parallel.md` for complete enforcement rules.

## Quick Reference

```bash
# REQUIRED pattern - parallel execution (even for just 2 calls)
mcp-cli info server/tool1 > /tmp/i1.json &
mcp-cli info server/tool2 > /tmp/i2.json &
wait
# Then make calls in parallel
mcp-cli call server/tool1 '{}' > /tmp/r1.json &
mcp-cli call server/tool2 '{}' > /tmp/r2.json &
wait

# FORBIDDEN - sequential execution wastes 50%+ of time
mcp-cli info server/tool1
mcp-cli info server/tool2
mcp-cli call server/tool1 '{}'
mcp-cli call server/tool2 '{}'
```

## Critical Rules

1. **Always parallelize** 2+ MCP operations using `&` and `wait`
2. **Include `mcp-cli info`** — schema checks are MCP operations too
3. **Batch aggressively** — aim for 20-25 parallel calls per Bash invocation
4. **Use Level 2 parallelization** — multiple parallel Bash tool calls when possible
5. **Never use `bash -c`** with mcp-cli (breaks session context)
6. **Always redirect output** to temp files (`> /tmp/result.json`)
7. **Always end with `wait`** before processing results

## Subagent Guidance

When spawning subagents that will make MCP calls:
- **Pre-batch schemas** — gather all `mcp-cli info` in the parent session before spawning
- **Pass schemas to subagents** — include required schemas in the subagent prompt
- **Avoid context thrashing** — don't spawn many small subagents; batch work in fewer agents
- **Subagents should parallelize too** — include these rules in subagent prompts

## Performance

| Calls | Sequential | Parallel | Speedup |
|-------|------------|----------|---------|
| 2 | 7.6s | 3.8s | **2x** |
| 10 | 38s | 3.0s | **12.8x** |
| 20 | 76s | 4.9s | **15.7x** |
| 50 | 191s | 10.3s | **18.6x** |

## Prerequisite

```bash
export ENABLE_EXPERIMENTAL_MCP_CLI=true
```

---

*Installed by [claude-code-mcp-cli-parallel-godmode](https://github.com/AIntelligentTech/claude-code-mcp-cli-parallel-godmode)*
