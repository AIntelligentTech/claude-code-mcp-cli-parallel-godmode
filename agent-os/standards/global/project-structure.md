# Project Structure

## Standard Layout

```
project/
├── src/
│   ├── server/           # Backend code (if applicable)
│   │   ├── routes/       # API route handlers
│   │   ├── services/     # Business logic
│   │   └── adapters/     # External integrations
│   ├── routes/           # Frontend page routes
│   ├── components/       # React components
│   │   ├── ui/           # Reusable UI primitives
│   │   └── [feature]/    # Feature-specific components
│   ├── lib/              # Shared utilities
│   │   ├── types.ts      # TypeScript types
│   │   ├── api.ts        # API client
│   │   ├── hooks/        # React hooks
│   │   └── utils/        # Helper functions
│   └── styles/           # Global CSS
├── agent-os/             # Agent-OS standards & specs
├── .claude/              # Claude commands & config
├── docs/                 # Documentation
└── package.json
```

## Rules

- Co-locate tests next to source: `service.ts` + `service.test.ts`
- Group by feature, not by type
- Keep `lib/` for truly shared code only
- One export per file for components; barrel exports (`index.ts`) for feature modules
