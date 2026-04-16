---
description: "Run an autonomous brainstorm: produce spec.md + session-log.md in a new session directory without interactive prompts. Walk away; come back to a committed spec."
---

You have been invoked via the `/auto-brainstorm` command. The user has walked away and expects you to produce a complete spec autonomously.

**Immediately invoke the `auto-superpowers:brainstorming` skill via the `Skill` tool.** Pass the user's task description as input. That skill handles everything: creating the session directory, writing `session-log.md`, dispatching the decision-proxy, drafting `spec.md`, self-review, and committing.

Do NOT:
- Ask the user clarifying questions
- Invoke `superpowers:brainstorming` (the interactive upstream version) — use `auto-superpowers:brainstorming`
- Write any files before the skill runs
- Invoke writing-plans yourself — Phase 1 stops after the spec is committed

If the user provided no task description, emit a one-line error naming the correct usage (`/auto-brainstorm "<task description>"`) and stop.
