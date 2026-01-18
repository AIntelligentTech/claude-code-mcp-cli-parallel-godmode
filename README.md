# Claude Code MCP Parallel Orchestration

> Make Claude Code 4x faster by running MCP tool calls in parallel instead of sequentially.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-2.1.12+-blue.svg)](https://claude.ai/claude-code)

**Verified benchmark:** 5 sequential MCP calls (5.93s) → 5 parallel calls (1.39s) = **4.25x speedup**

---

## The Problem

When Claude Code gathers data from multiple MCP sources (calendar, tasks, email, GitHub), it runs calls sequentially by default. Each call takes ~1.2 seconds, so 5 calls = 6 seconds of waiting.

## The Solution

Run multiple `mcp-cli` calls in parallel using shell background jobs (`&`) and synchronization (`wait`):

```bash
mcp-cli call google-workspace/get_events '{}' > /tmp/events.json &
mcp-cli call google-workspace/list_tasks '{}' > /tmp/tasks.json &
mcp-cli call google-workspace/search_gmail '{}' > /tmp/emails.json &
wait
# All 3 complete in ~1.2s instead of ~3.6s
```

This repository provides **CLAUDE.md instructions** and **optional enforcement hooks** to make Claude Code use this pattern automatically.

---

## Quick Start

### Prerequisites

```bash
# Enable experimental mcp-cli (required)
export ENABLE_EXPERIMENTAL_MCP_CLI=true

# Verify it works
mcp-cli servers
```

Add to your shell profile (`~/.zshrc` or `~/.bashrc`):
```bash
export ENABLE_EXPERIMENTAL_MCP_CLI=true
```

### Installation

Choose **one** installation method:

#### Option A: User-Level (All Projects)

```bash
# Clone the repository
git clone https://github.com/yourusername/claude-code-mcp-codegen-godmode.git
cd claude-code-mcp-codegen-godmode

# Run installer
./install.sh --user
```

#### Option B: Project-Level (Single Project)

```bash
# From your project directory
git clone https://github.com/yourusername/claude-code-mcp-codegen-godmode.git /tmp/mcp-parallel
cd /tmp/mcp-parallel

# Install to current project
./install.sh --project /path/to/your/project
```

#### Option C: Manual Installation

Copy the relevant files:

```bash
# For user-level
cp CLAUDE.md ~/.claude/CLAUDE.md
cp -r .claude/hooks ~/.claude/hooks

# For project-level
cp CLAUDE.md /your/project/CLAUDE.md
cp -r .claude/hooks /your/project/.claude/hooks
```

---

## What Gets Installed

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Instructions Claude Code follows for parallel orchestration |
| `.claude/hooks/mcp-parallel-validator.sh` | Warns when sequential MCP calls detected (advisory) |
| `.claude/hooks/mcp-cli-gate.sh` | Blocks mcp-cli if env var not set (optional) |
| `.claude/hooks.json` | Hook configuration |

---

## How It Works

### Three Layers of Parallelization

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    LAYER 3: PARALLEL SUBAGENTS                              │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐  │
│  │    Task Agent A     │  │    Task Agent B     │  │    Task Agent C     │  │
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
                              Main Claude Session
```

| Layer | Mechanism | Benefit |
|-------|-----------|---------|
| **Layer 1** | Background jobs (`&`) + `wait` in single Bash | O(N) → O(1) latency |
| **Layer 2** | Multiple Bash tool calls in single message | No round-trip between calls |
| **Layer 3** | Parallel Task subagents | Context isolation + massive scale |

### Multiplicative Effect

| Configuration | Operations | Effective Parallelism |
|---------------|------------|----------------------|
| Layer 1 only | 5 mcp-cli in 1 Bash | 5x |
| Layer 1 + 2 | 3 Bash calls × 5 mcp-cli each | 15x |
| Layer 1 + 2 + 3 | 4 subagents × 3 Bash × 5 mcp-cli | 60x |

---

## Wave-Based Execution

For calls with dependencies, use the wave pattern:

```bash
EMAIL="you@example.com"

# Wave 1: Independent calls
mcp-cli call google-workspace/get_events "{\"user_google_email\":\"$EMAIL\"}" > /tmp/events.json &
mcp-cli call google-workspace/search_gmail_messages "{\"user_google_email\":\"$EMAIL\",\"query\":\"in:inbox\"}" > /tmp/emails.json &
mcp-cli call google-workspace/list_task_lists "{\"user_google_email\":\"$EMAIL\"}" > /tmp/lists.json &
wait

# Extract IDs from Wave 1
TODAY_ID=$(jq -r '.task_lists[0].id' /tmp/lists.json)

# Wave 2: Dependent calls
mcp-cli call google-workspace/list_tasks "{\"user_google_email\":\"$EMAIL\",\"task_list_id\":\"$TODAY_ID\"}" > /tmp/tasks.json &
wait

# Output
jq -r '.content[0].text' /tmp/events.json
```

---

## Verified Benchmarks

All performance claims have been independently verified (January 2026).

### Test Environment
- **Claude Code version:** 2.1.12
- **MCP Server:** google-workspace
- **Test call:** `list_task_lists`

### Results

| Test | Time | Speedup |
|------|------|---------|
| 2 sequential calls | 2.39s | — |
| 2 parallel calls | 0.99s | **2.4x** |
| 5 sequential calls | 5.93s | — |
| 5 parallel calls | 1.39s | **4.25x** |

### Reproduce the Benchmark

```bash
# Ensure mcp-cli is available
export ENABLE_EXPERIMENTAL_MCP_CLI=true

# Run benchmark script
./benchmarks/run-benchmark.sh your@email.com
```

---

## Configuration Options

### CLAUDE.md Settings

The installed `CLAUDE.md` includes these key instructions:

```markdown
## MCP Tool Orchestration

**CRITICAL: When making 3+ MCP tool calls, use parallel bash orchestration.**

### Pattern:
1. Identify independent calls (can run simultaneously)
2. Identify dependent calls (need results from earlier calls)
3. Execute in waves using background jobs (`&`) and `wait`
```

### Hook Settings

Edit `.claude/hooks.json` to customize:

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

### Enforcement Levels

| Level | Hook | Behavior |
|-------|------|----------|
| **Advisory** (default) | `mcp-parallel-validator.sh` | Warns but allows sequential calls |
| **Strict** | `mcp-cli-gate.sh` | Blocks mcp-cli if env var not set |

To enable strict mode, uncomment the gate hook in `hooks.json`.

---

## Troubleshooting

### "MCP endpoint file not found"

**Cause:** Session context lost in subshell.

**Fix:** Don't use `bash -c` with `mktemp -d`. Run mcp-cli directly or with background jobs.

```bash
# WRONG
bash -c 'TMPDIR=$(mktemp -d); mcp-cli call ...'

# CORRECT
mcp-cli call ... &
mcp-cli call ... &
wait
```

### "mcp-cli: command not found"

**Cause:** Environment variable not set.

**Fix:**
```bash
export ENABLE_EXPERIMENTAL_MCP_CLI=true
```

### Background jobs not waiting

**Cause:** Missing `wait` command.

**Fix:** Always add `wait` after launching background jobs:

```bash
mcp-cli call ... &
mcp-cli call ... &
wait  # <-- Required!
```

### JSON parse errors in extracted values

**Cause:** Newlines in extracted data.

**Fix:** Strip newlines before grep/sed:

```bash
VALUE=$(cat /tmp/result.json | tr -d '\n' | grep -o 'pattern')
```

---

## Examples

See the `examples/` directory for real-world patterns:

- `daily-briefing.sh` — Gather calendar, tasks, and email in parallel
- `multi-repo-status.sh` — Git status across multiple repositories
- `batch-api-query.sh` — Parallel API calls with dependency handling

---

## Uninstallation

### User-Level

```bash
./install.sh --uninstall --user
```

### Project-Level

```bash
./install.sh --uninstall --project /path/to/your/project
```

### Manual

Remove the added sections from your CLAUDE.md and delete the hooks:

```bash
rm -rf ~/.claude/hooks/mcp-*.sh  # or .claude/hooks/ for project-level
```

---

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/improvement`)
3. Run the benchmarks to verify changes
4. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

## Acknowledgments

Inspired by Anthropic's [Code execution with MCP](https://www.anthropic.com/engineering/code-execution-with-mcp) engineering blog post.

---

## Related Projects

- [Claude Code](https://claude.ai/claude-code) — Anthropic's CLI for Claude
- [Model Context Protocol](https://modelcontextprotocol.io/) — MCP specification

---

*Created by [AIntelligent Technologies](https://aintelligenttech.com) — January 2026*
