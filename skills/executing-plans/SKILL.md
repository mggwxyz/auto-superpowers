---
name: executing-plans
description: "Use when auto-superpowers executing-plans is invoked (via /auto-execute or /auto). Runs an implementation plan non-interactively with tier-aware proxy dispatches, verification gates, and halt-on-unresolved-tier-C behavior."
---

# Executing Plans

## Overview

Load plan, self-check against repo state, execute all tasks non-interactively with verification gates, halt on unresolved tier-C events, return when complete.

**Announce at start:** "I'm using the auto-superpowers:executing-plans skill to implement this plan."

**Context:** You are running inside the auto-superpowers plugin. Read `skills/using-auto-superpowers/SKILL.md`, `skills/session-artifacts/SKILL.md`, and `skills/decision-proxy/SKILL.md` before starting. The caller (the pipeline driver or a command shim) will name the session directory. Use it.

**Input parsing:** Look for these sentinels on their own lines in the input prompt:

- `SESSION_DIR: <path>` — the session directory to work in.
- `PLAN: <path>` — the plan to execute. If absent, default to `<session-dir>/plan.md`.
- `STOP_AT: <impl|pr|merged>` — the pipeline's stop-at level. If absent, default to `impl`.

If no `SESSION_DIR:` line is present, fall back to the most recent directory under `docs/auto-superpowers/sessions/`. If no plan exists there, emit a one-line error and stop.

<HARD-GATE>
Do NOT proceed if `<session-dir>/halted.md` exists. A prior stage halted on a tier-C decision and the user has not resumed. Return terse status reporting the halt and stop.
</HARD-GATE>

Autonomous mode assumes subagent-driven execution when subagents are available. If you cannot dispatch subagents, fall back to inline execution but still honor all tier rules and verification gates.

## The Process

### Step 1: Load plan and self-check

1. Read `<session-dir>/plan.md`
2. Append a `## Phase: executing-plans` section marker to `<session-dir>/session-log.md`
3. Self-check the plan against current repo state:
   - Does every file path the plan references exist where the plan expects?
   - Do the listed dependencies exist?
   - Are there merge conflicts, uncommitted changes, or untracked files that conflict with the plan's starting assumptions?
4. If any concern surfaces, assess tier:
   - Tier A (trivial, reversible): resolve inline, note in log.
   - Tier B (substantive): dispatch `decision-proxy`, log the entry, proceed with the proxy's answer.
   - Tier C (load-bearing): dispatch `decision-proxy` with `tier: C`; if proxy returns high-confidence definitive answer, continue; otherwise write `halted.md` and STOP.
5. Create TodoWrite entries for each plan task and proceed.

### Step 2: Execute tasks with verification gates

For each task in order:

1. Read the task's `Tier:` annotation (from the plan). If the task has no `Tier:` line, treat it as tier B by default. If the annotation is malformed (e.g., `Tier: medium`), treat as tier C and dispatch the `decision-proxy` to classify before proceeding. Note that the task's annotated tier is distinct from a failure's tier (below): the former gates pre-task proxy dispatches, the latter gates mid-task halts.
2. Mark as in_progress in TodoWrite.
3. Run each step in the task exactly as written (bite-sized TDD steps).
4. **Verification gate before moving to the next plan step:**
   - Run the task's specified tests.
   - If tests pass: mark complete, continue to next task.
   - If tests fail:
     - Assess whether the failure is in code the current task introduced (tier B) or a regression in unrelated code (tier C).
     - Tier B: dispatch `decision-proxy` if the failure's cause is unclear; otherwise iterate per the task's debugging steps.
     - Tier C: write `halted.md` with the regression details and STOP.
5. **If 3+ fixes fail on the same task's tests, invoke `auto-superpowers:systematic-debugging` and follow its Phase 4 step 5.** That skill dispatches the `decision-proxy` with `tier: C` for the architectural hypothesis and writes `halted.md` with the full fix history. STOP. Do NOT write `halted.md` yourself in this path — defer to systematic-debugging so the architectural-hypothesis proxy dispatch is not skipped.
6. For tier-B or tier-C plan tasks (annotated in the plan), dispatch the `decision-proxy` BEFORE starting the task for any genuinely open question the plan left. Log the entry.

