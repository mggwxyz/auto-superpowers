# auto-superpowers Phase 2: Full Pipeline — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable `/auto "<task>"` to run the full spec → plan → execute pipeline non-interactively in a single walk-away session, with tier-C halt behavior end-to-end and `--stop-at` boundary control.

**Architecture:** Surgical rewrites of `writing-plans`, `executing-plans`, and `systematic-debugging` skills so each accepts an existing session directory, writes its artifacts into it, and respects the tier-B/C dispatch and halt rules established in Phase 1. Three new commands: `/auto-plan` and `/auto-execute` as single-stage shims, and `/auto` as a pipeline driver that chains all three stages in one command prompt. The pipeline driver creates the session dir up front and passes its path to each stage; each stage detects the existing directory and appends to the shared `session-log.md` instead of creating a new one.

**Tech Stack:**
- Markdown (SKILL.md edits, command shims)
- Shell (smoke test extension)
- No new dependencies; no new runtime machinery — all coordination happens via the session directory on disk and prose in the command file

**Reference spec:** `docs/superpowers/specs/2026-04-15-auto-superpowers-design.md` (Phase 2 section)

**Reference plan (for patterns):** `docs/superpowers/plans/2026-04-15-auto-superpowers-phase-1.md`

---

## Note on code blocks in this plan

Several tasks contain "write this content to file X" instructions where the target content itself contains code fences. Those outer content blocks use four-backtick fences where possible. Some Edit old_string/new_string blocks use three-backtick outer fences containing three-backtick inner fences. When implementing those steps, use `Read` on this plan file to view raw content and copy the exact strings — do not rely on markdown rendering, which will close the outer fence early.

---

## Scope Check

This plan covers **Phase 2 only** from the spec's "Implementation phasing" section. It does **not** cover:
- `finishing-a-development-branch`, `receiving-code-review`, `requesting-code-review` edits (Phase 3)
- `/calibrate-proxy` command (Phase 3)
- `--stop-at=pr` and `--stop-at=merged` stages (Phase 3)
- Golden-task fixtures and eval harness (Phase 4)

Phase 2's definition of done: a user can run `/auto "<task>"` with `--stop-at=impl` (the default) and walk away. The pipeline runs brainstorm → plan → execute, commits working code on the current branch, and returns to a clean stop either at `impl` completion or on a tier-C halt.

---

## File Structure

**Files created (new):**
- `commands/auto-plan.md` — single-stage shim that dispatches `auto-superpowers:writing-plans`
- `commands/auto-execute.md` — single-stage shim that dispatches `auto-superpowers:executing-plans`
- `commands/auto.md` — pipeline driver that chains brainstorm → plan → execute
- `tests/phase-2-smoke.sh` — structural checks for Phase 2 artifacts

**Files modified:**
- `skills/brainstorming/SKILL.md` — accept existing session dir (small patch)
- `skills/writing-plans/SKILL.md` — surgical rewrite
- `skills/executing-plans/SKILL.md` — surgical rewrite
- `skills/systematic-debugging/SKILL.md` — surgical rewrite (tier-C halt on 3+ failures)

**Files NOT modified in Phase 2 (explicitly out of scope):**
- `skills/verification-before-completion/SKILL.md` — upstream version ships unchanged
- `skills/test-driven-development/SKILL.md` — upstream version ships unchanged
- `skills/finishing-a-development-branch/SKILL.md` — Phase 3
- `skills/receiving-code-review/SKILL.md` — Phase 3
- `skills/requesting-code-review/SKILL.md` — Phase 3
- `skills/decision-proxy/SKILL.md` — already finished in Phase 1
- `skills/session-artifacts/SKILL.md` — already finished in Phase 1
- `skills/using-auto-superpowers/SKILL.md` — already finished in Phase 1
- `agents/decision-proxy.md` — already finished in Phase 1
- `hooks/session-start` — already finished in Phase 1
- `commands/auto-brainstorm.md` — already finished in Phase 1
- `tests/phase-1-smoke.sh` — leave as-is; Phase 2 adds its own smoke test alongside

---

## Task 1: Brainstorming — accept existing session directory

Phase 1 shipped brainstorming as a self-contained skill that always creates a new session directory. The `/auto` pipeline driver needs brainstorming to accept an existing session directory from its caller so all three pipeline stages share one `session-log.md`. This task adds a small patch to make step 2 conditional.

**Files:**
- Modify: `skills/brainstorming/SKILL.md`

- [ ] **Step 1: Read the current brainstorming checklist**

Run: `sed -n '22,40p' skills/brainstorming/SKILL.md`
Expected: shows the Checklist section with step 2 "Create session directory".

- [ ] **Step 2: Replace step 2 of the checklist to be conditional**

