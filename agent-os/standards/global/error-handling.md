# Error Handling

## Principles

- Fail fast at system boundaries (user input, external APIs)
- Trust internal code and framework guarantees
- Don't add error handling for scenarios that can't happen
- Return errors, don't throw (prefer Result patterns where practical)

## Backend

- Use try/catch at route handler level
- Return consistent error response shape: `{ error: string, details?: unknown }`
- Log errors with context (request ID, user, operation)
- Use appropriate HTTP status codes

## Frontend

- Use error boundaries for component-level failures
- Show user-friendly messages, log technical details
- Handle loading/error/success states explicitly
- Don't silently swallow errors
