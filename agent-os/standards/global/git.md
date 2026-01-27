# Git Standards

## Commit Messages

Use conventional commits format:

```
type(scope): description

Body (optional)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Types:** `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, `ci`

## Branching

- `main` — production-ready
- `feat/*` — feature branches
- `fix/*` — bug fix branches
- Keep branches short-lived; merge via PR or direct push

## Rules

- Never force-push to `main`
- Always backup configs before editing (`.backup` suffix)
- Commit related changes together, not file-by-file
- Write commit messages that explain *why*, not just *what*
