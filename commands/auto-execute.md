---
description: "Run autonomous plan execution: read a plan and implement it with TDD and verification gates, non-interactively. Walk away; come back to committed code."
---

You have been invoked via the `/auto-execute` command. The user has walked away and expects you to implement a plan autonomously.

**Parse arguments:**

- If `--plan <path>` is provided, use that plan file.
- If `$ARGUMENTS` contains `--session <dir>`, use that existing session directory.
- Otherwise, find the most recent session directory under `docs/auto-superpowers/sessions/` and use its `plan.md`. If no session dir or plan exists, emit a one-line error and stop.

**Pre-flight check:** Verify you are NOT on `main` or `master`. If you are, emit a one-line error telling the user to set up a worktree or feature branch first (auto-superpowers does not auto-create worktrees for standalone `/auto-execute` — that is the `/auto` pipeline driver's job). Stop.

**Immediately invoke the `auto-superpowers:executing-plans` skill via the `Skill` tool.** Pass the plan path and session directory path in the input prompt using this format:

```
SESSION_DIR: <path>
PLAN: <path>
```

That skill handles everything: self-checking the plan against repo state, dispatching the decision-proxy for tier-B/C blockers, running TDD loops per task, verification gates, halting on tier-C events, and committing progress.

Do NOT:
- Ask the user clarifying questions
- Invoke `superpowers:executing-plans` (upstream) — use `auto-superpowers:executing-plans`
- Invoke `finishing-a-development-branch` yourself — Phase 2 stops at `impl`

If no plan is available, emit:
```
auto-execute: no plan found. Usage: /auto-execute [--plan <path>] [--session <dir>]
            Run /auto-plan first, or supply --plan or --session.
```
and stop.
