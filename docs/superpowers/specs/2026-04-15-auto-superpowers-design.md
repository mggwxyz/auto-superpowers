# auto-superpowers — design spec

**Status:** draft
**Date:** 2026-04-15
**Author:** Michael Gilbertson (with Claude, via `superpowers:brainstorming`)

## Summary

`auto-superpowers` is a standalone Claude Code plugin derived from `superpowers`. It runs the same spec → plan → execute workflow, but autonomously: the user invokes one command and walks away. Every meaningful decision is captured in an auditable session log. A `decision-proxy` subagent answers in-flow questions by dispatching to whichever installed Claude skill best matches the question's domain, filtered by a user-preferences file. High-stakes decisions still halt with a resumable state, preserving the safety nets of upstream superpowers.

The plugin co-installs with upstream `superpowers` without conflicts: distinct skill namespace, distinct commands, distinct spec output directory, and a session-start hook that coordinates with upstream's preamble when both are present.

---

## Goals and non-goals

### Goals

- The user can invoke one command (`/auto <idea>`), walk away, and return to a finished artifact plus working code on a local branch.
- Every meaningful decision is visible in an audit trail: the question asked, the options considered, the answer given, who made the call (proxy vs. main agent), which skills informed the answer, and why.
- The plugin installs alongside upstream `superpowers` without conflicts. Users can switch between interactive (`/brainstorm`) and autonomous (`/auto`) per session.
- Over time, the decision-proxy gets better at representing the user via `user-preferences.md` plus a post-session calibration loop.
- Safety nets in high-stakes situations (3+ failed fixes, destructive operations, architectural pivots, security-sensitive choices) still halt with a resumable state, regardless of autonomous mode.

### Non-goals

- Not a replacement for upstream superpowers. If you want the interactive experience, use `/brainstorm` from upstream.
- No interactive mode within `auto-superpowers`. No `--interactive` flag. One plugin, one job.
- Not a remote autopilot. Runs in the Claude session the user starts. "Walk away" means "walk away from the laptop for an hour," not "run overnight on a server."
- Does not push code or merge to main by default. Default `--stop-at` is `impl`; shipping happens with explicit opt-in.
- Not a rewrite of upstream skills' philosophy. TDD, YAGNI, red/green, systematic debugging, and verification-before-completion stay as-is in spirit.

---

## Architecture overview

### Plugin layout

```
auto-superpowers/
├── skills/
│   └── auto-superpowers/
│       ├── using-auto-superpowers/SKILL.md          (entry preamble)
│       ├── brainstorming/SKILL.md                   (surgical rewrite)
│       ├── writing-plans/SKILL.md                   (surgical rewrite)
│       ├── executing-plans/SKILL.md                 (surgical rewrite)
│       ├── systematic-debugging/SKILL.md            (surgical rewrite: tier-C halt)
│       ├── finishing-a-development-branch/SKILL.md  (stop-at-aware)
│       ├── receiving-code-review/SKILL.md           (tier-aware)
│       ├── requesting-code-review/SKILL.md          (minor: feeds session-log)
│       ├── verification-before-completion/SKILL.md  (unchanged from upstream)
│       ├── test-driven-development/SKILL.md         (unchanged from upstream)
│       ├── decision-proxy/SKILL.md                  (NEW: routing guide)
│       └── session-artifacts/SKILL.md               (NEW: log format + layout)
├── agents/
│   └── decision-proxy.md                            (NEW subagent)
├── commands/
│   ├── auto.md
│   ├── auto-brainstorm.md
│   ├── auto-plan.md
│   ├── auto-execute.md
│   └── calibrate-proxy.md
└── hooks/
    └── session-start/                               (co-install aware)
```

