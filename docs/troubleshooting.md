# Troubleshooting Guide

Common issues and their solutions.

## "MCP endpoint file not found"

**Cause:** Session context lost when spawning a subshell with a new temp directory.

**Example of broken code:**
```bash
bash -c 'TMPDIR=$(mktemp -d); mcp-cli call server/tool ...'
```

**Solution:** Don't create new temp directories. Run mcp-cli directly or with background jobs:

```bash
# Correct: background jobs inherit session context
mcp-cli call server/tool1 '{}' > /tmp/a.json &
mcp-cli call server/tool2 '{}' > /tmp/b.json &
wait
```

**Why:** `mcp-cli` needs access to Claude Code's session endpoint files, which are stored in a specific temp location. Creating `TMPDIR=$(mktemp -d)` changes where the CLI looks for these files.

---

## "mcp-cli: command not found"

**Cause:** The `ENABLE_EXPERIMENTAL_MCP_CLI` environment variable is not set.

**Solution:** Add to your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
export ENABLE_EXPERIMENTAL_MCP_CLI=true
```

Then restart your shell or run `source ~/.zshrc`.

**Note:** This must be set before starting Claude Code, not just in the Bash tool.

---

## Background jobs not waiting

**Cause:** Missing `wait` command after launching background jobs.

**Broken:**
```bash
mcp-cli call server/tool1 '{}' > /tmp/a.json &
mcp-cli call server/tool2 '{}' > /tmp/b.json &
cat /tmp/a.json  # Files may be incomplete!
```

**Fixed:**
```bash
mcp-cli call server/tool1 '{}' > /tmp/a.json &
mcp-cli call server/tool2 '{}' > /tmp/b.json &
wait  # <-- Essential!
cat /tmp/a.json  # Now safe to read
```

---

## JSON parse errors in extracted values

**Cause:** Newlines or whitespace in values extracted from JSON.

**Broken:**
```bash
TASK_ID=$(grep -o 'ID: [^)]*' /tmp/result.json | head -1)
# TASK_ID may contain newlines
```

**Fixed:**
```bash
TASK_ID=$(cat /tmp/result.json | tr -d '\n' | grep -o 'ID: [^)]*' | head -1 | sed 's/ID: //')
```

Or better, use `jq`:
```bash
TASK_ID=$(jq -r '.task_lists[0].id' /tmp/result.json)
```

---

## Hooks not triggering

**Cause:** Hooks file not in the correct location or format.

**Check:**
1. Hooks file location:
   - User-level: `~/.claude/hooks/hooks.json`
   - Project-level: `.claude/hooks.json`

2. Script permissions:
   ```bash
   chmod +x .claude/hooks/*.sh
   ```

3. JSON syntax:
   ```bash
   jq . .claude/hooks.json  # Should parse without errors
   ```

4. Verify path variables:
   - `${HOME}` for user-level
   - `${CLAUDE_PROJECT_DIR}` for project-level

---

## Slow performance despite parallelization

**Possible causes:**

1. **Rate limiting:** MCP servers may throttle concurrent requests
   - Solution: Reduce parallelism or add delays between waves

2. **Network bottleneck:** All calls share the same connection
   - Solution: This is expected; parallel calls still faster than sequential

3. **Heavy endpoint:** One slow endpoint dominates total time
   - Solution: Move slow endpoints to separate waves

**Diagnostic:**
```bash
# Time individual calls to identify slow ones
time mcp-cli call server/tool1 '{}'
time mcp-cli call server/tool2 '{}'
```

---

## Hooks causing unexpected behavior

**Debug mode:**

Add logging to hooks:
```bash
#!/bin/bash
# At top of hook script
echo "[DEBUG] Hook called at $(date)" >> /tmp/hook-debug.log
echo "[DEBUG] Input: $(cat)" >> /tmp/hook-debug.log
```

**Disable temporarily:**

Rename or remove hooks.json:
```bash
mv .claude/hooks.json .claude/hooks.json.bak
```

---

## Still stuck?

1. Check Claude Code version: `claude --version`
2. Verify MCP servers connected: `mcp-cli servers`
3. Open an issue with:
   - Error message (full)
   - Claude Code version
   - OS and shell (`echo $SHELL`)
   - Minimal reproduction steps