Use Edit to replace:
```
2. **Create session directory** — `docs/auto-superpowers/sessions/<YYYY-MM-DD-HHMM-slug>/` (follow slug rules in `skills/session-artifacts/SKILL.md`)
```
with:
```
2. **Create or reuse session directory** — If the caller passed an existing session directory path (the `/auto` pipeline driver does this), reuse it and skip creation. Otherwise create `docs/auto-superpowers/sessions/<YYYY-MM-DD-HHMM-slug>/` (follow slug rules in `skills/session-artifacts/SKILL.md`). Detect a pipeline-provided session dir by looking for `SESSION_DIR:` followed by a path in the input prompt, or by checking for an existing `session-log.md` in a directory path the caller named explicitly.
```

- [ ] **Step 3: Update the "Write session-log.md header" step to be append-safe**

Use Edit to replace:
```
3. **Write session-log.md header** — task, stop-at, persona skills detected (use `Skill` tool listing to populate)
```
with:
```
3. **Write or extend session-log.md header** — If `session-log.md` does not yet exist in the session dir, write the full header (task, stop-at, persona skills detected — use `Skill` tool listing to populate). If it already exists (pipeline mode), append a `## Phase: brainstorming` section marker instead; do NOT rewrite the file header, the pipeline driver owned it.
```

- [ ] **Step 4: Verify no other step assumes a new session dir**

Run: `grep -nE '(new session|create.*directory|empty session-log)' skills/brainstorming/SKILL.md`
Expected: no matches other than the updated step 2 and 3 lines.

- [ ] **Step 5: Verify fence balance**

Run: `awk '/^```/{c++} END{print c}' skills/brainstorming/SKILL.md`
Expected: output is an even number.

- [ ] **Step 6: Commit**

```bash
git add skills/brainstorming/SKILL.md
git commit -m "auto-superpowers: brainstorming accepts existing session dir

Phase 1 shipped brainstorming as self-contained. The /auto pipeline
driver in Phase 2 needs the skill to accept an existing session dir
from its caller so all three stages share one session-log.md. Step 2
is now conditional: create new if no caller-provided dir, reuse if
passed in. Step 3 is append-safe: write full header only if log does
not exist, otherwise append a phase marker."
```

---

## Task 2: Surgical rewrite of writing-plans skill

Convert upstream writing-plans to the autonomous auto-superpowers version: write `plan.md` inside the current session directory (not `docs/superpowers/plans/`), accept an existing session dir, skip the interactive execution-handoff choice, and add the HARD-GATE against proceeding past a halted decision.

**Files:**
- Modify: `skills/writing-plans/SKILL.md`

- [ ] **Step 1: Read the current writing-plans skill**

Run: `wc -l skills/writing-plans/SKILL.md`
Expected: ~152 lines (upstream's version).

- [ ] **Step 2: Update the frontmatter description**

Use Edit to replace:
```
description: Use when you have a spec or requirements for a multi-step task, before touching code
```
with:
```
description: "Use when auto-superpowers writing-plans is invoked (via /auto-plan or /auto). Reads spec.md from the session directory and writes plan.md non-interactively, applying TDD granularity rules and committing the plan file. No interactive execution-handoff — the pipeline driver owns what happens next."
```

- [ ] **Step 3: Replace the Overview's announce line and Context note**

Use Edit to replace:
```
**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** This should be run in a dedicated worktree (created by brainstorming skill).

**Save plans to:** `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`
- (User preferences for plan location override this default)
```
with:
```
**Announce at start:** "I'm using the auto-superpowers:writing-plans skill to create the implementation plan."

**Context:** You are running inside the auto-superpowers plugin. Read `skills/using-auto-superpowers/SKILL.md`, `skills/session-artifacts/SKILL.md`, and `skills/decision-proxy/SKILL.md` before starting. The caller (a pipeline driver or a command shim) will provide the session directory path. Use it.

**Save plans to:** `<session-dir>/plan.md` (the session directory the caller provided, or the most recent session directory under `docs/auto-superpowers/sessions/` if the caller said "most recent"). Do NOT write to `docs/superpowers/plans/` — that is the upstream convention; auto-superpowers uses per-session directories.

<HARD-GATE>
Do NOT proceed if `<session-dir>/halted.md` exists. A prior stage halted on a tier-C decision and the user has not resumed. Return terse status reporting the halt and stop.
</HARD-GATE>
```

- [ ] **Step 4: Update the Plan Document Header example**

Use Edit to replace:
```
```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```
```
with:
```
```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use auto-superpowers:subagent-driven-development (or auto-superpowers:executing-plans) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

**Session:** `docs/auto-superpowers/sessions/<dir>/` — see [session-log.md](./session-log.md) for the spec and autonomous-decision transcript that produced this plan.

---
```
```

- [ ] **Step 5: Add plan-step confidence annotation to the Task Structure section**

Use Edit to replace:
```
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`
```
with:
```
### Task N: [Component Name]

**Tier:** [A | B | C] (A = mechanical, B = substantive, C = load-bearing — executing-plans uses this to decide when to dispatch the decision-proxy)

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`
```

- [ ] **Step 6: Replace the Execution Handoff section with an autonomous emit**

Use Edit to replace:
```
## Execution Handoff

