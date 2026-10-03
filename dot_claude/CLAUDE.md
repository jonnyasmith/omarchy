# Global Instructions

## Subagent Models

- Implementation subagents: use `sonnet` for clear, narrow tasks. Escalate to `opus` after two failed attempts.
- Review and critique subagents: use `opus`. Use a fresh context.
- Planning, specs, and final branch review: use `opus`.
- Rote work (search, lookups, test runs): use `haiku`.
- All subagents reasoning effort **MUST** be set to `medium`, unless the user asked for a different level.

## Git

In a repository, when tests and lint pass (or the project has no checks), automatically stage and commit the changes using the /conventional-commits skill. Do not push or create PRs unless asked.

Follow the /write-pull-requests skill when creating PRs.

