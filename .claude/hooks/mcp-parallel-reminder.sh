#!/bin/bash
# MCP Parallel Orchestration Reminder
# Reminds to use parallel pattern when mcp-cli operations are detected
# Triggers on BOTH mcp-cli info AND mcp-cli call
#
# Part of claude-code-mcp-cli-parallel-godmode
# https://github.com/AIntelligentTech/claude-code-mcp-cli-parallel-godmode

# Read tool input from stdin
INPUT=$(cat)

# Only process Bash tool calls
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
if [ "$TOOL_NAME" != "Bash" ]; then
    exit 0  # Not a Bash call, pass through
fi

# Check if this is an mcp-cli operation (info OR call)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
case "$COMMAND" in
    *"mcp-cli info"*|*"mcp-cli call"*) ;;  # Contains mcp-cli operation, continue checking
    *) exit 0 ;;  # Not an MCP operation, pass through
esac

# Check if it's a simple single operation (not part of parallel orchestration)
# A parallel orchestration includes '&' and 'wait'
# POSIX-compatible: check for absence of both patterns
case "$COMMAND" in
    *"&"*) exit 0 ;;    # Has background operator, likely parallel
    *"wait"*) exit 0 ;; # Has wait, likely parallel
esac

# Single sequential operation - provide feedback with rule reference and correct pattern
echo '{"hookSpecificOutput":{"feedback":"[MCP-PARALLEL] For 2+ MCP operations (info OR call), use parallel orchestration (2x-18x faster). See .claude/rules/mcp-parallel.md. Pattern: mcp-cli info/call ... > /tmp/r1.json & mcp-cli info/call ... > /tmp/r2.json & wait. Target 20-25 operations per Bash call."}}'

exit 0  # Always allow (advisory mode)