After saving the plan, offer execution choice:

**"Plan complete and saved to `docs/superpowers/plans/<filename>.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?"**

**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:subagent-driven-development
- Fresh subagent per task + two-stage review

**If Inline Execution chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:executing-plans
- Batch execution with checkpoints for review
```
with:
```
## Execution Handoff (autonomous)

After saving the plan, do NOT offer a choice. Autonomous mode always defaults to subagent-driven execution. If for some reason the caller (pipeline driver) needs inline execution, it will say so in the input prompt; otherwise subagent-driven is the assumed execution shape.

Steps:

1. Append a `## Phase: writing-plans` section marker to `<session-dir>/session-log.md` if not already present.
2. For every meaningful planning decision (e.g., "split this into 8 tasks vs. 4", "put helpers in a new file vs. extend an existing one", "use pytest vs. unittest"), dispatch the decision-proxy and log the entry. Tier-A mechanical choices (function names, task numbering) are silent.
3. Write `<session-dir>/plan.md` with the tasks, the Plan Document Header, and per-task `Tier:` annotations.
4. Run the spec self-review loop from the upstream skill text below. Fix inline.
5. Check whether the session directory is gitignored (`git check-ignore -q <session-dir>`). If NOT gitignored, commit with:

   ```
   auto-superpowers: plan for <slug>

   Session: docs/auto-superpowers/sessions/<dir>/
   ```

   If IT IS gitignored, skip the commit and note "plan committed skipped (gitignored)" in the return status.
6. Emit terse status: session dir, plan path, decision count, any halts. Return. Do NOT invoke executing-plans, subagent-driven-development, or any other skill — the pipeline driver owns what happens next.
```

- [ ] **Step 7: Verify no interactive handoff language remains**

Run: `grep -nE '(Which approach|chosen|offer execution choice|your human partner)' skills/writing-plans/SKILL.md`
Expected: no matches.

- [ ] **Step 8: Verify fence balance**

Run: `awk '/^```/{c++} END{print c}' skills/writing-plans/SKILL.md`
Expected: even number.

- [ ] **Step 9: Commit**

```bash
git add skills/writing-plans/SKILL.md
git commit -m "auto-superpowers: surgical rewrite writing-plans for autonomous mode

Replace interactive execution-handoff choice with an autonomous emit.
Write plan.md into the session directory instead of docs/superpowers/
plans/. Add per-task [A|B|C] tier annotation so executing-plans knows
which steps warrant decision-proxy dispatches. Add HARD-GATE against
proceeding if halted.md exists in the session dir. Honor the gitignore-
aware commit rule."
```

---

## Task 3: Surgical rewrite of executing-plans skill

Convert upstream executing-plans to the autonomous version: tier-aware concerns checkpoint, tier-aware blocker handling, verification gate before each plan step, integration with systematic-debugging's 3+ failures halt.

**Files:**
- Modify: `skills/executing-plans/SKILL.md`

- [ ] **Step 1: Read the current executing-plans skill**

Run: `wc -l skills/executing-plans/SKILL.md`
Expected: ~71 lines (upstream's version).

- [ ] **Step 2: Update the frontmatter description**

Use Edit to replace:
```
description: Use when you have a written implementation plan to execute in a separate session with review checkpoints
```
with:
```
description: "Use when auto-superpowers executing-plans is invoked (via /auto-execute or /auto). Runs an implementation plan non-interactively with tier-aware proxy dispatches, verification gates, and halt-on-unresolved-tier-C behavior."
```

- [ ] **Step 3: Replace the Overview section**

Use Edit to replace:
```
## Overview

Load plan, review critically, execute all tasks, report when complete.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

**Note:** Tell your human partner that Superpowers works much better with access to subagents. The quality of its work will be significantly higher if run on a platform with subagent support (such as Claude Code or Codex). If subagents are available, use superpowers:subagent-driven-development instead of this skill.
```
with:
```
## Overview

Load plan, self-check against repo state, execute all tasks non-interactively with verification gates, halt on unresolved tier-C events, return when complete.

**Announce at start:** "I'm using the auto-superpowers:executing-plans skill to implement this plan."

**Context:** You are running inside the auto-superpowers plugin. Read `skills/using-auto-superpowers/SKILL.md`, `skills/session-artifacts/SKILL.md`, and `skills/decision-proxy/SKILL.md` before starting. The caller (the pipeline driver or a command shim) will name the session directory. Use it.

<HARD-GATE>
Do NOT proceed if `<session-dir>/halted.md` exists. A prior stage halted on a tier-C decision and the user has not resumed. Return terse status reporting the halt and stop.
</HARD-GATE>

Autonomous mode assumes subagent-driven execution when subagents are available. If you cannot dispatch subagents, fall back to inline execution but still honor all tier rules and verification gates.
```

- [ ] **Step 4: Replace "The Process" section**

Use Edit to replace:
```
## The Process

