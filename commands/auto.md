---
description: "Run the full auto-superpowers pipeline (brainstorm → plan → execute) in one walk-away session. Creates a shared session directory, chains all three stages, honors --stop-at."
---

You have been invoked via the `/auto` command. The user has walked away and expects you to run the full spec → plan → execute pipeline non-interactively.

**Parse arguments from `$ARGUMENTS`:**

- First positional argument (or everything before any `--flag`) is the task description. If empty, emit a usage error and stop.
- `--stop-at <spec|plan|impl|pr|merged>` — default `impl`. Where the pipeline halts on success.
- `--persona <skill[,skill...]>` — force specific skills to be the primary persona sources during Stage 1 (brainstorming). Personas are brainstorming-only; writing-plans and executing-plans do not take a persona parameter.
- `--resume <session-dir>` — pick up a previously halted session. Before invoking Stage 1, read `<session-dir>/halted.md` into context, then archive it by renaming to `halted-resolved-<YYYY-MM-DD-HHMM>.md` so downstream HARD-GATEs do not trigger on the stale halt file. The user is expected to have addressed the halt's question in `session-log.md` or `user-preferences.md` before resuming.

**Pipeline steps:**

1. **Parse + pre-flight.** Verify the task description is present. Then check the current branch:

   **If on `main` or `master`:**
   Create a worktree automatically so the pipeline runs on an isolated feature branch.

   a. Derive the branch name from the session slug: `auto/<slug>` (e.g., `auto/build-a-login-flow-with-email-password`).
   b. Find the worktree directory using this priority:
      - If `.worktrees/` exists in the project root: use it.
      - Else if `worktrees/` exists: use it.
      - Else if CLAUDE.md specifies a worktree directory: use it.
      - Otherwise: create `.worktrees/` in the project root.
   c. If the chosen directory is project-local (`.worktrees/` or `worktrees/`), verify it is gitignored: `git check-ignore -q <dir>`. If NOT ignored, add it to `.gitignore` and commit the change.
   d. Create the worktree: `git worktree add <dir>/<branch-name> -b <branch-name>`.
   e. If worktree creation fails (e.g., branch already exists, git error), log the error to session-log.md and STOP the pipeline. The user can `git worktree remove` the stale worktree and retry.
   f. Log the worktree path and branch name to session-log.md.
   g. All subsequent pipeline steps run in the worktree context. Use absolute paths or `cd` to the worktree before invoking each stage.

   **If NOT on `main`/`master`:**
   Proceed as before — no worktree needed, the user is already on a feature branch.

2. **Create (or resume) session directory.** Default path: `docs/auto-superpowers/sessions/<YYYY-MM-DD-HHMM-slug>/` following the slug rules in `skills/session-artifacts/SKILL.md`. If `--resume <session-dir>` was provided, reuse that directory AND archive any existing `halted.md` by `mv halted.md halted-resolved-<YYYY-MM-DD-HHMM>.md`. The stale halt file would otherwise block every downstream stage's HARD-GATE.

3. **Write (or extend) session-log.md header.** If fresh, write the full header with task, stop-at, and detected persona skills (use `Skill` tool listing). If resuming, append a `## Phase: pipeline-resume` marker, note the resume time, and record the archived-halt filename.

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
   - Otherwise, continue to Stage 4 (if `--stop-at` is `pr` or `merged`), or emit terse status.

6b. **Stage 4 — Finishing branch (--stop-at=pr or --stop-at=merged only).** If `--stop-at` is `pr` or `merged`, invoke `auto-superpowers:finishing-a-development-branch` via the `Skill` tool with this input prompt format:

   ```
   SESSION_DIR: <path>
   STOP_AT: <pr|merged>
   ```

   When the skill returns:
   - If it reports a PR URL → include it in the pipeline status.
   - If it reports an error (e.g., gh failure) → note the error in pipeline status, do NOT write halted.md.
   - If `--stop-at` is `impl` (the default) → skip this stage entirely.

7. **Emit terse pipeline status** in this shape:

   ```
   auto-superpowers> Pipeline complete (or halted at stage N)
                     Session: docs/auto-superpowers/sessions/<dir>/
                     Stop-at: <value>
                     Stages completed: [brainstorm, plan, execute(, finish)]
                     Branch: <branch name>
                     HEAD: <sha>
                     Worktree: <path or "n/a">
                     PR: <url or "n/a">
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
