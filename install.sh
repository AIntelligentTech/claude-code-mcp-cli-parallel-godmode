#!/bin/bash
# MCP Parallel Orchestration Installer
# Installs CLAUDE.md, rules, and hooks for parallel MCP call optimization
#
# Usage:
#   ./install.sh --user              # Install to ~/.claude (all projects)
#   ./install.sh --project /path     # Install to specific project
#   ./install.sh --uninstall --user  # Remove user-level installation
#   ./install.sh --uninstall --project /path

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="2.0.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

show_help() {
    cat << EOF
MCP Parallel Orchestration Installer v${VERSION}

Usage:
  ./install.sh --user                    Install to ~/.claude (affects all projects)
  ./install.sh --project /path/to/proj   Install to a specific project
  ./install.sh --uninstall --user        Remove user-level installation
  ./install.sh --uninstall --project /p  Remove project-level installation
  ./install.sh --help                    Show this help

Options:
  --user          Install/uninstall at user level (~/.claude)
  --project PATH  Install/uninstall at project level (PATH/.claude)
  --uninstall     Remove installation instead of installing
  --strict        Enable strict mode (blocks mcp-cli without env var)
  --help          Show this help message

What Gets Installed:
  - CLAUDE.md      Concise instructions (references rules)
  - rules/         Detailed enforcement rules
  - hooks/         Pre-tool validation hooks

Prerequisites:
  Add to your shell profile (~/.zshrc or ~/.bashrc):
    export ENABLE_EXPERIMENTAL_MCP_CLI=true

Examples:
  ./install.sh --user
  ./install.sh --project ~/my-project
  ./install.sh --uninstall --user

EOF
}

check_prerequisites() {
    if [ "${ENABLE_EXPERIMENTAL_MCP_CLI}" != "true" ]; then
        print_warning "ENABLE_EXPERIMENTAL_MCP_CLI is not set"
        echo "  Add to your shell profile:"
        echo "    export ENABLE_EXPERIMENTAL_MCP_CLI=true"
        echo ""
    fi

    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed (required for hooks)"
        echo "  Install with: brew install jq"
        echo ""
    fi
}