### Step 1: Load and Review Plan
1. Read plan file
2. Review critically - identify any questions or concerns about the plan
3. If concerns: Raise them with your human partner before starting
4. If no concerns: Create TodoWrite and proceed

### Step 2: Execute Tasks

For each task:
1. Mark as in_progress
2. Follow each step exactly (plan has bite-sized steps)
3. Run verifications as specified
4. Mark as completed

### Step 3: Complete Development

After all tasks complete and verified:
- Announce: "I'm using the finishing-a-development-branch skill to complete this work."
- **REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch
- Follow that skill to verify tests, present options, execute choice
```
with:
```
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
```

- [ ] **Step 5: Replace "When to Stop and Ask for Help" with tier-aware handling**

Use Edit to replace:
```
## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly

**Ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner updates the plan based on your feedback
- Fundamental approach needs rethinking

**Don't force through blockers** - stop and ask.
```
with:
```
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
```

- [ ] **Step 6: Update the Integration section**

Use Edit to replace:
```
## Integration

**Required workflow skills:**
- **superpowers:using-git-worktrees** - REQUIRED: Set up isolated workspace before starting
- **superpowers:writing-plans** - Creates the plan this skill executes
- **superpowers:finishing-a-development-branch** - Complete development after all tasks
```
with:
```
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
```

- [ ] **Step 7: Remove the "Remember" line about main/master consent (Phase 2 assumes the caller set up the workspace)**

Use Edit to replace:
```
## Remember
- Review plan critically first
- Follow plan steps exactly
- Don't skip verifications
- Reference skills when plan says to
- Stop when blocked, don't guess
- Never start implementation on main/master branch without explicit user consent
```
with:
```
## Remember
- Review plan critically against repo state first
- Follow plan steps exactly
- Never skip verification gates
- Reference sibling skills when the plan says to
- Halt to `halted.md` on tier-C; do not guess
- Never force-push, never modify shared branches, never skip git hooks (these are refused outright)
- The caller (pipeline driver or worktree-setup sub-skill) is responsible for ensuring you are NOT on main/master before implementation begins; the task's git state is part of the Step 1 self-check
```

- [ ] **Step 8: Verify no lingering interactive language**

Run: `grep -nE '(ask.*human partner|your human partner|raise.*concerns.*partner|present.*options)' skills/executing-plans/SKILL.md`
Expected: no matches.

- [ ] **Step 9: Verify fence balance**

Run: `awk '/^```/{c++} END{print c}' skills/executing-plans/SKILL.md`
Expected: even number.

- [ ] **Step 10: Commit**

```bash
git add skills/executing-plans/SKILL.md
git commit -m "auto-superpowers: surgical rewrite executing-plans for autonomous mode

Replace interactive 'raise concerns with partner' checkpoint with
tier-aware self-check and decision-proxy dispatch. Replace 'stop and
ask' blocker handling with tier-A/B/C routing. Add verification gates
before each plan step. Integrate systematic-debugging 3+ failures
halt. Update integration section to point at auto-superpowers siblings.
Phase 2 stops at 'impl' unconditionally; pr/merged are Phase 3."
```

---

## Task 4: Surgical rewrite of systematic-debugging skill

Convert upstream systematic-debugging to the autonomous version: the 3+ failures rule's action changes from "discuss with human partner" to "write halted.md with fix history and hypothesis, stop." Add a hypothesis confidence check that escalates to tier-C halt when Phase 1 investigation yields no strong hypothesis.

**Files:**
- Modify: `skills/systematic-debugging/SKILL.md`

- [ ] **Step 1: Read the current skill**

Run: `wc -l skills/systematic-debugging/SKILL.md`
Expected: ~297 lines.

- [ ] **Step 2: Update frontmatter description**

Use Edit to replace:
```
description: Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes
```
with:
```
description: "Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes. Autonomous variant: 3+ failures halts to halted.md instead of asking the user; Phase 1 investigation with no strong hypothesis is tier-C."
```

- [ ] **Step 3: Replace the "5. If 3+ Fixes Failed: Question Architecture" block**

Use Edit to replace:
```
5. **If 3+ Fixes Failed: Question Architecture**

   **Pattern indicating architectural problem:**
   - Each fix reveals new shared state/coupling/problem in different place
   - Fixes require "massive refactoring" to implement
   - Each fix creates new symptoms elsewhere

   **STOP and question fundamentals:**
   - Is this pattern fundamentally sound?
   - Are we "sticking with it through sheer inertia"?
   - Should we refactor architecture vs. continue fixing symptoms?

   **Discuss with your human partner before attempting more fixes**

   This is NOT a failed hypothesis - this is a wrong architecture.
