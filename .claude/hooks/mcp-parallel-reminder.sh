#!/bin/bash
# MCP Parallel Orchestration Reminder
# Reminds to use parallel pattern when mcp-cli calls are detected
#
# Part of claude-code-mcp-cli-parallel-godmode
# https://github.com/yourusername/claude-code-mcp-cli-parallel-godmode

# Read tool input from stdin
INPUT=$(cat)

# Only process Bash tool calls
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
if [ "$TOOL_NAME" != "Bash" ]; then
    exit 0  # Not a Bash call, pass through
fi

# Check if this is an mcp-cli call (POSIX-compatible pattern match)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
case "$COMMAND" in
    *"mcp-cli call"*) ;;  # Contains mcp-cli call, continue checking
    *) exit 0 ;;          # Not an MCP call, pass through
esac

# Check if it's a simple single call (not part of parallel orchestration)
# A parallel orchestration includes '&' and 'wait'
# POSIX-compatible: check for absence of both patterns
case "$COMMAND" in
    *"&"*) exit 0 ;;    # Has background operator, likely parallel
    *"wait"*) exit 0 ;; # Has wait, likely parallel
esac

# Single sequential call - provide feedback with rule reference and correct pattern
echo '{"hookSpecificOutput":{"feedback":"[MCP-PARALLEL] For 2+ MCP calls, use parallel orchestration (2x-18x faster). See .claude/rules/mcp-parallel.md. Pattern: mcp-cli call server/tool1 {} > /tmp/r1.json & mcp-cli call server/tool2 {} > /tmp/r2.json & wait"}}'

exit 0  # Always allow (advisory mode)
