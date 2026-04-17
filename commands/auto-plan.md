---
description: "Run autonomous plan-writing: read a spec and produce plan.md in a session directory without interactive prompts. Walk away; come back to a committed plan."
---

You have been invoked via the `/auto-plan` command. The user has walked away and expects you to produce an implementation plan autonomously.

**Parse arguments:**

- If `--spec <path>` is provided, use that spec file.
- If `$ARGUMENTS` contains `--session <dir>`, use that existing session directory.
- Otherwise, find the most recent session directory under `docs/auto-superpowers/sessions/` and use its `spec.md`. If no session dir exists, emit a one-line error explaining correct usage and stop.

**Immediately invoke the `auto-superpowers:writing-plans` skill via the `Skill` tool.** Pass the spec path and the session directory path in the input prompt using this format:

```
SESSION_DIR: <path>
SPEC: <path>
```

That skill handles everything: appending a `## Phase: writing-plans` section marker to the session log, dispatching the decision-proxy for meaningful planning decisions, drafting `plan.md`, self-review, and the gitignore-aware commit.

Do NOT:
- Ask the user clarifying questions
- Invoke `superpowers:writing-plans` (the upstream interactive version) — use `auto-superpowers:writing-plans`
- Write any files before the skill runs
- Invoke executing-plans yourself — `/auto-plan` stops after the plan is committed

If the user provided no spec and no recent session exists, emit:
```
auto-plan: no spec found. Usage: /auto-plan [--spec <path>] [--session <dir>]
         Run /auto-brainstorm first, or supply --spec or --session.
```
and stop.