```
with:
```
5. **If 3+ Fixes Failed: Halt to halted.md**

   **Pattern indicating architectural problem:**
   - Each fix reveals new shared state/coupling/problem in different place
   - Fixes require "massive refactoring" to implement
   - Each fix creates new symptoms elsewhere

   **HALT:** write `<session-dir>/halted.md` with:
   - The original failing test and its output
   - The list of fix attempts tried, each with a one-line description and why it failed
   - The proxy's tentative architectural hypothesis (dispatch the `decision-proxy` with `tier: C` and include the fix history as context)
   - The question: "Is this pattern fundamentally sound, or is a deeper refactor required?"

   STOP. Do NOT attempt fix #4. Do NOT silently mask the failure. The user will resume with `/auto --resume <session-dir>` after reading `halted.md`.

   This is NOT a failed hypothesis — this is a wrong architecture, and autonomous mode must defer to the user for architectural pivots.
```

- [ ] **Step 4: Add a "Hypothesis confidence check" at the end of Phase 1**

Use Edit to replace (this is the end of Phase 1's section, right before `### Phase 2: Pattern Analysis`):
```
5. **Trace Data Flow**

   **WHEN error is deep in call stack:**

   See `root-cause-tracing.md` in this directory for the complete backward tracing technique.

   **Quick version:**
   - Where does bad value originate?
   - What called this with bad value?
   - Keep tracing up until you find the source
   - Fix at source, not at symptom

### Phase 2: Pattern Analysis
```
with:
```
5. **Trace Data Flow**

   **WHEN error is deep in call stack:**

   See `root-cause-tracing.md` in this directory for the complete backward tracing technique.

   **Quick version:**
   - Where does bad value originate?
   - What called this with bad value?
   - Keep tracing up until you find the source
   - Fix at source, not at symptom

6. **Hypothesis confidence check (tier-C gate)**

   After completing steps 1–5, assess: do I have a strong hypothesis about the root cause?

   - **Strong hypothesis** (high confidence, specific file/line/mechanism): proceed to Phase 2.
   - **Weak or no hypothesis** (the symptoms are clear but the cause is diffuse or cross-cutting): this is a tier-C investigation. Dispatch `decision-proxy` with `tier: C` and the full evidence trail. If the proxy returns high-confidence, proceed. Otherwise write `halted.md` naming the symptom, the evidence gathered, and the proxy's tentative direction (if any). STOP.

   This prevents the autonomous agent from "powering through" a mystery by guessing — which is exactly the anti-pattern systematic debugging exists to prevent.

### Phase 2: Pattern Analysis
```

- [ ] **Step 5: Update the "your human partner's Signals" section header to be autonomous-friendly**

Use Edit to replace:
```
## your human partner's Signals You're Doing It Wrong

**Watch for these redirections:**
- "Is that not happening?" - You assumed without verifying
- "Will it show us...?" - You should have added evidence gathering
- "Stop guessing" - You're proposing fixes without understanding
- "Ultrathink this" - Question fundamentals, not just symptoms
- "We're stuck?" (frustrated) - Your approach isn't working

**When you see these:** STOP. Return to Phase 1.
```
with:
```
## Self-signals you're doing it wrong

**Watch for these patterns in your own process:**
- You assumed a behavior without verifying it empirically
- You proposed a fix without adding evidence gathering first
- You're reaching for a fix without a specific hypothesis
- You're treating symptoms, not root cause
- You're iterating on fixes without new information between attempts

**When you catch yourself:** STOP. Return to Phase 1. If you cannot get unstuck without guidance, write `halted.md` and halt rather than guess.

(The autonomous version of this skill cannot ask the user mid-run; the halt path replaces the "ask partner" escape hatch.)
```

- [ ] **Step 6: Verify no lingering "ask your human partner" phrases in fix-loop guidance**

Run: `grep -nE '(human partner|discuss with.*partner|ask.*partner)' skills/systematic-debugging/SKILL.md`
Expected: matches only in comparison/historical context, not as an action instruction. If any remain as instructions, edit them out individually.

- [ ] **Step 7: Verify fence balance**

Run: `awk '/^```/{c++} END{print c}' skills/systematic-debugging/SKILL.md`
Expected: even number.

- [ ] **Step 8: Commit**

```bash
git add skills/systematic-debugging/SKILL.md
git commit -m "auto-superpowers: surgical rewrite systematic-debugging for autonomous halt

The 3+ failures rule now writes halted.md with fix history and the
decision-proxy's tentative architectural hypothesis, then stops, instead
of 'discuss with your human partner.' Phase 1 investigation gains a
hypothesis confidence check: if no strong hypothesis emerges, that is
tier-C and routes through the decision-proxy before possibly halting.
The 'your human partner's signals' section becomes a self-signals
section for autonomous mode."
```

---

## Task 5: Add /auto-plan command

Thin shim that dispatches `auto-superpowers:writing-plans` with an input spec.

**Files:**
- Create: `commands/auto-plan.md`

- [ ] **Step 1: Create the command file**

Write `commands/auto-plan.md` with exactly this content:

```markdown
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
```

- [ ] **Step 2: Verify frontmatter**

Run: `head -3 commands/auto-plan.md`
Expected: shows the `description:` frontmatter.

