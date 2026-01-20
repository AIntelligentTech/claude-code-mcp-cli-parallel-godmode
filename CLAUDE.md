# MCP Parallel Orchestration — Three-Layer Architecture

**MANDATORY: Use parallel orchestration for ALL mcp-cli operations (2+ calls).**

This applies to **both** `mcp-cli info` and `mcp-cli call` commands.

See `.claude/rules/mcp-parallel.md` for complete enforcement rules.

---

## What This Provides

**L3 (MCP-CLI Parallelism):** Genuine 2x-18x speedup for batch operations.

**L1 (Subagent Parallelism):** Horizontal throughput scaling (~6x more work at
similar latency). NOT additional speedup for fixed operations.

---

## Quick Reference

```bash
# REQUIRED pattern (even for 2 calls)
mcp-cli call server/tool1 '{}' > /tmp/r1.json &
mcp-cli call server/tool2 '{}' > /tmp/r2.json &
wait

# FORBIDDEN - sequential calls waste time
mcp-cli call server/tool1 '{}'
mcp-cli call server/tool2 '{}'
```

---

## Three-Layer Architecture

```
Layer 1: SUBAGENT PARALLELISM
═════════════════════════════
Multiple Task tools in ONE message execute concurrently
Effect: Throughput scaling (more operations simultaneously)
NOT speedup for fixed work

Layer 2: TOOL CALL PARALLELISM (NOT IMPLEMENTED)
════════════════════════════════════════════════
Claude API supports this, but Claude Code doesn't use it

Layer 3: MCP-CLI PARALLELISM
════════════════════════════
Background jobs: mcp-cli ... &
Effect: Genuine speedup (2x-18x for same operations)
THIS IS THE PRIMARY VALUE
```

---

## Performance (Honest Numbers)

### L3 Speedup (Same Work, Less Time)

| Calls | Speedup   |
| ----- | --------- |
| 2     | **2x**    |
| 10    | **9.7x**  |
| 20    | **15.5x** |
| 50    | **18x**   |

### L1 Throughput (More Work, Same Time)

| Configuration            | Operations | Wall-Clock |
| ------------------------ | ---------- | ---------- |
| 1 agent, 17 L3 ops       | 17         | ~3.2s      |
| 6 agents, 17 L3 ops each | 102        | ~4.0s      |

L1 does NOT make L3 faster. It allows more operations simultaneously.

---

## Key Patterns

### L3: Parallel MCP-CLI

```bash
mcp-cli call google-workspace/get_events '{}' > /tmp/events.json &
mcp-cli call google-workspace/list_tasks '{}' > /tmp/tasks.json &
wait
cat /tmp/events.json /tmp/tasks.json
```

### L1 + L3: Throughput Scaling

```yaml
# ONE message, multiple Task tools (L1)
# Each agent uses parallel MCP-CLI (L3)

Task:
  subagent_type: general-purpose
  prompt: |
    Fetch calendar data with parallel MCP-CLI.
    mcp-cli call ... > /tmp/cal.json &
    mcp-cli call ... > /tmp/tasks.json &
    wait
    Target output: 400-600 tokens.

Task:
  subagent_type: general-purpose
  prompt: |
    Fetch email data with parallel MCP-CLI.
    ...
```

---

## Known Bug: Subagent Model Selection

Setting `model: haiku` in Task tool doesn't reliably work.

**Workaround:** Use token budget in prompts:

```yaml
Task:
  prompt: |
    ...
    IMPORTANT: Target output 400-600 tokens max.
    Return structured YAML, not verbose prose.
```

---

## Required Elements

| Element            | Purpose              |
| ------------------ | -------------------- |
| `&`                | Run in background    |
| `> /tmp/file.json` | Capture output       |
| `wait`             | Block until complete |

---

## Anti-Patterns

| Pattern                 | Problem                       |
| ----------------------- | ----------------------------- |
| Sequential MCP calls    | Wastes 2x-18x time            |
| Missing `wait`          | Results incomplete            |
| Missing output redirect | Results lost                  |
| `bash -c` with mcp-cli  | Loses session context         |
| Claiming L1 = speedup   | L1 is throughput, not speedup |

---

_Installed by
[claude-code-mcp-cli-parallel-godmode](https://github.com/AIntelligentTech/claude-code-mcp-cli-parallel-godmode)_
_January 2026_
