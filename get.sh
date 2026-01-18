#!/bin/bash
# Remote installer for MCP Parallel Orchestration
# Usage: curl -fsSL https://raw.githubusercontent.com/user/repo/main/get.sh | bash
#        curl -fsSL URL | bash -s -- --project /path

set -e

REPO="https://github.com/yourusername/claude-code-mcp-cli-parallel-godmode.git"

# Parse args (passed via bash -s -- args)
INSTALL_ARGS="${*:---user}"

# Create temp dir, clone, install, cleanup
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git clone --depth 1 -q "$REPO" "$tmp/mcp"
"$tmp/mcp/install.sh" $INSTALL_ARGS