- [ ] **Step 3: Commit**

```bash
git add commands/auto-plan.md
git commit -m "auto-superpowers: add /auto-plan command

Thin shim that dispatches auto-superpowers:writing-plans. Accepts
--spec and --session flags, otherwise falls back to the most recent
session directory."
```

---

## Task 6: Add /auto-execute command

Thin shim that dispatches `auto-superpowers:executing-plans` with an input plan.

**Files:**
- Create: `commands/auto-execute.md`

- [ ] **Step 1: Create the command file**

Write `commands/auto-execute.md` with exactly this content:

```markdown
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
```

- [ ] **Step 2: Verify frontmatter**

Run: `head -3 commands/auto-execute.md`
Expected: shows the `description:` frontmatter.

- [ ] **Step 3: Commit**

```bash
git add commands/auto-execute.md
git commit -m "auto-superpowers: add /auto-execute command

Thin shim that dispatches auto-superpowers:executing-plans. Accepts
--plan and --session flags, otherwise falls back to the most recent
session directory. Pre-flight check refuses to run on main/master
since standalone /auto-execute does not set up worktrees."
```

---

## Task 7: Add /auto pipeline driver command

The main happy path. `/auto "<task>"` creates the shared session directory and chains brainstorm → plan → execute in one command. Honors `--stop-at spec|plan|impl` (default: `impl`).

**Files:**
- Create: `commands/auto.md`

- [ ] **Step 1: Create the command file**

Write `commands/auto.md` with exactly this content (outer fence uses four backticks because the content contains inner code fences):

````markdown
---
description: "Run the full auto-superpowers pipeline (brainstorm → plan → execute) in one walk-away session. Creates a shared session directory, chains all three stages, honors --stop-at."
---

You have been invoked via the `/auto` command. The user has walked away and expects you to run the full spec → plan → execute pipeline non-interactively.

**Parse arguments from `$ARGUMENTS`:**

- First positional argument (or everything before any `--flag`) is the task description. If empty, emit a usage error and stop.
- `--stop-at <spec|plan|impl>` — default `impl`. Where the pipeline halts on success.
- `--docs-root <path>` — override the default `docs/auto-superpowers/`.
- `--persona <skill[,skill...]>` — force specific skills to be the primary persona sources (overrides auto-detection).
- `--resume <session-dir>` — pick up a previously halted session from its `halted.md`. Skip stages already completed in that session.
- `--commit-session-log` / `--no-commit-session-log` — override the default gitignore behavior for this session's artifacts.

**Pipeline steps:**

1. **Parse + pre-flight.** Verify the task description is present. Verify you are NOT on `main`/`master` — if you are, halt with a one-line error telling the user to create a worktree or feature branch first.

2. **Create (or resume) session directory.** Default path: `docs/auto-superpowers/sessions/<YYYY-MM-DD-HHMM-slug>/` following the slug rules in `skills/session-artifacts/SKILL.md`. If `--resume <session-dir>` was provided, reuse that directory.

3. **Write (or extend) session-log.md header.** If fresh, write the full header with task, stop-at, and detected persona skills (use `Skill` tool listing). If resuming, append a `## Phase: pipeline-resume` marker and note the resume time.

4. **Stage 1 — Brainstorming.** Invoke `auto-superpowers:brainstorming` via the `Skill` tool with this input prompt format:

   ```
   SESSION_DIR: <path>
   TASK: <task description>
   STOP_AT: <stop-at value>
   PERSONAS: <comma-separated list, or "auto">
   ```

   When the skill returns:
   - If `<session-dir>/halted.md` exists → write pipeline status noting the halt, STOP.
   - If `--stop-at spec` → emit terse status (brainstorm complete), STOP.
   - Otherwise, continue to Stage 2.

5. **Stage 2 — Writing plans.** Invoke `auto-superpowers:writing-plans` with this input prompt format:

   ```
   SESSION_DIR: <path>
   SPEC: <session-dir>/spec.md
   ```

   When the skill returns:
   - If `halted.md` exists → STOP.
   - If `--stop-at plan` → emit terse status (plan complete), STOP.
   - Otherwise, continue to Stage 3.

6. **Stage 3 — Executing plans.** Invoke `auto-superpowers:executing-plans` with this input prompt format:

   ```
   SESSION_DIR: <path>
   PLAN: <session-dir>/plan.md
   ```

   When the skill returns:
   - If `halted.md` exists → STOP.
   - Otherwise (stop-at=impl, default) → emit terse status with the branch name, HEAD sha, tasks completed, any halts.

7. **Emit terse pipeline status** in this shape:

   ```
   auto-superpowers> Pipeline complete (or halted at stage N)
                     Session: docs/auto-superpowers/sessions/<dir>/
                     Stop-at: <value>
                     Stages completed: [brainstorm, plan, execute]
                     Branch: <branch name>
                     HEAD: <sha>
                     Halts: <count> (see halted.md if > 0)
                     Run /calibrate-proxy to review decisions (Phase 3).
   ```