install_files() {
    local target_dir="$1"
    local is_user_level="$2"
    local strict_mode="$3"

    echo "Installing MCP Parallel Orchestration to: $target_dir"
    echo ""
    print_info "Enforcement layers:"
    echo "  1. CLAUDE.md    - Instructions in model context"
    echo "  2. rules/       - Detailed enforcement rules"
    echo "  3. hooks/       - Runtime validation hooks"
    echo ""

    # Create directories
    mkdir -p "$target_dir/hooks"
    mkdir -p "$target_dir/rules"

    # ============================================
    # Install Rules
    # ============================================
    cp "$SCRIPT_DIR/.claude/rules/mcp-parallel.md" "$target_dir/rules/"
    print_success "Installed rules/mcp-parallel.md (enforcement rules)"

    # ============================================
    # Install CLAUDE.md
    # ============================================
    if [ -f "$target_dir/CLAUDE.md" ]; then
        # Check if already installed
        if grep -q "MCP Parallel Orchestration" "$target_dir/CLAUDE.md" 2>/dev/null; then
            print_warning "MCP Parallel Orchestration already in CLAUDE.md, skipping..."
        else
            print_warning "CLAUDE.md already exists, appending MCP section..."
            echo "" >> "$target_dir/CLAUDE.md"
            echo "---" >> "$target_dir/CLAUDE.md"
            echo "" >> "$target_dir/CLAUDE.md"
            cat "$SCRIPT_DIR/CLAUDE.md" >> "$target_dir/CLAUDE.md"
            print_success "Appended MCP instructions to CLAUDE.md"
        fi
    else
        cp "$SCRIPT_DIR/CLAUDE.md" "$target_dir/CLAUDE.md"
        print_success "Created CLAUDE.md (concise instructions)"
    fi

    # ============================================
    # Install Hooks
    # ============================================
    cp "$SCRIPT_DIR/.claude/hooks/mcp-parallel-reminder.sh" "$target_dir/hooks/"
    chmod +x "$target_dir/hooks/mcp-parallel-reminder.sh"
    print_success "Installed hooks/mcp-parallel-reminder.sh (advisory)"

    cp "$SCRIPT_DIR/.claude/hooks/mcp-cli-gate.sh" "$target_dir/hooks/"
    chmod +x "$target_dir/hooks/mcp-cli-gate.sh"
    print_success "Installed hooks/mcp-cli-gate.sh (env guard)"

    # ============================================
    # Install hooks.json
    # ============================================
    local hooks_file="$target_dir/hooks.json"
    if [ "$is_user_level" = "true" ]; then
        hooks_file="$target_dir/hooks/hooks.json"
    fi

    if [ -f "$hooks_file" ]; then
        print_warning "hooks.json already exists"
        echo "  Manual merge required. Add this to PreToolUse hooks:"
        echo '    {'
        echo '      "matcher": "Bash",'
        echo '      "hooks": [{'
        echo '        "type": "command",'
        if [ "$is_user_level" = "true" ]; then
            echo '        "command": "${HOME}/.claude/hooks/mcp-parallel-reminder.sh",'
        else
            echo '        "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/mcp-parallel-reminder.sh",'
        fi
        echo '        "timeout": 5'
        echo '      }]'
        echo '    }'
    else
        # Create hooks.json with appropriate paths
        if [ "$is_user_level" = "true" ]; then
            cat > "$hooks_file" << 'EOF'
{
  "description": "MCP Parallel Orchestration hooks",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${HOME}/.claude/hooks/mcp-parallel-reminder.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
EOF
        else
            cp "$SCRIPT_DIR/.claude/hooks.json" "$target_dir/hooks.json"
        fi
        print_success "Created hooks.json (hook configuration)"
    fi

    # Add gate hook if strict mode
    if [ "$strict_mode" = "true" ]; then
        print_warning "Strict mode: You'll need to manually add mcp-cli-gate.sh to hooks.json"
        echo "  See README.md for configuration details"
    fi

    echo ""
    echo "============================================"
    print_success "Installation complete!"
    echo "============================================"
    echo ""
    echo "Installed components:"
    echo "  - CLAUDE.md              Instructions (in model context)"
    echo "  - rules/mcp-parallel.md  Enforcement rules (auto-loaded)"
    echo "  - hooks/                 Runtime validation"
    echo ""
    echo "Next steps:"
    echo "  1. Ensure ENABLE_EXPERIMENTAL_MCP_CLI=true in your shell profile"
    echo "  2. Restart Claude Code"
    echo "  3. Claude will now use parallel MCP orchestration automatically"
    echo ""
    echo "Verification:"
    echo "  Ask Claude: 'Make 5 MCP calls to list my task lists'"
    echo "  It should use: mcp-cli call ... & mcp-cli call ... & wait"
}

uninstall_files() {
    local target_dir="$1"
    local is_user_level="$2"

    echo "Uninstalling MCP Parallel Orchestration from: $target_dir"
    echo ""

    # Remove rules
    if [ -f "$target_dir/rules/mcp-parallel.md" ]; then
        rm "$target_dir/rules/mcp-parallel.md"
        print_success "Removed rules/mcp-parallel.md"
    fi

    # Remove hooks
    if [ -f "$target_dir/hooks/mcp-parallel-reminder.sh" ]; then
        rm "$target_dir/hooks/mcp-parallel-reminder.sh"
        print_success "Removed hooks/mcp-parallel-reminder.sh"
    fi

    if [ -f "$target_dir/hooks/mcp-cli-gate.sh" ]; then
        rm "$target_dir/hooks/mcp-cli-gate.sh"
        print_success "Removed hooks/mcp-cli-gate.sh"
    fi

    # Note about CLAUDE.md
    if [ -f "$target_dir/CLAUDE.md" ]; then
        print_warning "CLAUDE.md not removed (may contain other content)"
        echo "  Manually remove the 'MCP Parallel Orchestration' section if desired"
    fi

    # Note about hooks.json
    print_warning "hooks.json not modified (may contain other hooks)"
    echo "  Manually remove MCP-related hooks if desired"

    # Clean up empty directories
    rmdir "$target_dir/rules" 2>/dev/null && print_success "Removed empty rules/ directory" || true

    echo ""
    print_success "Uninstallation complete!"
}

# Parse arguments
INSTALL_MODE=""
TARGET_PATH=""
UNINSTALL=false
STRICT_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --user)
            INSTALL_MODE="user"
            TARGET_PATH="$HOME/.claude"
            shift
            ;;
        --project)
            INSTALL_MODE="project"
            TARGET_PATH="$2/.claude"
            shift 2
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        --strict)
            STRICT_MODE=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate arguments
if [ -z "$INSTALL_MODE" ]; then
    print_error "Please specify --user or --project /path"
    echo ""
    show_help
    exit 1
fi

# Check prerequisites
check_prerequisites

# Execute
if [ "$UNINSTALL" = true ]; then
    uninstall_files "$TARGET_PATH" "$([ "$INSTALL_MODE" = "user" ] && echo "true" || echo "false")"
else
    install_files "$TARGET_PATH" "$([ "$INSTALL_MODE" = "user" ] && echo "true" || echo "false")" "$STRICT_MODE"
fi
