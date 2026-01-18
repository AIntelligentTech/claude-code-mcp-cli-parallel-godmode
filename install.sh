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

print_success() { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
print_warning() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
print_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }
print_info() { printf "${BLUE}[INFO]${NC} %s\n" "$1"; }

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

detect_shell_profile() {
    # Detect the appropriate shell profile
    if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "$(command -v zsh)" ]; then
        echo "$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ] || [ "$SHELL" = "$(command -v bash)" ]; then
        if [ -f "$HOME/.bash_profile" ]; then
            echo "$HOME/.bash_profile"
        else
            echo "$HOME/.bashrc"
        fi
    else
        echo "$HOME/.profile"
    fi
}

check_prerequisites() {
    # Check HOME is set (required for --user install)
    if [ -z "$HOME" ]; then
        print_error "HOME environment variable is not set"
        exit 1
    fi

    # Check and install jq if missing
    if ! command -v jq >/dev/null 2>&1; then
        print_warning "jq is required but not installed"

        # Try to auto-install based on platform
        if command -v brew >/dev/null 2>&1; then
            print_info "Installing jq via Homebrew..."
            brew install jq
        elif command -v apt-get >/dev/null 2>&1; then
            print_info "Installing jq via apt..."
            sudo apt-get update -qq && sudo apt-get install -y jq
        elif command -v dnf >/dev/null 2>&1; then
            print_info "Installing jq via dnf..."
            sudo dnf install -y jq
        elif command -v yum >/dev/null 2>&1; then
            print_info "Installing jq via yum..."
            sudo yum install -y jq
        elif command -v pacman >/dev/null 2>&1; then
            print_info "Installing jq via pacman..."
            sudo pacman -S --noconfirm jq
        else
            print_error "Could not auto-install jq. Please install manually:"
            echo "  macOS:  brew install jq"
            echo "  Ubuntu: sudo apt install jq"
            echo "  Fedora: sudo dnf install jq"
            exit 1
        fi

        # Verify installation
        if command -v jq >/dev/null 2>&1; then
            print_success "jq installed successfully"
        else
            print_error "jq installation failed"
            exit 1
        fi
    fi

    # Check and configure ENABLE_EXPERIMENTAL_MCP_CLI
    if [ "${ENABLE_EXPERIMENTAL_MCP_CLI}" != "true" ]; then
        SHELL_PROFILE=$(detect_shell_profile)

        # Check if already in profile but not exported in current session
        if grep -q "ENABLE_EXPERIMENTAL_MCP_CLI=true" "$SHELL_PROFILE" 2>/dev/null; then
            print_warning "ENABLE_EXPERIMENTAL_MCP_CLI is in $SHELL_PROFILE but not active"
            echo "  Run: source $SHELL_PROFILE"
        else
            print_info "Adding ENABLE_EXPERIMENTAL_MCP_CLI to $SHELL_PROFILE"
            echo "" >> "$SHELL_PROFILE"
            echo "# MCP CLI (required for claude-code mcp-cli)" >> "$SHELL_PROFILE"
            echo "export ENABLE_EXPERIMENTAL_MCP_CLI=true" >> "$SHELL_PROFILE"
            print_success "Added to $SHELL_PROFILE"
            echo "  Note: Restart your terminal or run: source $SHELL_PROFILE"
        fi
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
    # Install hooks.json (with auto-merge)
    # ============================================
    local hooks_file="$target_dir/hooks.json"
    if [ "$is_user_level" = "true" ]; then
        hooks_file="$target_dir/hooks/hooks.json"
    fi

    # Determine the hooks path variable for this install type
    # sed_path has backslash for sed substitution, raw_path is for jq
    local sed_path raw_path
    if [ "$is_user_level" = "true" ]; then
        sed_path='\${HOME}/.claude/hooks'
        raw_path='${HOME}/.claude/hooks'
    else
        sed_path='\${CLAUDE_PROJECT_DIR}/.claude/hooks'
        raw_path='${CLAUDE_PROJECT_DIR}/.claude/hooks'
    fi

    # Generate our hooks from template
    local our_hooks
    our_hooks=$(sed "s|{{HOOKS_PATH}}|$sed_path|g" "$SCRIPT_DIR/.claude/hooks.template.json")

    if [ -f "$hooks_file" ]; then
        # Check if our hooks are already present
        if grep -q "mcp-parallel-reminder.sh" "$hooks_file" 2>/dev/null; then
            # Check if gate is also present
            if grep -q "mcp-cli-gate.sh" "$hooks_file" 2>/dev/null; then
                print_warning "MCP hooks already installed in hooks.json, skipping..."
            else
                # Reminder exists but gate doesn't - need to add gate
                print_info "Adding mcp-cli-gate.sh to existing hooks..."
                local gate_command="$raw_path/mcp-cli-gate.sh"
                # Insert gate hook before reminder hook (use --arg to pass string, build object in jq)
                jq --arg cmd "$gate_command" '
                    .hooks.PreToolUse |= map(
                        if .matcher == "Bash" then
                            .hooks |= ([{"type":"command","command":$cmd,"timeout":5}] + map(select(.command | contains("mcp-cli-gate") | not)))
                        else . end
                    )
                ' "$hooks_file" > "$hooks_file.tmp" && mv "$hooks_file.tmp" "$hooks_file"
                print_success "Added mcp-cli-gate.sh to hooks.json"
            fi
        else
            # No MCP hooks present - merge our hooks into existing file
            print_info "Merging MCP hooks into existing hooks.json..."
            local our_pretooluse
            our_pretooluse=$(echo "$our_hooks" | jq '.hooks.PreToolUse[0]')

            # Check if PreToolUse array exists and has Bash matcher
            if jq -e '.hooks.PreToolUse' "$hooks_file" > /dev/null 2>&1; then
                # PreToolUse exists - check for existing Bash matcher
                if jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash")' "$hooks_file" > /dev/null 2>&1; then
                    # Bash matcher exists - append our hooks to it
                    local our_hook_entries
                    our_hook_entries=$(echo "$our_hooks" | jq '.hooks.PreToolUse[0].hooks')
                    jq --argjson newhooks "$our_hook_entries" '
                        .hooks.PreToolUse |= map(
                            if .matcher == "Bash" then .hooks += $newhooks else . end
                        )
                    ' "$hooks_file" > "$hooks_file.tmp" && mv "$hooks_file.tmp" "$hooks_file"
                else
                    # No Bash matcher - add our entire PreToolUse entry
                    jq --argjson entry "$our_pretooluse" '.hooks.PreToolUse += [$entry]' "$hooks_file" > "$hooks_file.tmp" && mv "$hooks_file.tmp" "$hooks_file"
                fi
            else
                # No PreToolUse - add it
                jq --argjson entry "$our_pretooluse" '.hooks.PreToolUse = [$entry]' "$hooks_file" > "$hooks_file.tmp" && mv "$hooks_file.tmp" "$hooks_file"
            fi
            print_success "Merged MCP hooks into hooks.json"
        fi
    else
        # No existing hooks.json - create from template
        echo "$our_hooks" > "$hooks_file"
        print_success "Created hooks.json (hook configuration)"
    fi

    # ============================================
    # Verify Installation
    # ============================================
    echo ""
    echo "Verifying installation..."
    echo ""

    local failures=0

    # Check CLAUDE.md
    if [ -f "$target_dir/CLAUDE.md" ] && grep -q "MCP Parallel Orchestration" "$target_dir/CLAUDE.md" 2>/dev/null; then
        print_success "CLAUDE.md contains MCP instructions"
    else
        print_error "CLAUDE.md missing or incomplete"
        failures=$((failures + 1))
    fi

    # Check rules
    if [ -f "$target_dir/rules/mcp-parallel.md" ]; then
        print_success "rules/mcp-parallel.md exists"
    else
        print_error "rules/mcp-parallel.md missing"
        failures=$((failures + 1))
    fi

    # Check hook scripts exist and are executable
    if [ -x "$target_dir/hooks/mcp-cli-gate.sh" ]; then
        print_success "hooks/mcp-cli-gate.sh exists and executable"
    else
        print_error "hooks/mcp-cli-gate.sh missing or not executable"
        failures=$((failures + 1))
    fi

    if [ -x "$target_dir/hooks/mcp-parallel-reminder.sh" ]; then
        print_success "hooks/mcp-parallel-reminder.sh exists and executable"
    else
        print_error "hooks/mcp-parallel-reminder.sh missing or not executable"
        failures=$((failures + 1))
    fi

    # Check hooks.json contains both hooks
    if [ -f "$hooks_file" ]; then
        local gate_registered=false
        local reminder_registered=false

        if grep -q "mcp-cli-gate.sh" "$hooks_file" 2>/dev/null; then
            gate_registered=true
        fi
        if grep -q "mcp-parallel-reminder.sh" "$hooks_file" 2>/dev/null; then
            reminder_registered=true
        fi

        if [ "$gate_registered" = true ] && [ "$reminder_registered" = true ]; then
            print_success "hooks.json registers both hooks"
        elif [ "$gate_registered" = false ] && [ "$reminder_registered" = false ]; then
            print_error "hooks.json missing both MCP hooks"
            failures=$((failures + 1))
        elif [ "$gate_registered" = false ]; then
            print_error "hooks.json missing mcp-cli-gate.sh"
            failures=$((failures + 1))
        else
            print_error "hooks.json missing mcp-parallel-reminder.sh"
            failures=$((failures + 1))
        fi
    else
        print_error "hooks.json not found at $hooks_file"
        failures=$((failures + 1))
    fi

    # Summary
    echo ""
    echo "============================================"
    if [ $failures -eq 0 ]; then
        print_success "Installation verified! All components OK"
        echo "============================================"
        echo ""
        echo "Next steps:"
        echo "  1. Ensure ENABLE_EXPERIMENTAL_MCP_CLI=true in your shell profile"
        echo "  2. Restart Claude Code"
        echo "  3. Claude will now use parallel MCP orchestration automatically"
        echo ""
        echo "Test it:"
        echo "  Ask Claude: 'Make 5 MCP calls to list my task lists'"
        echo "  It should use: mcp-cli call ... & mcp-cli call ... & wait"
    else
        print_error "Installation incomplete: $failures component(s) failed"
        echo "============================================"
        echo ""
        echo "Please check the errors above and re-run the installer."
        return 1
    fi
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
