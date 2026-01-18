#!/bin/bash
# MCP-CLI Environment Gate
# Blocks mcp-cli usage if ENABLE_EXPERIMENTAL_MCP_CLI is not set
#
# Part of claude-code-mcp-cli-parallel-godmode
# https://github.com/yourusername/claude-code-mcp-cli-parallel-godmode

# Read tool input from stdin
INPUT=$(cat)

# Only process Bash tool calls
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
if [ "$TOOL_NAME" != "Bash" ]; then
    exit 0
fi

# Check if this is an mcp-cli call (POSIX-compatible pattern match)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
case "$COMMAND" in
    *mcp-cli*) ;;  # Contains mcp-cli, continue checking
    *) exit 0 ;;   # Not an mcp-cli call, pass through
esac

# Check if experimental flag is enabled
if [ "${ENABLE_EXPERIMENTAL_MCP_CLI}" != "true" ]; then
    echo '{"hookSpecificOutput":{"feedback":"[MCP-GATE] mcp-cli requires ENABLE_EXPERIMENTAL_MCP_CLI=true. Add to your shell profile: export ENABLE_EXPERIMENTAL_MCP_CLI=true"}}'
    exit 2  # Block the call
fi

exit 0
