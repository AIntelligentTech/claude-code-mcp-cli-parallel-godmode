# Contributing to MCP Parallel Orchestration

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## Ways to Contribute

- **Bug Reports**: Found an issue? Open a GitHub issue with reproduction steps
- **Feature Requests**: Have an idea? Open an issue to discuss
- **Documentation**: Improvements to README, examples, or inline comments
- **Code**: Bug fixes, new examples, or enhanced hooks

## Development Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/yourusername/claude-code-mcp-cli-parallel-godmode.git
   cd claude-code-mcp-cli-parallel-godmode
   ```
3. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Testing Changes

Before submitting:

1. **Test the install script**:
   ```bash
   ./install.sh --project /tmp/test-project
   ```

2. **Run the benchmark** to verify performance claims:
   ```bash
   export ENABLE_EXPERIMENTAL_MCP_CLI=true
   ./benchmarks/run-benchmark.sh your@email.com
   ```

3. **Test hooks manually**:
   ```bash
   # Test validator hook
   echo '{"tool_name":"Bash","tool_input":{"command":"mcp-cli call test/tool"}}' | \
     .claude/hooks/mcp-parallel-validator.sh
   ```

## Code Style

- **Shell scripts**: Use `shellcheck` for linting
- **Documentation**: Keep it concise and technical
- **Comments**: Explain "why", not "what"

## Pull Request Process

1. Update documentation if adding new features
2. Add yourself to CONTRIBUTORS.md (optional)
3. Ensure all tests pass
4. Submit PR with clear description of changes

## Commit Messages

Use conventional commit format:

```
type(scope): description

[optional body]
```

Types: `feat`, `fix`, `docs`, `chore`, `refactor`

Examples:
- `feat(hooks): add timeout configuration option`
- `fix(install): handle existing CLAUDE.md gracefully`
- `docs(readme): add macOS-specific instructions`

## Questions?

Open an issue with the `question` label.
