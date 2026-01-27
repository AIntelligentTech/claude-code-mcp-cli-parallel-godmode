# Naming Conventions

## Files & Directories

- Use kebab-case for files and directories: `my-component.tsx`, `use-auth.ts`
- Test files: `*.test.ts` or `*.test.tsx` alongside source
- Type files: `types.ts` in the relevant module directory

## Code

- **Variables/functions:** camelCase — `getUserData`, `isActive`
- **Types/interfaces:** PascalCase — `UserProfile`, `JobStatus`
- **Constants:** SCREAMING_SNAKE_CASE — `MAX_RETRIES`, `API_BASE_URL`
- **Enums:** PascalCase for name, PascalCase for members
- **React components:** PascalCase — `UserCard`, `DashboardLayout`
- **Hooks:** camelCase with `use` prefix — `useAuth`, `usePortfolio`

## Database / API

- Database tables: snake_case plural — `user_profiles`
- API routes: kebab-case — `/api/user-profiles`
- Query parameters: camelCase — `?pageSize=10`
