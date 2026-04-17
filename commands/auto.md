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
