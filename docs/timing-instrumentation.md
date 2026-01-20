# Timing Instrumentation Guide

This document describes how to capture accurate end-to-end timing for workflows
that use MCP parallelization, to properly measure what this toolkit optimizes.

---

## The Measurement Problem

When evaluating MCP parallelization, there's a critical distinction:

| Metric | What It Measures | Typical Time |
|--------|------------------|--------------|
| **MCP layer time** | Just MCP-CLI operations | ~9s (parallelized) |
| **End-to-end time** | Complete workflow | 90-180s |

Claiming "9 seconds" for a workflow that takes 2-3 minutes is misleading. This
guide helps you measure both accurately.

---

## Recommended Timing Schema

### Per-Operation Timing

```json
{
  "workflow_id": "briefing-2026-01-20-1300",
  "phases": [
    {
      "name": "mcp_wave_1",
      "start_ts": "2026-01-20T13:00:01.234Z",
      "end_ts": "2026-01-20T13:00:04.567Z",
      "duration_ms": 3333,
      "operations": [
        {"type": "mcp", "server": "google-workspace", "tool": "list_calendars", "duration_ms": 2100},
        {"type": "mcp", "server": "google-workspace", "tool": "list_task_lists", "duration_ms": 1800},
        {"type": "read", "file": "GOALS.md", "duration_ms": 45}
      ]
    },
    {
      "name": "mcp_wave_2",
      "start_ts": "2026-01-20T13:00:04.567Z",
      "end_ts": "2026-01-20T13:00:10.890Z",
      "duration_ms": 6323,
      "operations": [
        {"type": "mcp", "server": "google-workspace", "tool": "get_events", "count": 9, "duration_ms": 5200},
        {"type": "mcp", "server": "google-workspace", "tool": "list_tasks", "count": 5, "duration_ms": 4100}
      ]
    },
    {
      "name": "subagent_orchestration",
      "start_ts": "2026-01-20T13:00:10.890Z",
      "end_ts": "2026-01-20T13:00:35.123Z",
      "duration_ms": 24233,
      "subagents": [
        {"name": "vault-scanner", "startup_ms": 2800, "execution_ms": 5200},
        {"name": "calendar-scanner", "startup_ms": 2600, "execution_ms": 3100},
        {"name": "email-scanner", "startup_ms": 2900, "execution_ms": 4500},
        {"name": "tasks-scanner", "startup_ms": 2500, "execution_ms": 2800},
        {"name": "historical-memory-scanner", "startup_ms": 2700, "execution_ms": 3200},
        {"name": "historical-git-scanner", "startup_ms": 3100, "execution_ms": 48000}
      ]
    },
    {
      "name": "synthesis",
      "start_ts": "2026-01-20T13:01:35.123Z",
      "end_ts": "2026-01-20T13:02:10.456Z",
      "duration_ms": 35333,
      "tokens_processed": 32000
    }
  ],
  "totals": {
    "mcp_layer_ms": 9656,
    "subagent_overhead_ms": 24233,
    "synthesis_ms": 35333,
    "end_to_end_ms": 129222
  }
}
```

---

## Implementation Patterns

### Pattern 1: Bash Timing Wrapper

Add timing to MCP calls:

```bash
# Capture start time
START=$(date +%s%3N)

# Parallel MCP operations
mcp-cli call google-workspace/get_events '{}' > /tmp/r1.json &
mcp-cli call google-workspace/list_tasks '{}' > /tmp/r2.json &
wait

# Capture end time and log
END=$(date +%s%3N)
DURATION=$((END - START))
echo "{\"phase\": \"mcp_wave_1\", \"duration_ms\": $DURATION}" >> /tmp/timing.jsonl
```

### Pattern 2: Session Metrics Parser Enhancement

Add to `~/.claude/scripts/metrics/session-metrics-parser.py`:

```python
def extract_timing(session_data):
    """Extract per-phase timing from session transcript."""
    phases = []
    current_phase = None

    for entry in session_data:
        if entry.get("role") == "assistant":
            # Detect phase transitions
            content = str(entry.get("content", ""))
            if "Task tool" in content and "subagent_type" in content:
                # Subagent spawn detected
                if current_phase:
                    phases.append(current_phase)
                current_phase = {
                    "name": "subagent",
                    "start_ts": entry.get("timestamp"),
                    "operations": []
                }
            elif "mcp-cli" in content:
                # MCP operation detected
                if not current_phase or current_phase["name"] != "mcp":
                    if current_phase:
                        phases.append(current_phase)
                    current_phase = {
                        "name": "mcp",
                        "start_ts": entry.get("timestamp"),
                        "operations": []
                    }

    return phases
```

### Pattern 3: Hook-Based Timing

Add a timing hook to capture tool execution:

```json
// hooks.json
{
  "hooks": [
    {
      "matcher": {
        "tool_name": "Bash"
      },
      "hooks": [
        {
          "type": "postToolExecution",
          "command": "~/.claude/hooks/timing-logger.sh"
        }
      ]
    }
  ]
}
```

```bash
#!/bin/bash
# timing-logger.sh
echo "{\"tool\": \"Bash\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)\"}" >> /tmp/tool-timing.jsonl
```

---

## Metrics to Capture

### Essential Metrics

| Metric | How to Measure | Why It Matters |
|--------|----------------|----------------|
| MCP layer time | Sum of MCP wave durations | What this toolkit optimizes |
| Subagent overhead | Count × startup latency | Architectural limitation |
| Git analysis time | historical-git-scanner execution | Often the longest phase |
| Synthesis time | Token count × processing rate | LLM-bound, not parallelizable |

### Derived Metrics

| Metric | Formula | Interpretation |
|--------|---------|----------------|
| MCP efficiency | parallel_time / sequential_time | Should be <0.20 (5x+ speedup) |
| Subagent ratio | subagent_time / total_time | If >50%, consider direct MCP |
| Parallelization coverage | mcp_layer_time / total_time | Percentage this toolkit impacts |

---

## Validation Checklist

Before reporting performance claims:

- [ ] **Clarify scope**: Is this MCP-only or end-to-end?
- [ ] **Measure all layers**: MCP, subagents, git, synthesis
- [ ] **Count operations**: How many MCP calls, file reads, git commands?
- [ ] **Note architectural limits**: What CAN'T be parallelized?
- [ ] **Include overhead**: Subagent startup, token processing

---

## Example Report

```markdown
## Briefing Performance Analysis

### MCP Layer (Optimized)
- Operations: 25 MCP calls + 6 file reads
- Sequential time: ~60s
- Parallel time: ~9s
- **Speedup: 6.7x**

### Other Layers (Not Optimized)
- Subagent orchestration: 24s (6 agents × 4s each)
- Historical git analysis: 45s (25 repos × 1.8s each)
- Synthesis: 35s (32k tokens)
- **Additional time: 104s**

### End-to-End
- Total time: 113s (~2 minutes)
- Time saved by MCP parallelization: ~50s
- **Net improvement: ~1.5x faster**
```

---

## Integration with Existing Metrics

The session metrics parser at `~/.claude/scripts/metrics/session-metrics-parser.py`
already tracks:

- Total tool calls by type
- Parallelization adoption (L1 subagent and L3 MCP-CLI)
- Session durations

**Recommended enhancement:** Add per-phase timing extraction to correlate with
the parallelization metrics.

---

_Document created: January 20, 2026_
_Part of the MCP Parallel Orchestration toolkit_
