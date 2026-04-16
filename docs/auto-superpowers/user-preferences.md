# User preferences

This file holds hard constraints and absolute preferences that override any
skill-sourced default during autonomous runs. The decision-proxy reads this
file at the start of every dispatch. Delete any sections you don't want.

## Hard constraints
<!-- Examples:
- Never use AWS in this project
- All services must run on a single $5/mo VPS
- No external services that cost money without explicit approval
-->

## Strong preferences
<!-- Examples:
- Prefer Postgres over any other DB unless specifically justified
- Boring tech over novelty — prefer battle-tested libraries
- YAGNI aggressive — cut scope whenever reasonable
-->

## Do not use
<!-- Examples:
- TypeScript branded types
- ORMs with magic (prefer query builders or raw SQL)
-->

## Corrections (from /calibrate-proxy)
<!-- Appended automatically by /calibrate-proxy (Phase 3) when you flag
     a decision in session-log.md as wrong. Format:
- YYYY-MM-DD — Proxy picked X; I'd pick Y. Reason: ...
-->