(The plugin ships no `docs/` directory of its own — plugin-repo docs live at the repo root, separate from user runtime output. User runtime output lives under the *user's* `docs/auto-superpowers/`, described in the "Session artifacts and file layout" section.)

### Core new primitives (added on top of surgical edits)

1. **`decision-proxy` subagent.** Dispatched by brainstorming/planning/execution skills per meaningful decision. Answers by invoking installed Claude skills for domain expertise, applying `user-preferences.md` as an override filter.
2. **`user-preferences.md`.** Optional. Project-local by default at `docs/auto-superpowers/user-preferences.md`. A global fallback at `~/.auto-superpowers/user-preferences.md` is read if the project-local file is absent. If both exist, the project-local file takes precedence; no merging. Contains hard constraints and absolute preferences that override skill-sourced defaults.
3. **`session-log.md`.** Per-session chronological transcript of every tier-B and tier-C decision: who asked, which options, which skill was consulted, the answer, reasoning, and confidence.
4. **Confidence-tier gate.** Embedded in each rewritten skill at decision points. Three tiers (A, B, C) with distinct handling.
5. **Pipeline driver** (`/auto`). Chains brainstorm → plan → execute, stopping at the `--stop-at` boundary, with one shared `session-log.md` across all stages.

### Runtime flow for `/auto "build me X"`

```
user  →  /auto "X"
  ↓
pipeline driver creates session dir; writes session-log.md header
  (decision-proxy reads user-preferences.md per dispatch, not the driver)
  ↓
invokes auto-superpowers:brainstorming
  ↓   per meaningful decision: dispatch decision-proxy → append log entry
  ↓
writes spec.md → commits (trailer: Session: <dir>)
  ↓
invokes auto-superpowers:writing-plans  (same proxy pattern)
  ↓
writes plan.md → commits
  ↓
invokes auto-superpowers:executing-plans
  ↓   per step: TDD loop; log any structural decisions
  ↓   on tier-C halt: writes halted.md, stops the session
  ↓
returns: branch ready at the --stop-at boundary
```

---

## The decision-proxy subagent

### Purpose

A dedicated subagent dispatched per meaningful decision by brainstorming, writing-plans, and executing-plans. It answers questions on behalf of an absent user, drawing expertise from installed Claude skills and applying `user-preferences.md` as an override filter.

### Tools available to the subagent

- `Skill` — the core capability. The proxy's value comes from invoking domain skills per question.
- `Read`, `Grep`, `Glob` — for reading project context, `user-preferences.md`, and relevant source files.
- `Bash` — limited to read-only commands like `git log`, `git diff`, config inspection.
- **Not** `Edit`, `Write`, or `TaskCreate`. The proxy returns answers only. The caller writes to `session-log.md`.

### Input contract (from caller)

```
Question: <one specific decision to make>
Options: <list of 2+ meaningfully different choices, or "open-ended">
Task context: <one-paragraph summary of what's being built and why>
Confidence tier: <A|B|C> (caller's estimate; proxy may override upward)
Relevant files: <optional paths to inspect>
```

### Output contract (structured response)

```yaml
answer: <the chosen option, or a short open-ended answer>
reasoning: <3-6 sentences naming the inputs that drove the choice>
skills_consulted: [<skill-name>, ...] or []
user_prefs_applied: [<quoted pref>, ...] or []
confidence: high | medium | low
tier_override: <null | proposed higher tier with reason>
```

### Internal process (documented in the agent definition)

1. Read `user-preferences.md` if present.
2. Read the routing guide at `skills/auto-superpowers/decision-proxy/SKILL.md` to identify candidate skills for this question's domain.
3. Invoke the most relevant installed skill(s) via `Skill`. If none applies, proceed with general reasoning and say so.
4. Consult any named context files.
5. Apply user-preferences as an override filter. If a preference contradicts the skill's default, prefer the preference and note it in reasoning.
6. Pick the answer, fill the output contract, return.
7. If, during steps 3–5, the proxy discovers the decision is riskier than the caller's tier estimate, return `tier_override: C` with reasoning.

### Why the proxy can escalate (but not de-escalate)

The caller estimates stakes based on local context. The proxy, after consulting a skill, may know better. Example: brainstorming thinks "which hashing algorithm?" is a tier-B style choice; the proxy invokes `security-review`, learns it's load-bearing, and escalates to C. De-escalation is forbidden — it would let the proxy route around safety nets, which is the opposite of what we want. The tier is a floor, not a guess.

### Cost model

Each proxy dispatch is one subagent call. A typical brainstorm has ~6–12 meaningful decisions; writing-plans ~3–5; executing-plans is mostly silent (tier A) with occasional tier-B/C events during debugging. Rough upper bound per `/auto` session: ~25 proxy dispatches. Acceptable for walk-away use cases; not suitable for sub-second interactive work — which isn't the target.

### Failure modes and mitigations

| Failure | Mitigation |
|---|---|
| Proxy picks wrong | Visible in log. `/calibrate-proxy` updates `user-preferences.md`. |
| Proxy invokes wrong skill | Log shows which skill was consulted. User updates the routing guide. |
| Proxy returns `confidence: low` on tier-B | Caller treats as tier-C and halts. Safer default. |
| Proxy hangs on a skill invocation | Caller enforces a dispatch timeout. On timeout, caller writes `halted.md` with "proxy timed out on skill X". |
| Proxy fabricates expertise when no skill matches | Output contract requires `skills_consulted: []` to be explicit; log entry names "no domain skill, general reasoning applied". |

---

## Confidence tiers and hard-stop behavior

Every meaningful decision lands in one of three tiers. The calling skill makes an initial estimate; the decision-proxy can escalate (never de-escalate).

### Tier A — Mechanical / low-stakes

**Criteria (any one qualifies):**
- Fully reversible in under 5 minutes of work (rename a variable, move a file).
- No user-visible effect (internal structure, formatting).
- Dictated by existing convention in the codebase (file layout, naming pattern).
- Trivially swappable if wrong.

**Examples:** file names, import order, variable names, which internal helper to use, how to split a function that's grown too long.

**Action:** Decide inline. No proxy dispatch, no log entry.

### Tier B — Substantive / medium-stakes

**Criteria (any one qualifies):**
- Reversible but costs meaningful work to change (library choice, data shape for an internal API, test framework).
- User-visible but contained (UI wording, error message text, feature scoping within an agreed boundary).
- The spec has 2+ reasonable approaches with different tradeoffs.
- The decision would normally be asked in an interactive brainstorm session.

**Examples:** which web framework, initial database schema, pagination style, error handling strategy, what to include in the MVP vs. cut, which of two architectural patterns to follow.

**Action:** Dispatch `decision-proxy`. Append structured entry to `session-log.md`. Continue.

### Tier C — Load-bearing / high-stakes

**Criteria (any one qualifies):**
- **Architectural pivots** — change the shape of the system mid-stream (swap DB, rewrite a module, split a service).
- **Destructive or hard-to-reverse operations** — deleting data, force-pushing, schema migrations on existing data, renaming a public API.
- **Security-sensitive** — auth, secret handling, permissions, input validation on trust boundaries, crypto choices.
- **3+ failed fixes** on the same bug (pulled from systematic-debugging's existing rule).
- **Cross-cutting scope change** — discovering mid-execution that the spec was wrong in a way that breaks the plan.
- **Legal, licensing, or compliance implications.**
- **Committing code whose correctness cannot be verified by tests the agent can run.**

**Action:**
1. Dispatch `decision-proxy` with `tier: C` signaled.
2. If proxy returns `confidence: high` with a definitive answer, log it with a tier-C header and continue.
3. If proxy returns `confidence: medium` or `low`, OR returns `tier_override: C` because it found something worse than the caller thought, OR general reasoning with no skill support — **halt**.
4. Write `halted.md` with the decision point, options, proxy's tentative recommendation (if any), relevant file pointers, and a one-line resume instruction. Stop the session.

### Why tier-C can still auto-proceed on high confidence

The walk-away promise matters and most "high-stakes" decisions still have an obviously right answer in context. "Use argon2id with these params for password hashing" is tier C but a confident `security-review`-consulted answer is fine to commit to. The halt exists for when the proxy itself does not know.

### Operations refused outright (beyond tier C)

- Force push, including to feature branches.
- Deleting remote branches.
- Modifying shared branches (main, release).
- Skipping git hooks (`--no-verify`, `--no-gpg-sign`).
- Git operations that discard uncommitted user work.

These are refused regardless of tier and logged as refusals in `session-log.md`.

### `halted.md` format

```markdown
# Session halted — high-stakes decision needed

**When:** 2026-04-15 14:32 (brainstorming phase)
**Task:** <one-line task description>

## The decision
<The question in plain terms>

## Options considered
- **A:** <option + summary>
- **B:** <option + summary>
- **C:** <option + summary>

## Proxy's tentative recommendation
<Option and reasoning, or "proxy could not commit">

## Why this halted
<Tier-C trigger: e.g., "security-sensitive and proxy confidence was medium">

## How to resume
Reply with one of:
- `go with <letter>` — accept an option
- `go with proxy` — accept the proxy's recommendation
- answer freely in your own words

Or: `/auto --resume <session-dir>`

## Pointers
- session-log.md: [link]
- current draft spec: [link]
- relevant files: [list]
```

---

## Session artifacts and file layout

### Directory layout

Default root is `docs/auto-superpowers/`. Overridable via `AUTO_SUPERPOWERS_DOCS_ROOT` env var or per-command `--docs-root` flag.

```
docs/auto-superpowers/
├── sessions/
│   └── 2026-04-15-1432-build-login-flow/     ← one directory per /auto invocation
│       ├── session-log.md                     ← chronological transcript
│       ├── spec.md                             ← the design doc
│       ├── plan.md                             ← the implementation plan
│       └── halted.md                           ← only present if session halted
└── user-preferences.md                         ← optional; project-scoped
```

Each session gets its own folder named `YYYY-MM-DD-HHMM-<slug>`. All artifacts for that run live together. Easy to browse, easy to delete, easy to reference from a PR description.

### `session-log.md` format

```markdown
# Session log — 2026-04-15 14:32
Task: build login flow (email+password, passkeys optional later)
Stop at: impl (default)
Skills available for persona expertise: ui-ux-pro-max, security-review, claude-api

## Phase: brainstorming

### 14:32 | Scope — what's in the MVP?
- Tier: B
- Options: [password-only, password+passkeys, password+OAuth]
- Skill consulted: security-review, ui-ux-pro-max
- Proxy answered: password-only
- Reasoning: 3 sentences explaining.
- User prefs applied: "YAGNI aggressive" — passkeys punted to v2.
- Confidence: high

### 14:34 | Password hashing algorithm
- Tier: C (security-sensitive)
- Options: [bcrypt, scrypt, argon2id]
- Skill consulted: security-review
- Proxy answered: argon2id (m=64MB, t=3, p=4)
- Reasoning: 3 sentences explaining.
- Confidence: high | Tier-C auto-proceed allowed

## Phase: writing-plans
…

## Phase: executing-plans
…

## Halts
(none — or a table listing any halted.md events)
```

### `spec.md` and `plan.md` with decision callouts

Each document gets a "Key autonomous decisions" callout at the top, linking into specific `session-log.md` entries. The body reads normally — someone who never looks at the transcript still gets a usable document.

```markdown
# Spec — Login flow

> **Key autonomous decisions** (full reasoning: [session-log.md](./session-log.md))
> - Scope: password-only MVP, passkeys punted → [14:32]
> - Password hashing: argon2id with specific params → [14:34] (tier C, auto-proceed)
> - Session storage: signed JWT in httpOnly cookie → [14:36]
>
> Correct any decision with `/calibrate-proxy`.

## Overview
<normal spec body>
```

### Git commits

Each phase boundary produces a commit:
1. After spec written: `auto-superpowers: spec for <slug>`
2. After plan written: `auto-superpowers: plan for <slug>`
3. After each plan step implemented: normal TDD commits from executing-plans (unchanged from upstream).

All commits include a `Session: docs/auto-superpowers/sessions/<dir>/` trailer so any commit can be traced back to its decision trail.

### `user-preferences.md` format

Lightweight markdown, no frontmatter. Sections are optional; the proxy greps for relevant ones per decision.

```markdown
# User preferences

## Hard constraints
- Never use AWS in this project
- All services must run on a single $5/mo VPS

## Strong preferences
- Prefer Postgres over any other DB unless specifically justified
- Boring tech over novelty — prefer battle-tested libraries
- YAGNI aggressive — cut scope whenever reasonable

## Do not use
- TypeScript branded types
- ORMs with magic (prefer query builders or raw SQL)

## Corrections (from /calibrate-proxy)
- 2026-04-15 — Proxy picked Tailwind for the login page; I'd pick vanilla CSS modules for this project. Reason: existing codebase uses CSS modules throughout.
```

### Privacy and secrets

`session-log.md` may reference config decisions. The decision-proxy skill explicitly instructs: **never quote actual secret values in log entries — only their names and shapes.** Session directories are gitignored by default; the user opts in via `--commit-session-log` on `/auto` or by removing the gitignore entry. The plugin's README includes a post-install note explaining this.

---

## Surgical skill modifications

Every skill listed below is a **surgical rewrite** of upstream's version. "+" means added content, "~" means replaced content, "−" means removed content.

### `auto-superpowers:brainstorming`

- ~ Replace "ask clarifying questions one at a time" with "identify the set of decisions this brainstorm must resolve; for each tier-B/C decision, dispatch the decision-proxy; for tier-A decisions, decide inline; log every B/C dispatch to `session-log.md`."
- ~ Replace "one question at a time" with "one decision at a time — each dispatch is a focused, single-decision prompt with options."
- ~ Replace "user approves design sections" with "self-review each spec section for placeholder scan, internal consistency, scope. Fix inline. No approval wait — the written spec is the deliverable."
- − Remove the visual-companion offer. Autonomous mode has no interactive channel to show visuals. `visual-companion.md` is not shipped.
- \+ Add a "persona skill selection" step at the top: "analyze the task, identify likely-relevant domain skills, list them in the session-log header."
- \+ Add a HARD-GATE: "do not proceed past brainstorming if any tier-C decision halted to `halted.md`."
- ~ Throughout: "your human partner" → "the absent user" or removed where benign.

### `auto-superpowers:writing-plans`

- ~ Replace "choose subagent-driven vs. inline execution" with "default to subagent-driven for autonomous mode — it parallelizes better and each plan step is independently verifiable. Override only if a tier-B proxy dispatch returns a different answer."
- \+ Add "plan step confidence annotation" — each plan step is marked [A/B/C] so executing-plans knows which steps warrant proxy dispatches.
- \+ Add the same HARD-GATE: stop if any decision halted to `halted.md`.

### `auto-superpowers:executing-plans`

- ~ Replace "plan concerns checkpoint — raise concerns or proceed" with "self-check the plan against current repo state; if concerns surface, dispatch proxy with tier matching severity; proceed only if all surfaced concerns resolve to tier A or B."
- ~ Replace "blocker checkpoint — stop and ask" with "on blocker: assess tier. Tier A — resolve inline. Tier B — dispatch proxy. Tier C — write `halted.md`, halt. Do not power through a tier-C blocker by guessing."
- \+ Integrate with `systematic-debugging`'s "3+ failed fixes" rule: that rule becomes a tier-C halt.
- \+ Add "verification gate" — before moving to the next plan step, run tests. On failure: tier B if the failure is within the current step's introduced code; tier C if it's a regression in unrelated code.

### `auto-superpowers:systematic-debugging`

- ~ Existing "STOP if 3+ fixes failed, question architecture" rule stays, but the stop action changes: write `halted.md` with the fix history and hypothesis, then halt. Do not silently attempt fix #4.
- \+ Add "hypothesis confidence check" — if Phase 1 root cause investigation yields no strong hypothesis, it is tier C. Dispatch proxy with the evidence trail.
- Otherwise unchanged. This skill's discipline is a feature, not something to loosen.

### `auto-superpowers:finishing-a-development-branch`

- ~ "Merge/PR/Keep/Discard choice" becomes tier- and stop-at-dependent. Default `/auto --stop-at=impl` short-circuits: stop at "local branch ready" without offering merge options. `--stop-at=pr` triggers PR creation non-interactively. `--stop-at=merged` merges after tests pass + code-reviewer subagent approves + no tier-C halts are open.
- ~ Remove "type `discard` to confirm deletion" gate. Autonomous mode never invokes the discard path. Discarding is an interactive operation only.
- \+ Hard rule: never force-push, never delete remote branches, never modify shared branches. Refused outright.

### `auto-superpowers:receiving-code-review`

- ~ "Verify feedback is technically sound before implementing" — tier-B dispatch to proxy per non-trivial review item.
- ~ "Stop and ask for clarification on unclear items" → tier-C halt if the proxy also cannot resolve the ambiguity. Otherwise tier B (proxy interprets + logs + continues).
- ~ "Pushback decision" — proxy handles, invoking the `code-reviewer` skill (if installed) or general reasoning. Logs the call. User sees pushback reasoning in the log and can override via calibration.

### `auto-superpowers:requesting-code-review`

- No behavioral change. Upstream already dispatches the code-reviewer subagent autonomously. Only addition: feed the reviewer a pointer to `session-log.md` so it can factor the decision trail into its review.

### `auto-superpowers:test-driven-development`

- **Unchanged from upstream.** TDD discipline stays as-is. RED/GREEN/REFACTOR, no loosening. The upstream "exceptions ask your human partner" clause becomes: in autonomous mode the proxy handles the rare "is this a legitimate exception" call (tier B, logged).

### `auto-superpowers:verification-before-completion`

- **Unchanged from upstream.** Verification-before-completion is a hard rule that autonomous mode depends on, not something to loosen. If anything, more important in autonomous mode — there is no human to catch a missed check.

### `auto-superpowers:using-auto-superpowers` (NEW)

- Two-paragraph intro explaining the autonomous mode contract.
- Pointer to `decision-proxy/SKILL.md` and `session-artifacts/SKILL.md`.
- Preamble emphasis: "log every tier-B/C decision, dispatch the proxy, write `halted.md` on any halt."
- Co-install aware. If upstream `using-superpowers` is also active in this session, this skill defers to it for general skill-usage discipline and only overrides where autonomous behavior differs.

### New skills (not surgical rewrites)

- **`auto-superpowers:decision-proxy/SKILL.md`** — short routing guide. Table of "question type → candidate skills" plus a fallback rule. Maintained by the plugin; extendable by the user via project-local overlay.
- **`auto-superpowers:session-artifacts/SKILL.md`** — defines the session directory layout, `session-log.md` format, `halted.md` format, commit trailer convention, and the gitignore defaults.

### Skills NOT modified and NOT shipped by this plugin

- `dispatching-parallel-agents` — upstream's version is fine.
- `subagent-driven-development` — same.
- `using-git-worktrees` — same.
- `writing-skills` — same. Relevant only when authoring skills, not when running `/auto`.

**Plugin size:**
- **7 skills with behavior changes** — brainstorming, writing-plans, executing-plans, systematic-debugging, finishing-a-development-branch, receiving-code-review, requesting-code-review (minor).
- **2 skills shipped unchanged** — test-driven-development, verification-before-completion. Shipped so that users who install only `auto-superpowers` (no upstream) still get them.
- **3 new skills** — `using-auto-superpowers`, `decision-proxy` (routing guide), `session-artifacts` (file format spec).
- **1 new agent** — `decision-proxy`.
- **5 new commands** — `/auto`, `/auto-brainstorm`, `/auto-plan`, `/auto-execute`, `/calibrate-proxy`.
- **1 new session-start hook** — co-install aware.

Total: 12 skill files + 1 agent + 5 commands + 1 hook.

---

## Commands and kickoff

### `/auto "<task description>" [flags]` — the pipeline driver

The happy path. Runs brainstorm → plan → execute in a single session with one shared `session-log.md`.

**Flags:**
- `--stop-at <spec|plan|impl|pr|merged>` — default `impl`. Where the pipeline halts.
- `--docs-root <path>` — override `docs/auto-superpowers/`.
- `--persona <skill[,skill...]>` — force specific skills to be primary persona sources, bypassing auto-selection.
- `--no-commit-session-log` / `--commit-session-log` — override the default gitignore behavior.
- `--dry-run` — run brainstorm only, write the spec, halt. Equivalent to `--stop-at spec`.
- `--resume <session-dir>` — pick up a previously halted session from its `halted.md`.

**Behavior:** creates a fresh session directory, writes `session-log.md` header, invokes brainstorming, then writing-plans, then executing-plans, honoring `--stop-at`. On any tier-C halt: writes `halted.md`, stops the current stage, does not proceed.

### `/auto-brainstorm "<task>" [flags]`

Just the brainstorm stage. Writes `spec.md` to a new session directory. Equivalent to `/auto --stop-at spec`. Use when you want to walk away to a written spec, review it interactively, then drive the rest yourself.

### `/auto-plan [--spec <path>] [flags]`

Just the plan stage. Takes an existing spec (from `/auto`, from upstream, or hand-written) and produces `plan.md`. If `--spec` is omitted, finds the most recent session directory and uses its spec.

### `/auto-execute [--plan <path>] [flags]`

Just the execution stage. Takes an existing plan and runs it to implementation. Same implicit "most recent session" fallback as `/auto-plan`.

### `/calibrate-proxy [--session <dir>]` — the correction loop

Opens the most recent (or specified) `session-log.md` and walks the user through each meaningful decision one at a time: "keep, correct, or add a preference?" Corrections become entries in `user-preferences.md`. No code changes — purely a preferences-update tool.

**This is the only interactive command in auto-superpowers.** The walk-away command is `/auto`; the come-back command is `/calibrate-proxy`.

### Kickoff UX

```
user> /auto "build a login flow with email+password"

auto-superpowers> Starting session: 2026-04-15-1432-login-flow
                  Stop-at: impl
                  Persona skills detected: security-review, ui-ux-pro-max, frontend-design
                  Writing session-log.md
                  → Phase: brainstorming…

                  (6 minutes later)

                  Brainstorm complete. Spec written to .../spec.md
                  → Phase: writing-plans…

                  (3 minutes later)

                  Plan written to .../plan.md
                  → Phase: executing-plans…

                  [TDD loop runs — commits per step]

                  Done. Branch: auto/login-flow-20260415
                  Session: docs/auto-superpowers/sessions/2026-04-15-1432-login-flow/
                  Halts: none

                  Run `/calibrate-proxy` to review decisions before merging.
```

### On halt

```
auto-superpowers> [14:37] Tier-C halt in brainstorming:
                  Question: password hashing library choice
                  Proxy confidence: low (no security-review skill installed)
                  Wrote: docs/auto-superpowers/sessions/.../halted.md
                  Session paused. Reply with:
                    go with <option>
                    go with proxy
                    (or answer freely)
                  Or: /auto --resume <session-dir>
```

---

## Co-install coordination

### Session-start hook

Auto-superpowers ships a session-start hook at `hooks/session-start/`. When it runs:

1. Check if upstream `superpowers`' session-start hook has already injected its preamble this session (detected via a marker string or a small env var the upstream hook sets).
2. **Upstream present:** inject only a short auto-mode note — "auto-superpowers is installed. `/auto <task>` runs brainstorm → plan → execute non-interactively. See `auto-superpowers:using-auto-superpowers`." Do not duplicate upstream's full preamble.
3. **Upstream absent:** inject a fuller preamble establishing skill-use discipline on its own, drawing from upstream's `using-superpowers` content plus the auto-mode notes.

### Skill namespace

Every skill is `auto-superpowers:<name>`. No collision with `superpowers:<name>`.

### Commands

All prefixed `/auto*` or `/calibrate-proxy`. No collision with `/brainstorm`, `/write-plan`, `/execute-plan`.

### Agents

Only one new agent: `decision-proxy`. Auto-superpowers does not ship a `code-reviewer` agent — if upstream is installed we reuse theirs; if not, requesting-code-review degrades to dispatching the general-purpose agent.

### Spec output

Default `docs/auto-superpowers/sessions/`. Upstream uses `docs/superpowers/specs/`. No directory collision.

### Gitignore coordination

The plugin's README suggests adding `docs/auto-superpowers/sessions/` to `.gitignore` by default. Session logs may contain reasoning about proprietary or sensitive context. Users who want session artifacts committed opt in via `--commit-session-log` or by removing the gitignore entry.

---

## Testing and evaluation strategy

1. **Unit-style dry-run tests.** Each rewritten skill has a test file at `tests/skills/<skill>/` with fixture inputs and expected shape of output — did the proxy get dispatched, did log entries get written, did tier-C trigger halts. Mechanical correctness, not subjective quality.
2. **Golden-task fixtures.** A small library of ~6 canonical tasks in `tests/golden-tasks/`:
   - "CLI tool to convert CSV to JSON"
   - "login flow with email+password"
   - "small REST API for a todo list"
   - "React component for a date range picker"
   - "background worker that polls a queue and posts to Slack"
   - "schema migration adding a NOT NULL column to a 10M-row table" (a tier-C-heavy task)

   Each golden task has a target session directory with hand-curated expectations. Run `/auto` against each in a scratch repo as part of CI. Compare produced `session-log.md` against the golden one using rubric-based eval (structure, presence, absence — not prose diff).
3. **Adversarial pressure tests.** Prompts designed to break the plugin:
   - "just build it, don't ask questions" — does the plugin still produce a session log?
   - "skip the brainstorming step" — does it refuse and explain why?
   - "you decide, I don't care" on a security-sensitive task — does tier-C still halt?
   - Ambiguous tasks that upstream handles by asking the user — does auto-mode produce sensible answers with honest confidence?
4. **Real-task dogfooding.** The maintainer runs `/auto` on actual work for a few weeks before v1.0, reviews every `session-log.md`, and submits corrections via `/calibrate-proxy`. The plugin is not "done" until there is signal that decision quality is acceptable on real work.
5. **No adversarial eval against upstream.** We do not claim auto-mode is "as good as" interactive mode. We claim it is "acceptable for walk-away tasks with a review loop." Different bar.

---

## Risks and mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Decision-proxy picks wrong on a tier-B call; spec is subtly off | High (especially before calibration) | `/calibrate-proxy` loop. Spec self-review before handoff. Transcript visibility so user sees the error. |
| Proxy fails to escalate a tier-C call (misses danger) | Medium | Tier floor set by calling skill first; proxy can only escalate up. Conservative defaults on security/destructive patterns. |
| Session-start hook loops or duplicates preamble on dual install | Low | Marker-based detection. Tested in dual-install CI fixture. |
| Long sessions burn tokens without useful output | Medium | Per-stage budget caps (configurable). Iteration caps on systematic-debugging's fix loop (3+ → halt). |
| User reads `halted.md` and is frustrated the plugin "gave up" | Low–medium | Halt reasons must be specific. Include proxy's tentative recommendation so user can almost always resume with `go with proxy`. |
| Upstream changes break surgical edits on sync | Medium (over time) | Surgical edits are localized and merge-friendly. Maintainer periodically re-syncs from upstream. |
| First-run user has no `user-preferences.md`, proxy makes project-inappropriate calls | High on first session | Don't require `user-preferences.md` — proxy handles empty-file gracefully. First session has the most `/calibrate-proxy` corrections. Documented in README. |
| Proxy invokes a skill that calls external services and hangs | Low | Proxy dispatch has a timeout. On timeout, caller writes `halted.md` with "proxy timed out on skill X". |
| Destructive git actions taken autonomously | Low (refused outright) | Refused regardless of tier. Listed as "beyond tier C" in this spec. |

---

## Implementation phasing

This spec is large enough that it should produce multiple implementation plans rather than a single monolithic plan. Suggested decomposition for the writing-plans phase:

**Phase 1 — Walk-away brainstorm (MVP).** The smallest shippable increment: enough to invoke `/auto-brainstorm` and get a spec with a session log. Includes:
- `decision-proxy` subagent + routing skill
- `brainstorming` surgical rewrite
- `session-artifacts` skill (log/halted format)
- `using-auto-superpowers` entry skill
- `/auto-brainstorm` command
- Session-start hook (co-install aware)
- `user-preferences.md` reading

Deliverable: user can walk away from a brainstorm and come back to `spec.md` + `session-log.md`.

**Phase 2 — Full pipeline.** Extends Phase 1 to the full spec → plan → execute flow:
- `writing-plans` surgical rewrite
- `executing-plans` surgical rewrite
- `systematic-debugging` surgical rewrite (tier-C halt on 3+ failures)
- `verification-before-completion` + `test-driven-development` shipped unchanged
- `/auto` pipeline driver, `/auto-plan`, `/auto-execute` commands

Deliverable: `/auto "<task>"` runs end-to-end with `--stop-at=impl`.

**Phase 3 — Completion and finishing.** Adds the later-stage skills and the calibration loop:
- `finishing-a-development-branch` surgical rewrite (stop-at routing)
- `receiving-code-review` + `requesting-code-review` edits
- `/calibrate-proxy` command
- Gitignore coordination + README

Deliverable: `--stop-at=pr` and `--stop-at=merged` work. Post-session review loop available.

**Phase 4 — Tests and dogfooding.** The evaluation machinery:
- Unit-style dry-run fixtures per skill
- Golden-task fixtures and rubric-based eval harness
- Adversarial pressure-test prompts
- Dual-install CI fixture

Deliverable: regression prevention, plus signal that decision quality meets the bar.

Each phase produces its own implementation plan and lands as its own set of commits. Phases are sequential; Phase 2 depends on Phase 1's primitives, etc.

---

## Open questions for implementation planning

The following are explicitly deferred to the writing-plans phase:

- Exact SKILL.md text for each surgical rewrite — the spec above defines the semantic changes; the plan decides the precise wording.
- Agent definition file format for `decision-proxy` — mirrors upstream's `code-reviewer.md` structure; the plan documents field by field.
- Session-start hook implementation language (shell script vs. node). Upstream uses shell; plugin likely follows.
- `/calibrate-proxy` UX for large session logs — how to present many decisions without overwhelming the user.
- Budget cap defaults (per-stage token caps).
- Commit trailer exact format and whether multi-line trailers work in all git setups.
- Whether `--persona` should accept short aliases (e.g., "frontend", "security") in addition to full skill names.

These are implementation details, not spec-level decisions. They don't block the plan-writing step.