### Step 3: Return (Phase 2: stop at impl)

After all tasks complete and the test suite passes:

- Append a "## Halts" section to `session-log.md` if any halts occurred (or `(none)` if clean).
- Update the `## TLDR` section in `session-log.md` to reflect execution results (tasks completed, test status, any halts).
- Check whether the session directory is gitignored: run `git check-ignore -q <session-dir>`. Exit 0 means gitignored; exit 1 means tracked. If tracked (exit 1), `git add <session-dir>/session-log.md` and commit with:

  ```
  auto-superpowers: execute plan for <slug>

  Session: docs/auto-superpowers/sessions/<dir>/
  ```

  If gitignored (exit 0), skip the session-artifact commit and note "execute-phase commit skipped (gitignored)" in status. Do NOT use `git add -f` to force-commit a gitignored path — respect the user's gitignore. (The task commits produced during execution are unrelated to this session-log commit and are never gitignored.)
- Emit terse status: session dir, tasks completed, halts, current branch, HEAD sha.

Default stop-at is `impl`. With `--stop-at pr` or `--stop-at merged`, Step 4 chains into `finishing-a-development-branch`.

### Step 4: Finish branch (--stop-at=pr or --stop-at=merged)

If `STOP_AT` is `pr` or `merged`:
- Invoke `auto-superpowers:finishing-a-development-branch` via the `Skill` tool with:
  ```
  SESSION_DIR: <path>
  STOP_AT: <pr|merged>
  ```
- Include the skill's return status (PR URL or error) in this skill's return status.

If `STOP_AT` is `impl` (default): skip Step 4. Emit terse status and return.

## When to halt

**Write `<session-dir>/halted.md` and STOP when:**
- A tier-C decision arose and the `decision-proxy` could not commit with high confidence
- 3+ consecutive fix attempts have failed on the same task's tests (per `systematic-debugging`'s rule)
- A plan task references a file, function, or dependency that does not exist and the gap is tier-C (cross-cutting scope change)
- A verification gate detects a regression in unrelated code (tier C)

**Dispatch `decision-proxy` when:**
- A blocker is tier B (substantive but reversible): proxy answers with general reasoning or a skill consultation, log the entry, proceed with the answer
- A plan task was annotated tier B and left a choice open

**Handle inline (no dispatch, no halt) when:**
- Tier A: file exists but at a slightly different path; test name differs by one character; obvious typo in the plan
- The fix is fully reversible in under 5 minutes and has no user-visible effect

**Never:**
- Ask the user a question mid-run. Dispatch the proxy instead.
- "Power through" a tier-C blocker by guessing.
- Skip verification gates to keep moving.
- Force through a failing test with `# noqa`, `skip`, or similar bypasses.

## Remember
- Review plan critically against repo state first
- Follow plan steps exactly
- Never skip verification gates
- Reference sibling skills when the plan says to
- Halt to `halted.md` on tier-C; do not guess
- Never force-push, never modify shared branches, never skip git hooks (these are refused outright)
- The caller (pipeline driver or worktree-setup sub-skill) is responsible for ensuring you are NOT on main/master before implementation begins; the task's git state is part of the Step 1 self-check

## Integration

**Required workflow skills:**
- **auto-superpowers:using-git-worktrees** (or upstream) — REQUIRED: Set up isolated workspace before starting. Phase 2's `/auto` pipeline driver does NOT auto-create worktrees yet — it refuses to run on main/master and expects the caller to have created a feature branch or worktree first. Standalone `/auto-execute` callers have the same responsibility. Phase 3 may add auto-worktree-creation to `/auto`.
- **auto-superpowers:writing-plans** — Creates the plan this skill executes
- **auto-superpowers:systematic-debugging** — For root-cause investigation on test failures; enforces the 3+ failures halt rule
- **auto-superpowers:test-driven-development** — For RED/GREEN/REFACTOR discipline within each task
- **auto-superpowers:verification-before-completion** — For verifying claims of completion before marking tasks done
- **auto-superpowers:decision-proxy** — For tier-B/C dispatches during execution
- **auto-superpowers:session-artifacts** — For the session-log.md and halted.md formats

- **auto-superpowers:finishing-a-development-branch** — Invoked in Step 4 for --stop-at=pr/merged
