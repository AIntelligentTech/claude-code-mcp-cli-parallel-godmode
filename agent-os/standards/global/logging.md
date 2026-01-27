# Logging

## Levels

- **error** — Something broke, needs attention
- **warn** — Unexpected but recoverable
- **info** — Significant state changes (startup, job completion)
- **debug** — Detailed diagnostic info (disabled in production)

## Format

Use structured logging with context:

```typescript
logger.info('Job completed', { jobId, duration, repoCount })
logger.error('API request failed', { endpoint, status, error: err.message })
```

## Rules

- Never log secrets, tokens, or passwords
- Include correlation IDs for request tracing
- Keep log messages concise and grep-friendly
- Use `debug` level for high-frequency operations
