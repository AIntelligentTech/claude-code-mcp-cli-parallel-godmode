# Claude Code MCP Parallel Orchestration

> Reduce MCP call latency by 4x through parallel bash orchestration.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-2.1.12+-blue.svg)](https://claude.ai/claude-code)

**Verified benchmark:** 5 MCP calls — Sequential: 5.93s → Parallel: 1.39s = **4.25x faster**

---

## What This Does

When Claude Code needs data from multiple MCP sources (calendar, tasks, email, GitHub), it typically runs calls **sequentially**. Each call takes ~1.2 seconds, so 5 calls = 6 seconds of waiting.

This toolkit makes Claude Code run multiple `mcp-cli` calls **in parallel** using shell background jobs:

```bash
# Instead of 5 sequential calls (6 seconds)...
mcp-cli call google-workspace/get_events '{}'      # 1.2s
mcp-cli call google-workspace/list_tasks '{}'      # 1.2s
mcp-cli call google-workspace/search_gmail '{}'    # 1.2s
# ... total: ~6 seconds

# Run them in parallel (1.4 seconds)
mcp-cli call google-workspace/get_events '{}' > /tmp/events.json &
mcp-cli call google-workspace/list_tasks '{}' > /tmp/tasks.json &
mcp-cli call google-workspace/search_gmail '{}' > /tmp/emails.json &
wait  # All 3 complete in ~1.2s total
```

---

## What This Is (and Isn't)

### This IS:
- **A latency optimization** — 4x faster MCP data gathering
- **Fewer model turns** — One bash command instead of N separate tool calls
- **Practical for data-heavy workflows** — Daily briefings, multi-source queries

### This is NOT:
- **Anthropic's 98.7% token reduction** — That comes from on-demand tool loading and local data filtering (see [their blog post](https://www.anthropic.com/engineering/code-execution-with-mcp))
- **A context window optimizer** — Results still return to model context
- **Filesystem-based code execution** — We use inline bash, not written code files

**Honest comparison:**

| Metric | Sequential (5 calls) | Parallel (1 bash) | Savings |
|--------|---------------------|-------------------|---------|
| **Latency** | 5.93s | 1.39s | **4.25x faster** |
| **Model turns** | 5 | 1 | 5x fewer |
| **Model output tokens** | ~500 (5 decisions) | ~300 (1 script) | ~40% less |
| **Result tokens** | ~2500 | ~2500 | None |
| **Tool definitions** | All loaded | All loaded | None |

**Primary benefit: Speed.** The efficiency gains are modest (fewer model turns, slightly less output).

---

## Quick Start

### Prerequisites

```bash
# Enable experimental mcp-cli (required)
export ENABLE_EXPERIMENTAL_MCP_CLI=true

# Add to shell profile (~/.zshrc or ~/.bashrc) for persistence
echo 'export ENABLE_EXPERIMENTAL_MCP_CLI=true' >> ~/.zshrc
```

### Installation

**Option A: User-Level (All Projects)**
```bash
git clone https://github.com/yourusername/claude-code-mcp-codegen-godmode.git
cd claude-code-mcp-codegen-godmode
./install.sh --user
```

**Option B: Project-Level (Single Project)**
```bash
git clone https://github.com/yourusername/claude-code-mcp-codegen-godmode.git /tmp/mcp-parallel
/tmp/mcp-parallel/install.sh --project /path/to/your/project
```

**Option C: Manual**
```bash
# Copy CLAUDE.md to your project or ~/.claude/
cp CLAUDE.md ~/.claude/CLAUDE.md

# Copy hooks (optional enforcement)
cp -r .claude/hooks ~/.claude/hooks
```

---

## How It Works

### The Pattern

Claude Code receives CLAUDE.md instructions to use parallel bash orchestration:

```bash
# Wave 1: Independent calls run in parallel
mcp-cli call server/tool1 '{}' > /tmp/result1.json &
mcp-cli call server/tool2 '{}' > /tmp/result2.json &
mcp-cli call server/tool3 '{}' > /tmp/result3.json &
wait  # Synchronization point

# Extract values if needed for dependent calls
VALUE=$(jq -r '.data.id' /tmp/result1.json)

# Wave 2: Dependent calls (also parallel)
mcp-cli call server/tool4 "{\"id\":\"$VALUE\"}" > /tmp/result4.json &
mcp-cli call server/tool5 "{\"id\":\"$VALUE\"}" > /tmp/result5.json &
wait

# Process results
jq -r '.content[0].text' /tmp/result1.json
```

### Why Background Jobs Work

Background jobs (`&`) inherit the parent shell's environment, including Claude Code's session context. The `mcp-cli` command needs access to session endpoint files — background jobs preserve this access.

**What breaks:**
```bash
# WRONG: New subshell loses session context
bash -c 'TMPDIR=$(mktemp -d); mcp-cli call ...'
# Error: "MCP endpoint file not found"
```

### Three Layers of Parallelization

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    LAYER 3: PARALLEL SUBAGENTS (Task tool)                  │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐  │
│  │    Subagent A       │  │    Subagent B       │  │    Subagent C       │  │
│  │  ┌───────────────┐  │  │  ┌───────────────┐  │  │  ┌───────────────┐  │  │
│  │  │ LAYER 2: Bash │  │  │  │ LAYER 2: Bash │  │  │  │ LAYER 2: Bash │  │  │
│  │  │ ┌───────────┐ │  │  │  │ ┌───────────┐ │  │  │  │ ┌───────────┐ │  │  │
│  │  │ │L1: mcp &  │ │  │  │  │ │L1: mcp &  │ │  │  │  │ │L1: mcp &  │ │  │  │
│  │  │ │L1: mcp &  │ │  │  │  │ │L1: mcp &  │ │  │  │  │ │L1: mcp &  │ │  │  │
│  │  │ │wait       │ │  │  │  │ │wait       │ │  │  │  │ │wait       │ │  │  │
│  │  │ └───────────┘ │  │  │  │ └───────────┘ │  │  │  │ └───────────┘ │  │  │
│  │  └───────────────┘  │  │  └───────────────┘  │  │  └───────────────┘  │  │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

| Layer | Mechanism | Speedup |
|-------|-----------|---------|
| **Layer 1** | Background jobs in single Bash call | N calls → 1 latency |
| **Layer 2** | Multiple parallel Bash tool calls | Concurrent execution |
| **Layer 3** | Parallel Task subagents | Independent contexts |

---

## Verified Benchmarks

### Test Environment
- Claude Code version: 2.1.12
- MCP Server: google-workspace
- Test call: `list_task_lists`
- Date: January 2026

### Results

| Configuration | Time | Speedup |
|---------------|------|---------|
| 2 sequential calls | 2.39s | — |
| 2 parallel calls | 0.99s | **2.4x** |
| 5 sequential calls | 5.93s | — |
| 5 parallel calls | 1.39s | **4.25x** |

### Reproduce

```bash
export ENABLE_EXPERIMENTAL_MCP_CLI=true
./benchmarks/run-benchmark.sh your@email.com
```

---

## What Gets Installed

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Instructions for parallel MCP orchestration |
| `.claude/hooks/mcp-parallel-validator.sh` | Advisory: warns on sequential calls |
| `.claude/hooks/mcp-cli-gate.sh` | Optional: blocks if env var not set |
| `.claude/hooks.json` | Hook configuration |

---

## Configuration

### Enforcement Levels

| Level | Behavior | Enable |
|-------|----------|--------|
| **Advisory** (default) | Warns when sequential MCP calls detected | Installed by default |
| **Strict** | Blocks mcp-cli without env var | Uncomment in hooks.json |

### Customizing hooks.json

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/mcp-parallel-validator.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

---

## Examples

### Daily Briefing (Calendar + Tasks + Email)

```bash
EMAIL="you@example.com"

# Wave 1: Independent sources
mcp-cli call google-workspace/get_events "{\"user_google_email\":\"$EMAIL\"}" > /tmp/events.json &
mcp-cli call google-workspace/search_gmail_messages "{\"user_google_email\":\"$EMAIL\",\"query\":\"in:inbox newer_than:3d\"}" > /tmp/emails.json &
mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$EMAIL\"}" > /tmp/lists.json &
wait

# Extract task list ID
TODAY_ID=$(jq -r '.task_lists[0].id' /tmp/lists.json)

# Wave 2: Fetch tasks
mcp-cli call google-workspace/list_tasks "{\"user_google_email\":\"$EMAIL\",\"task_list_id\":\"$TODAY_ID\"}" > /tmp/tasks.json &
wait

# Output
echo "=== CALENDAR ===" && jq -r '.content[0].text' /tmp/events.json
echo "=== TASKS ===" && jq -r '.content[0].text' /tmp/tasks.json
```

See `examples/` for more patterns.

---

## Troubleshooting

### "MCP endpoint file not found"

Session context lost. Don't use `bash -c` with new temp directories:

```bash
# WRONG
bash -c 'TMPDIR=$(mktemp -d); mcp-cli call ...'

# CORRECT
mcp-cli call ... &
wait
```

### "mcp-cli: command not found"

Environment variable not set:

```bash
export ENABLE_EXPERIMENTAL_MCP_CLI=true
```

### Background jobs not waiting

Missing `wait` command:

```bash
mcp-cli call ... &
mcp-cli call ... &
wait  # Required!
```

See `docs/troubleshooting.md` for more.

---

## Comparison with Anthropic's Approach

This toolkit is **inspired by** but **different from** Anthropic's [Code execution with MCP](https://www.anthropic.com/engineering/code-execution-with-mcp).

| Aspect | Anthropic's Approach | This Toolkit |
|--------|---------------------|--------------|
| **Primary goal** | Token efficiency | Latency reduction |
| **98.7% savings from** | On-demand tool loading | N/A |
| **Data filtering** | Yes (in code) | No (all results return) |
| **Execution model** | Filesystem code files | Inline bash commands |
| **Parallelization** | Not the focus | Primary mechanism |

**When to use what:**
- **This toolkit**: When you need faster MCP data gathering (latency matters)
- **Anthropic's approach**: When context window / token costs matter (implement their full pattern)

---

## Uninstallation

```bash
./install.sh --uninstall --user        # User-level
./install.sh --uninstall --project /p  # Project-level
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

MIT License. See [LICENSE](LICENSE).

---

## Related

- [Anthropic: Code execution with MCP](https://www.anthropic.com/engineering/code-execution-with-mcp) — Token efficiency through code execution
- [Claude Code](https://claude.ai/claude-code) — Anthropic's CLI
- [Model Context Protocol](https://modelcontextprotocol.io/) — MCP specification

---

*Created by [AIntelligent Technologies](https://aintelligenttech.com) — January 2026*
