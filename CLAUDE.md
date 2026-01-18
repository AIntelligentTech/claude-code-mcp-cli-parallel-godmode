# MCP Parallel Orchestration

**MANDATORY: Use parallel orchestration for all mcp-cli operations (3+ calls).**

See `.claude/rules/mcp-parallel.md` for complete enforcement rules.

## Quick Reference

```bash
# REQUIRED pattern - parallel execution
mcp-cli call server/tool1 '{}' > /tmp/r1.json &
mcp-cli call server/tool2 '{}' > /tmp/r2.json &
mcp-cli call server/tool3 '{}' > /tmp/r3.json &
wait

# FORBIDDEN - sequential execution wastes 94% of time
mcp-cli call server/tool1 '{}'
mcp-cli call server/tool2 '{}'
```

## Critical Rules

1. **Always parallelize** 3+ MCP calls using `&` and `wait`
2. **Never use `bash -c`** with mcp-cli (breaks session context)
3. **Always redirect output** to temp files (`> /tmp/result.json`)
4. **Always end with `wait`** before processing results
5. **Wave batch 50+ calls** into groups of 20-25

## Performance

| Calls | Sequential | Parallel | Speedup |
|-------|------------|----------|---------|
| 20 | 76s | 4.9s | **15.7x** |
| 50 | 191s | 10.3s | **18.6x** |

## Prerequisite

```bash
export ENABLE_EXPERIMENTAL_MCP_CLI=true
```

---

*Installed by [claude-code-mcp-cli-parallel-godmode](https://github.com/yourusername/claude-code-mcp-cli-parallel-godmode)*
