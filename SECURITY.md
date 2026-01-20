# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly:

1. **Do NOT** open a public GitHub issue for security vulnerabilities
2. Email security concerns to: tony.deverill@aintelligenttech.com
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

## Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 7 days
- **Resolution**: Dependent on severity, typically within 30 days

## Security Considerations

This tool executes shell commands provided in configuration files. Users should:

1. **Review scripts before execution** - Always inspect `install.sh` and hook scripts before running
2. **Use trusted sources** - Only install from the official repository
3. **Keep updated** - Use the latest version for security fixes
4. **Sandbox testing** - Test in isolated environments first

## Scope

This policy applies to:
- The `install.sh` installer script
- Hook scripts (`.claude/hooks/`)
- Rules and configuration files

## Out of Scope

- Third-party MCP servers you connect to
- Your own scripts that use this toolkit
- Claude Code itself (report to Anthropic)
