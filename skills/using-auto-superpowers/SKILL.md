---
name: using-auto-superpowers
description: "Use when starting any conversation in the auto-superpowers plugin - establishes how autonomous mode works, the decision-proxy dispatch contract, and how to read session artifacts."
---

# Using auto-superpowers

You are running inside the **auto-superpowers** plugin — a fork of `superpowers` that runs the spec → plan → execute workflow non-interactively. The user invoked a command and walked away. Your job is to complete their task end-to-end, recording every meaningful decision in an auditable session log.

## The contract

Auto-superpowers skills override default interactive behavior:

1. **Never ask the user questions mid-run.** The user is not at the keyboard. If you would have asked a clarifying question in upstream superpowers, dispatch the `decision-proxy` subagent instead.
2. **Log every meaningful decision.** Every tier-B and tier-C decision appends a structured entry to `session-log.md`. Tier-A (mechanical) decisions are silent.
3. **Halt on unresolved tier-C.** If the `decision-proxy` returns low confidence on a tier-C decision, write `halted.md`, stop, and do not proceed.
4. **Honor `user-preferences.md`.** Hard constraints and absolute preferences override any skill-sourced default.

## Reading order at session start

Before doing any work, read these in order:

1. `skills/session-artifacts/SKILL.md` — file layout and log formats.
2. `skills/decision-proxy/SKILL.md` — the routing guide the proxy uses.
3. `docs/auto-superpowers/user-preferences.md` (if present) — the user's overrides.

## Decision tiers (summary)

- **Tier A** (mechanical, reversible in <5min): decide silently, no log entry.
- **Tier B** (substantive, reversible with effort): dispatch `decision-proxy`, append log entry, continue.
- **Tier C** (load-bearing, hard to reverse, security-sensitive): dispatch `decision-proxy` with `tier: C`. If proxy returns `confidence: high` with a definitive answer, continue with a TIER-C log entry. Otherwise halt to `halted.md`.

See `skills/decision-proxy/SKILL.md` for the full tier criteria and escalation rules.

## Co-install with upstream superpowers

If upstream `superpowers` is also installed, both plugins' skills are namespaced distinctly: `superpowers:brainstorming` (interactive) vs. `auto-superpowers:brainstorming` (autonomous). Use the auto-superpowers version for anything reached via `/auto-brainstorm`, `/auto-plan`, `/auto-execute`, or `/auto`. Use upstream for anything reached via `/brainstorm`, `/write-plan`, `/execute-plan`.

Phase 1 does not coordinate session-start preambles between the two plugins. Users who install both may see two preambles at session start. This is cosmetic and fixed in a later phase.

## Priority with other instructions

User instructions in CLAUDE.md, GEMINI.md, or direct messages always take precedence over this skill. Auto-superpowers' autonomy promise is "the user told me to run this autonomously," not "the user never gets to interrupt." If the user sends a new message mid-run, respond to it.
