---
name: writing-plans
description: "Use when auto-superpowers writing-plans is invoked (via /auto-plan or /auto). Reads spec.md from the session directory and writes plan.md non-interactively, applying TDD granularity rules and committing the plan file. No interactive execution-handoff — the pipeline driver owns what happens next."
---

# Writing Plans

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the auto-superpowers:writing-plans skill to create the implementation plan."

**Context:** You are running inside the auto-superpowers plugin. Read `skills/using-auto-superpowers/SKILL.md`, `skills/session-artifacts/SKILL.md`, and `skills/decision-proxy/SKILL.md` before starting. The caller (a pipeline driver or a command shim) will provide the session directory path. Use it.

**Input parsing:** Look for these sentinels on their own lines in the input prompt:

- `SESSION_DIR: <path>` — the session directory to write into.
- `SPEC: <path>` — the spec to read. If absent, default to `<session-dir>/spec.md`.

If no `SESSION_DIR:` line is present, fall back to the most recent directory under `docs/auto-superpowers/sessions/`. If no session directory exists at all, emit a one-line error and stop.

**Save plans to:** `<session-dir>/plan.md` (the session directory the caller provided, or the most recent session directory under `docs/auto-superpowers/sessions/` if the caller said "most recent"). Do NOT write to `docs/superpowers/plans/` — that is the upstream convention; auto-superpowers uses per-session directories.

<HARD-GATE>
Do NOT proceed if `<session-dir>/halted.md` exists. A prior stage halted on a tier-C decision and the user has not resumed. Return terse status reporting the halt and stop.
</HARD-GATE>

## Scope Check

If the spec covers multiple independent subsystems, it should have been broken into sub-project specs during brainstorming. If it wasn't, suggest breaking this into separate plans — one per subsystem. Each plan should produce working, testable software on its own.

## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure - but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use auto-superpowers:subagent-driven-development (or auto-superpowers:executing-plans) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

**Session:** `docs/auto-superpowers/sessions/<dir>/` — see [session-log.md](./session-log.md) for the spec and autonomous-decision transcript that produced this plan.

---
```

## Task Structure

````markdown
### Task N: [Component Name]

**Tier:** [A | B | C] (A = mechanical, B = substantive, C = load-bearing — executing-plans uses this to decide when to dispatch the decision-proxy)

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the engineer may be reading tasks out of order)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

## Remember
- Exact file paths always
- Complete code in every step — if a step changes code, show the code
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits

## Self-Review

After writing the complete plan, look at the spec with fresh eyes and check the plan against it. This is a checklist you run yourself — not a subagent dispatch.

**1. Spec coverage:** Skim each section/requirement in the spec. Can you point to a task that implements it? List any gaps.

**2. Placeholder scan:** Search your plan for red flags — any of the patterns from the "No Placeholders" section above. Fix them.

**3. Type consistency:** Do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

If you find issues, fix them inline. No need to re-review — just fix and move on. If you find a spec requirement with no task, add the task.

## Execution Handoff (autonomous)

After saving the plan, do NOT offer a choice. Autonomous mode always defaults to subagent-driven execution. If for some reason the caller (pipeline driver) needs inline execution, it will say so in the input prompt; otherwise subagent-driven is the assumed execution shape.

Steps:

1. Append a `## Phase: writing-plans` section marker to `<session-dir>/session-log.md` if not already present.
2. For every meaningful planning decision (e.g., "split this into 8 tasks vs. 4", "put helpers in a new file vs. extend an existing one", "use pytest vs. unittest"), dispatch the decision-proxy and log the entry. Tier-A mechanical choices (function names, task numbering) are silent.
3. Write `<session-dir>/plan.md` with the tasks, the Plan Document Header, and per-task `Tier:` annotations.
4. Run the Self-Review checklist above. Fix inline.
5. Check whether the session directory is gitignored: run `git check-ignore -q <session-dir>`. Exit 0 means gitignored; exit 1 means tracked. If tracked (exit 1), `git add <session-dir>/plan.md` and commit with:

   ```
   auto-superpowers: plan for <slug>

   Session: docs/auto-superpowers/sessions/<dir>/
   ```

   If gitignored (exit 0), skip the commit and note "plan commit skipped (gitignored)" in the return status. Do NOT use `git add -f` to force-commit a gitignored path — respect the user's gitignore.
6. Emit terse status: session dir, plan path, decision count, any halts. Return. Do NOT invoke executing-plans, subagent-driven-development, or any other skill — the pipeline driver owns what happens next.
