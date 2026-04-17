---
name: executing-plans
description: "Use when auto-superpowers executing-plans is invoked (via /auto-execute or /auto). Runs an implementation plan non-interactively with tier-aware proxy dispatches, verification gates, and halt-on-unresolved-tier-C behavior."
---

# Executing Plans

## Overview

Load plan, self-check against repo state, execute all tasks non-interactively with verification gates, halt on unresolved tier-C events, return when complete.

**Announce at start:** "I'm using the auto-superpowers:executing-plans skill to implement this plan."

**Context:** You are running inside the auto-superpowers plugin. Read `skills/using-auto-superpowers/SKILL.md`, `skills/session-artifacts/SKILL.md`, and `skills/decision-proxy/SKILL.md` before starting. The caller (the pipeline driver or a command shim) will name the session directory. Use it.

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

1. Read the task's `Tier:` annotation (from the plan).
2. Mark as in_progress in TodoWrite.
3. Run each step in the task exactly as written (bite-sized TDD steps).
4. **Verification gate before moving to the next plan step:**
   - Run the task's specified tests.
   - If tests pass: mark complete, continue to next task.
   - If tests fail:
     - Assess whether the failure is in code the current task introduced (tier B) or a regression in unrelated code (tier C).
     - Tier B: dispatch `decision-proxy` if the failure's cause is unclear; otherwise iterate per the task's debugging steps.
     - Tier C: write `halted.md` with the regression details and STOP.
5. **If 3+ fixes fail on the same task's tests, invoke systematic-debugging's 3+ failures rule — write `halted.md` with the fix history and hypothesis. STOP.**
6. For tier-B or tier-C plan tasks (annotated in the plan), dispatch the `decision-proxy` BEFORE starting the task for any genuinely open question the plan left. Log the entry.

### Step 3: Return (Phase 2: stop at impl)

After all tasks complete and the test suite passes:

- Append a "## Halts" section to `session-log.md` if any halts occurred (or `(none)` if clean).
- Check whether the session directory is gitignored. If NOT gitignored, commit any remaining session-log.md updates with:

  ```
  auto-superpowers: execute plan for <slug>

  Session: docs/auto-superpowers/sessions/<dir>/
  ```

  If gitignored, skip the commit and note "execute-phase commit skipped (gitignored)" in status.
- Emit terse status: session dir, tasks completed, halts, current branch, HEAD sha. Return. Do NOT invoke `finishing-a-development-branch` — Phase 3 adds that.

Phase 2 always stops at `impl`. Phase 3 adds `--stop-at pr` and `--stop-at merged` stages that chain into `finishing-a-development-branch`.

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
- **auto-superpowers:using-git-worktrees** (or upstream) — REQUIRED: Set up isolated workspace before starting. The pipeline driver (`/auto` command) handles this for pipeline runs; standalone `/auto-execute` callers are responsible for worktree setup themselves.
- **auto-superpowers:writing-plans** — Creates the plan this skill executes
- **auto-superpowers:systematic-debugging** — For root-cause investigation on test failures; enforces the 3+ failures halt rule
- **auto-superpowers:test-driven-development** — For RED/GREEN/REFACTOR discipline within each task
- **auto-superpowers:verification-before-completion** — For verifying claims of completion before marking tasks done
- **auto-superpowers:decision-proxy** — For tier-B/C dispatches during execution
- **auto-superpowers:session-artifacts** — For the session-log.md and halted.md formats

**Phase 3 adds:**
- **auto-superpowers:finishing-a-development-branch** — Completion after all tasks (merge / PR / keep logic)
