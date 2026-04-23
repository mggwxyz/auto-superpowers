---
name: session-artifacts
description: "Defines the session directory layout, session-log.md format, halted.md format, and commit trailer convention for auto-superpowers. Read this when creating a new session or writing to any session artifact."
---

# Session Artifacts — File Formats and Conventions

Auto-superpowers records every autonomous run in a session directory. This skill defines the shape of those directories and the files inside them. Any skill that reads or writes session artifacts MUST follow these conventions exactly.

## Directory layout

Default root: `docs/auto-superpowers/`. Overridable via `AUTO_SUPERPOWERS_DOCS_ROOT` environment variable or a per-command `--docs-root` flag (Phase 2+).

```
docs/auto-superpowers/
├── sessions/
│   └── YYYY-MM-DD-HHMM-<slug>/          ← one directory per auto run
│       ├── session-log.md                 ← chronological transcript
│       ├── spec.md                         ← design doc (from brainstorming)
│       ├── plan.md                         ← implementation plan (Phase 2+)
│       └── halted.md                       ← present only if the session halted
└── user-preferences.md                     ← optional; project-scoped
```

The slug is derived from the task description: lowercased, punctuation stripped, spaces → hyphens, truncated to 40 chars. Example: `build a login flow with email+password` → `build-a-login-flow-with-email-password` → truncate to `build-a-login-flow-with-email-password` (already under 40).

## session-log.md format

Every session-log.md starts with this header:

```markdown
# Session log — YYYY-MM-DD HH:MM
Task: <one-line task description>
Stop at: <spec|plan|impl|pr|merged>
Skills available for persona expertise: <comma-separated list, or "none detected">

## TLDR
<2-4 sentence summary of what this session produced, the key decisions made, and whether it completed or halted. Written after brainstorming completes; updated at the end of each subsequent phase.>

## Phase: brainstorming
```

Each tier-B or tier-C decision appends an entry in this exact shape:

```markdown
### HH:MM | <short decision title>
- Tier: <B|C>
- Options: [<option1>, <option2>, ...]
- Skill consulted: <skill name, or "none (general reasoning)">
- Proxy answered: <the chosen option>
- Reasoning: <3-6 sentences>
- User prefs applied: <quoted preference, or "none">
- Confidence: <high|medium|low>
```

For tier-C entries that auto-proceeded, append `| Tier-C auto-proceed allowed` to the Confidence line.

Phase boundaries start with `## Phase: <phase-name>`. End with a `## Halts` section listing any halted.md events (or `(none)` if clean).

## halted.md format

Written only when a tier-C decision halts the session. Exactly this shape:

```markdown
# Session halted — high-stakes decision needed

**When:** YYYY-MM-DD HH:MM (<phase> phase)
**Task:** <one-line task description>

## The decision
<The question in plain terms>

## Options considered
- **A:** <option + summary>
- **B:** <option + summary>
- **C:** <option + summary>

## Proxy's tentative recommendation
<Option letter and reasoning, or "proxy could not commit">

## Why this halted
<Tier-C trigger description>

## How to resume
Reply with one of:
- `go with <letter>` — accept an option
- `go with proxy` — accept the proxy's recommendation
- answer freely in your own words

## Pointers
- session-log.md: [link]
- relevant files: <list>
```

## Commit trailer convention

Every commit produced inside a session includes a trailer line:

```
Session: docs/auto-superpowers/sessions/<dir>/
```

This lets any commit be traced back to its decision trail via `git log --show-notes`.

## Privacy rules

- **Never quote secret values in session-log.md.** Refer to secrets by name only (`DATABASE_URL`, not `postgres://user:pass@...`).
- **Session directories are gitignored by default.** The plugin installer (or Task 9 of the Phase 1 plan) adds `docs/auto-superpowers/sessions/` to the project's `.gitignore`. Users who want session artifacts committed opt in by removing that line, or by using `--commit-session-log` once Phase 3 introduces the flag.

## Slug generation reference

Use this exact algorithm so different skills produce identical slugs:

1. Lowercase the task description.
2. Replace any character not in `[a-z0-9 ]` with a space.
3. Collapse runs of whitespace to a single space.
4. Trim leading/trailing whitespace.
5. Replace spaces with `-`.
6. Truncate to 40 characters, trimming a trailing `-` if present.