**HARD-GATES:**

- Do NOT skip stages. Each stage must complete (or halt) before the next begins.
- Do NOT combine stages.
- Do NOT proceed past a halt. If any stage writes `halted.md`, the pipeline stops immediately. The user resumes by reading `halted.md`, providing an answer, and invoking `/auto --resume <session-dir>`.
- Do NOT invoke `finishing-a-development-branch`, `subagent-driven-development`, or any sibling skill directly — each stage's skill handles its own sub-skill dispatch.
- Do NOT modify files outside the session directory and whatever the plan says to modify. The pipeline driver is a thin orchestrator, not an implementer.

**Co-install note:** This command is `/auto` in the `auto-superpowers` plugin. If upstream `superpowers` is also installed, its interactive flow uses different commands (`/brainstorm`, `/write-plan`, `/execute-plan`). There is no name collision.
````

- [ ] **Step 2: Verify frontmatter**

Run: `head -3 commands/auto.md`
Expected: shows the `description:` frontmatter.

- [ ] **Step 3: Verify fence balance**

Run: `awk '/^```/{c++} END{print c}' commands/auto.md`
Expected: even number (the outer fence is four backticks so it does not affect this count).

- [ ] **Step 4: Commit**

```bash
git add commands/auto.md
git commit -m "auto-superpowers: add /auto pipeline driver command

Chains brainstorm → plan → execute in one walk-away session. Creates
a shared session directory, passes it to each stage so they share a
session-log.md, honors --stop-at (default impl), supports --resume
for halted sessions. HARD-GATES prevent skipping stages or combining
them."
```

---

## Task 8: Phase 2 smoke test

Structural checks for the new Phase 2 artifacts, mirroring the Phase 1 smoke test pattern. Extends coverage without modifying Phase 1's test.

**Files:**
- Create: `tests/phase-2-smoke.sh`

- [ ] **Step 1: Create the script**

Write `tests/phase-2-smoke.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# auto-superpowers Phase 2 smoke test
#
# Structural checks for the full pipeline MVP. Verifies that:
#   - The three surgically-rewritten skills no longer contain interactive
#     gates
#   - The three new commands exist with frontmatter
#   - The brainstorming skill accepts an existing session dir
#   - systematic-debugging's 3+ failures rule writes halted.md
#
# Like Phase 1's smoke test, this does NOT run Claude — it only checks
# the filesystem state. End-to-end verification is a separate manual step.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

step() {
    printf '\n\033[1;34m[STEP]\033[0m %s\n' "$1"
}

check() {
    if eval "$1"; then
        printf '  \033[1;32m✓\033[0m %s\n' "$2"
    else
        printf '  \033[1;31m✗\033[0m %s\n' "$2"
        exit 1
    fi
}

step "1. Phase 2 commands exist"
for cmd in auto auto-plan auto-execute; do
    check "test -f '${PLUGIN_ROOT}/commands/${cmd}.md'" "commands/${cmd}.md exists"
    check "head -1 '${PLUGIN_ROOT}/commands/${cmd}.md' | grep -q '^---$'" "commands/${cmd}.md has frontmatter"
done

step "2. writing-plans surgically rewritten"
check "grep -q 'auto-superpowers:writing-plans' '${PLUGIN_ROOT}/skills/writing-plans/SKILL.md'" "writing-plans announces as auto-superpowers:writing-plans"
check "! grep -qE 'Which approach' '${PLUGIN_ROOT}/skills/writing-plans/SKILL.md'" "interactive 'Which approach' choice is gone"
check "grep -q 'session-dir' '${PLUGIN_ROOT}/skills/writing-plans/SKILL.md'" "writing-plans references session directory"
check "grep -qE '<HARD-GATE>' '${PLUGIN_ROOT}/skills/writing-plans/SKILL.md'" "writing-plans has HARD-GATE against halted.md"

step "3. executing-plans surgically rewritten"
check "grep -q 'auto-superpowers:executing-plans' '${PLUGIN_ROOT}/skills/executing-plans/SKILL.md'" "executing-plans announces as auto-superpowers:executing-plans"
check "! grep -q 'Raise them with your human partner' '${PLUGIN_ROOT}/skills/executing-plans/SKILL.md'" "interactive 'raise concerns with partner' is gone"
check "grep -q 'decision-proxy' '${PLUGIN_ROOT}/skills/executing-plans/SKILL.md'" "executing-plans references decision-proxy"
check "grep -q 'halted.md' '${PLUGIN_ROOT}/skills/executing-plans/SKILL.md'" "executing-plans references halted.md"
check "grep -q 'verification gate' '${PLUGIN_ROOT}/skills/executing-plans/SKILL.md'" "executing-plans has verification gate"

step "4. systematic-debugging surgically rewritten"
check "grep -q 'halted.md' '${PLUGIN_ROOT}/skills/systematic-debugging/SKILL.md'" "systematic-debugging references halted.md"
check "! grep -q 'Discuss with your human partner before attempting' '${PLUGIN_ROOT}/skills/systematic-debugging/SKILL.md'" "interactive '3+ failures: discuss with partner' is gone"
check "grep -q 'Hypothesis confidence check' '${PLUGIN_ROOT}/skills/systematic-debugging/SKILL.md'" "hypothesis confidence check added"

step "5. brainstorming accepts existing session dir"
check "grep -q 'existing session directory' '${PLUGIN_ROOT}/skills/brainstorming/SKILL.md'" "brainstorming mentions existing session directory"
check "grep -q 'pipeline-provided' '${PLUGIN_ROOT}/skills/brainstorming/SKILL.md' || grep -q 'pipeline mode' '${PLUGIN_ROOT}/skills/brainstorming/SKILL.md'" "brainstorming mentions pipeline mode"

step "6. Phase 1 smoke test still passes"
check "bash '${SCRIPT_DIR}/phase-1-smoke.sh' >/dev/null 2>&1" "phase-1-smoke.sh still green"

printf '\n\033[1;32m[OK]\033[0m Phase 2 structural checks passed.\n'
printf '\n'
printf 'Next, manually run /auto inside a Claude Code session with this\n'
printf 'plugin installed. Expected outcome:\n'
printf '  - /auto "some task" creates a shared session dir\n'
printf '  - session-log.md has ## Phase: brainstorming, ## Phase: writing-plans,\n'
printf '    and ## Phase: executing-plans section markers\n'
printf '  - spec.md, plan.md, and real code commits are all produced\n'
printf '  - Tests pass on the plan-executed code\n'
printf '  - If any tier-C decision halts, halted.md exists and the pipeline stops\n'
printf '  - --stop-at spec / plan / impl controls where the pipeline ends\n'
```

