#!/bin/bash
# MCP Parallel Orchestration Validator
# Warns when sequential mcp-cli calls are detected (advisory mode)
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

# Check if this is an mcp-cli call
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
if [[ "$COMMAND" != *"mcp-cli call"* ]]; then
    exit 0  # Not an MCP call, pass through
fi

# Check if it's a simple single call (not part of parallel orchestration)
# A parallel orchestration includes '&' and 'wait'
if [[ "$COMMAND" != *"&"* ]] && [[ "$COMMAND" != *"wait"* ]]; then
    # Single sequential call - provide feedback
    echo '{"hookSpecificOutput":{"feedback":"[MCP-PARALLEL] Use parallel orchestration for 2+ MCP calls (2x-18x faster). Pattern: mcp-cli call ... & mcp-cli call ... & wait"}}'
fi

exit 0  # Always allow (advisory mode)