- [ ] **Step 2: Make the script executable**

Run: `chmod +x tests/phase-2-smoke.sh`

- [ ] **Step 3: Run the smoke test**

Run: `tests/phase-2-smoke.sh`
Expected: all steps print ✓ and the final "[OK] Phase 2 structural checks passed." appears. Phase 1 smoke test is re-run as step 6 and must still pass.

- [ ] **Step 4: Commit**

```bash
git add tests/phase-2-smoke.sh
git commit -m "auto-superpowers: add Phase 2 smoke test

Structural checks for the full-pipeline MVP. Verifies the three new
commands exist with frontmatter, the three surgically-rewritten skills
no longer contain interactive gates, brainstorming accepts an existing
session dir, systematic-debugging halts to halted.md on 3+ failures.
Re-runs Phase 1 smoke test as step 6 to guard against regressions."
```

---

## Definition of Done — Phase 2

Phase 2 is complete when all of the following are true:

1. `tests/phase-2-smoke.sh` exits 0 (which also re-runs Phase 1's smoke test).
2. A manual `/auto "build a CLI tool that counts words per line in a file"` invocation in a fresh Claude Code session (with this plugin installed and `/reload-plugins` done) produces:
   - A session directory with `session-log.md`, `spec.md`, `plan.md`, and real code + test commits on the current branch
   - `session-log.md` contains `## Phase: brainstorming`, `## Phase: writing-plans`, and `## Phase: executing-plans` markers in order
   - At least one tier-B decision-proxy entry per phase
   - A passing test suite on the implemented code
   - A terse pipeline status at the end with the branch name, HEAD sha, and stage summary
3. A manual `/auto "change the database schema to add a NOT NULL column to a 10M-row table" --stop-at spec` invocation (a tier-C-heavy task) either:
   - (a) Writes `spec.md` with tier-C decisions marked auto-proceed by the proxy, OR
   - (b) Halts with `halted.md` describing the tier-C event (expected behavior for schema migrations)
4. No interactive prompts appear during either run.

---

## Open items explicitly deferred to Phase 3

- `/calibrate-proxy` — post-session review loop that edits `user-preferences.md`
- `finishing-a-development-branch` surgical rewrite — enables `--stop-at=pr` and `--stop-at=merged`
- `receiving-code-review` / `requesting-code-review` edits
- Session-start hook co-install coordination (dual-preamble fix)
- README rewrite (still upstream's content)
- CLAUDE.md rewrite (still upstream's contributor guidelines)
- `.opencode/plugins/superpowers.js` entry point rename

---

## Self-review checklist

Before starting implementation, the operator should confirm:

- [ ] The Phase 2 file structure above matches the spec's "Phase 2" scope in the design spec's "Implementation phasing" section
- [ ] Every task has a commit step
- [ ] Every task's verification step is a concrete command, not "verify it works"
- [ ] No task references a function, method, or type not defined in this plan or the spec
- [ ] Task 1 is listed BEFORE Task 7 because /auto depends on brainstorming accepting an existing session dir
- [ ] Tasks 2, 3, 4 are independent of each other and can run in any order among themselves
- [ ] Task 8 (smoke test) is last because it verifies all prior work
