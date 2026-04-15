# auto-superpowers Phase 1: Walk-Away Brainstorm MVP — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the smallest-possible auto-superpowers increment — `/auto-brainstorm "<task>"` runs non-interactively and produces `spec.md` + `session-log.md` in a session directory, with halt-on-tier-C behavior working end-to-end.

**Architecture:** In-place transformation of this fork. Rename plugin identity (`superpowers` → `auto-superpowers`). Add three new skills (`decision-proxy` routing guide, `session-artifacts` format spec, `using-auto-superpowers` entry preamble). Surgically rewrite `brainstorming/SKILL.md` to replace interactive gates with decision-proxy dispatches and transcript logging. Add `/auto-brainstorm` slash command. Add `decision-proxy` subagent. Update session-start hook to read the new entry skill. The resulting plugin installs standalone; co-install with upstream `superpowers` is tolerated but not optimized in Phase 1.

**Tech Stack:**
- Plugin content: Markdown (SKILL.md files with YAML frontmatter, agent markdown, command shims)
- Session-start hook: Bash (porting the existing `hooks/session-start` script)
- Session artifacts: Plain-text Markdown (`session-log.md`, `spec.md`, `halted.md`, `user-preferences.md`)
- No code compilation, no package manager dependencies, no test harness setup (Phase 4 introduces eval tests)

**Reference spec:** `docs/superpowers/specs/2026-04-15-auto-superpowers-design.md`

---

## Note on code blocks in this plan

Several tasks contain "write this content to file X" instructions where the target content itself contains code fences. To keep the plan unambiguous, those outer content blocks use **four-backtick** fences wherever possible. Some Edit old_string/new_string blocks (notably Task 6 steps 7–9) use three-backtick outer fences that contain three-backtick inner fences. When implementing those steps, use `Read` on this plan file to view raw content and copy the exact strings — do not rely on markdown rendering, which will close the outer fence early. If a step looks truncated when rendered, that is the nested-fence artifact; the raw plan file is correct.

---

## Scope Check

This plan covers **Phase 1 only** from the spec's "Implementation phasing" section. It does **not** cover:
- Writing-plans or executing-plans skill rewrites (Phase 2)
- `/auto` pipeline driver, `/auto-plan`, `/auto-execute` (Phase 2)
- Finishing-a-development-branch, receiving-code-review edits (Phase 3)
- `/calibrate-proxy` command (Phase 3)
- Golden-task fixtures and eval harness (Phase 4)

Phase 1's definition of done is: a user can run `/auto-brainstorm "<idea>"`, walk away, and come back to a committed `spec.md` + `session-log.md` in a session directory, with tier-C halts working correctly. Phase 2 begins after Phase 1 lands.

---

## File Structure

**Files created (new):**
- `skills/decision-proxy/SKILL.md` — routing guide listing candidate skills per question domain
- `skills/session-artifacts/SKILL.md` — defines session directory layout, log format, halted.md format
- `skills/using-auto-superpowers/SKILL.md` — entry preamble, replaces `using-superpowers` role
- `agents/decision-proxy.md` — subagent definition with tools list and internal process
- `commands/auto-brainstorm.md` — slash command that kicks off the auto-brainstorm flow
- `tests/phase-1-smoke.sh` — manual smoke test script

**Files modified:**
- `package.json` — rename `superpowers` → `auto-superpowers`
- `gemini-extension.json` — same rename
- `skills/brainstorming/SKILL.md` — surgical rewrite (auto version)
- `hooks/session-start` — read new entry skill path, preserve bash-script shape

**Files deleted:**
- `commands/brainstorm.md` — deprecation stub, no longer relevant in this plugin

**Files left untouched in Phase 1:**
- `skills/writing-plans/*`, `skills/executing-plans/*`, `skills/systematic-debugging/*` — Phase 2+
- `skills/finishing-a-development-branch/*`, `skills/receiving-code-review/*` — Phase 3
- `skills/using-superpowers/SKILL.md` — left alongside new file. Hook reads the new path; old file becomes dead weight but removing it is out-of-scope for Phase 1
- `agents/code-reviewer.md` — unchanged, reused by requesting-code-review skill (no edits in Phase 1)
- `README.md`, `CLAUDE.md` — contributor docs; plugin identity changes don't require immediate rewrite

---

## Task 1: Rename plugin identity

**Files:**
- Modify: `package.json`
- Modify: `gemini-extension.json`

- [ ] **Step 1: Read current package.json**

Run: `cat package.json`
Expected: confirms `"name": "superpowers"`.

- [ ] **Step 2: Rewrite package.json with new name**

Replace the entire file contents with:

```json
{
  "name": "auto-superpowers",
  "version": "0.1.0",
  "type": "module",
  "main": ".opencode/plugins/superpowers.js"
}
```

Note: version resets to `0.1.0` to reflect this is a fresh plugin, not a superpowers-compatible release. `main` path is left alone for Phase 1; rename of the OpenCode entry point is deferred to later phases where OpenCode integration is actually touched.

- [ ] **Step 3: Read current gemini-extension.json**

Run: `cat gemini-extension.json`
Expected: shows a JSON object with `name` field.

- [ ] **Step 4: Update gemini-extension.json name**

Replace `"name": "superpowers"` with `"name": "auto-superpowers"` using Edit. Leave other fields unchanged.

- [ ] **Step 5: Verify neither file references the old name in the `name` field**

Run: `grep -E '"name":\s*"superpowers"' package.json gemini-extension.json`
Expected: no matches.

- [ ] **Step 6: Commit**

```bash
git add package.json gemini-extension.json
git commit -m "auto-superpowers: rename plugin identity to auto-superpowers

Phase 1 of auto-superpowers. Resets version to 0.1.0."
```

---

## Task 2: Add decision-proxy routing skill

**Files:**
- Create: `skills/decision-proxy/SKILL.md`

- [ ] **Step 1: Create the skill file with complete content**

Write `skills/decision-proxy/SKILL.md` with exactly this content:

```markdown
---
name: decision-proxy
description: "Routing guide for the decision-proxy subagent. Maps question domains to candidate Claude skills, so the proxy knows which skill to invoke for any given decision. Read this at the start of every proxy dispatch."
---

# Decision Proxy — Routing Guide

The `decision-proxy` subagent uses this guide to pick which installed Claude skills to consult for a given decision. You are that subagent. For each question, identify the domain, then invoke the most specific installed skill from the list below. If none of the listed candidates is installed, fall back to general reasoning and record `skills_consulted: []` in your output.

## How to use this guide

1. Classify the question's primary domain (UI, security, data, debugging, etc.).
2. Look at the candidate skills for that domain.
3. Check which candidates are actually installed in the current session. Invoke the first installed one that matches.
4. If the question spans multiple domains, invoke one skill per domain (up to 3) and synthesize the answers.
5. If no candidate matches, do NOT fabricate expertise. Use general reasoning and say so explicitly in `skills_consulted: []`.

## Routing table

| Question domain | Candidate skills (in priority order) |
|---|---|
| UI / visual / layout / design aesthetics | `frontend-design`, `ui-ux-pro-max`, `ckm-ui-styling` |
| UX flow / product sense / information architecture | `ui-ux-pro-max`, `frontend-design` |
| Security / auth / secrets / permissions / crypto | `security-review` |
| Anthropic SDK / Claude API / prompt caching / tool use | `claude-api` |
| Debugging / root-cause analysis / failing tests | `systematic-debugging` |
| Testing strategy / TDD / test design | `test-driven-development` |
| Brand identity / voice / messaging / assets | `ckm-brand`, `ckm-design` |
| Slide decks / presentations | `ckm-slides` |
| Design systems / tokens / component specs | `ckm-design-system`, `ckm-ui-styling` |
| Skill authoring / plugin design | `skill-creator`, `writing-skills` |
| Git / branch hygiene / commit structure | `verification-before-completion` (for completion gates); no direct skill otherwise |

## Fallback rule

When no candidate skill is installed, or the question does not match any listed domain:
- Use general reasoning informed by task context and `user-preferences.md`.
- Set `skills_consulted: []`.
- In the reasoning field, explicitly state "no domain skill matched; general reasoning applied."
- Keep your confidence assessment honest: if you are guessing, return `confidence: low`.

## Extending this guide

Project-local overrides live at `docs/auto-superpowers/decision-proxy-routing.md`. When present, the decision-proxy reads both files and prefers project-local entries over these defaults.
```

- [ ] **Step 2: Verify the file has correct frontmatter**

Run: `head -5 skills/decision-proxy/SKILL.md`
Expected: lines 1-5 show the YAML frontmatter with `name: decision-proxy` and a `description:` field.

- [ ] **Step 3: Verify the file parses as valid markdown (no unclosed code fences)**

Run: `awk '/^```/{c++} END{print c}' skills/decision-proxy/SKILL.md`
Expected: output is an even number (all code fences closed).

- [ ] **Step 4: Commit**

```bash
git add skills/decision-proxy/SKILL.md
git commit -m "auto-superpowers: add decision-proxy routing skill

Maps question domains to candidate Claude skills. The decision-proxy
subagent reads this file at the start of every dispatch to decide which
skill (if any) to consult."
```

---

## Task 3: Add decision-proxy subagent definition

**Files:**
- Create: `agents/decision-proxy.md`

- [ ] **Step 1: Create the agent file with complete content**

Write `agents/decision-proxy.md` with exactly this content (the outer fence below uses **four** backticks so that inner three-backtick blocks render correctly):

````markdown
---
name: decision-proxy
description: |
  Use this agent when auto-superpowers needs to answer a decision question on behalf of an absent user. The agent consults installed domain skills (via the Skill tool) and applies user-preferences.md as an override filter. It does not write files — it returns a structured answer that the caller logs to session-log.md. Examples: <example>Context: auto-superpowers:brainstorming is running an autonomous brainstorm and needs to pick a web framework. assistant: "I'll dispatch the decision-proxy to decide this one." <commentary>Brainstorming identified a tier-B decision; the proxy will consult relevant skills (e.g., frontend-design) and return a structured answer.</commentary></example> <example>Context: writing-plans is choosing between two data shapes for an internal API. assistant: "Dispatching decision-proxy — this is a tier-B library/schema choice." <commentary>The proxy consults any installed backend or API-design skills and applies user-preferences as a filter.</commentary></example>
model: inherit
---

You are the **decision-proxy** — a dedicated subagent for auto-superpowers. Your job is to answer one focused decision question on behalf of an absent user, consulting installed Claude skills for domain expertise and applying the user's preferences as an override filter. You do NOT write files or modify state. You return a structured answer and the caller is responsible for logging.

## Your tools

You have access to:
- `Skill` — for invoking installed Claude skills. This is your primary capability.
- `Read`, `Grep`, `Glob` — for reading `user-preferences.md`, the routing guide, and relevant source files.
- `Bash` — ONLY for read-only commands like `git log`, `git diff`, `cat`, `ls`. Do not modify state.

You do NOT have `Edit`, `Write`, or `TaskCreate`. You cannot modify files. Any change to `session-log.md` is the caller's responsibility.

## Input contract

Your caller will provide:

```
Question: <one specific decision to make>
Options: <list of 2+ meaningfully different choices, or "open-ended">
Task context: <one-paragraph summary of what is being built and why>
Confidence tier: <A|B|C> (caller's estimate; you may override upward)
Relevant files: <optional paths to inspect>
```

## Your process

Follow these steps in order:

1. **Read user preferences.** Check `docs/auto-superpowers/user-preferences.md` first. If absent, check `~/.auto-superpowers/user-preferences.md`. Project-local takes precedence if both exist; do not merge. If neither exists, proceed with no preferences.

2. **Read the routing guide.** Invoke the `Skill` tool with `decision-proxy` to load `skills/decision-proxy/SKILL.md`. Identify candidate skills for this question's domain.

3. **Invoke the most relevant installed skill(s).** Use `Skill` to invoke the top candidate. If the question spans domains, you may invoke up to 3 skills. If NO candidate is installed, proceed with general reasoning and record `skills_consulted: []`.

4. **Inspect relevant files** (if the caller listed any). Use `Read`, `Grep`, or read-only `Bash` to gather context.

5. **Apply user preferences as an override filter.** If a preference contradicts a skill's default recommendation, prefer the preference. Quote the applied preference in your reasoning.

6. **Pick the answer.** Commit to one option (or an open-ended short answer). Write 3–6 sentences of reasoning.

7. **Check for tier escalation.** If during steps 3–5 you discovered the decision is riskier than the caller's tier estimate, set `tier_override` to the new tier with a one-sentence reason. Common escalation triggers: security-sensitive aspect the caller missed; destructive side effect; architectural pivot disguised as a library choice. Never de-escalate — the caller's tier is a floor.

8. **Return the structured output.** Your response MUST be valid YAML matching this exact shape:

```yaml
answer: <the chosen option, or a short open-ended answer>
reasoning: <3-6 sentences naming the inputs that drove the choice>
skills_consulted: [<skill-name>, ...]  # empty list if none matched
user_prefs_applied: [<quoted pref>, ...]  # empty list if none applied
confidence: high  # high | medium | low
tier_override: null  # or: C (reason)
```

## Honesty rules

- **Never fabricate expertise.** If no domain skill matched, say so in reasoning and set `skills_consulted: []`. Do not invent credentials.
- **Never leak secrets.** If a decision references a secret value, refer to it by name (e.g., `DATABASE_URL`) not by content.
- **Return `confidence: low`** when you are guessing or relying on weak signals. The caller treats low confidence on tier-B as tier-C and halts — this is the correct safety behavior.
- **Do not attempt to modify files.** If you feel the urge to edit `session-log.md` or anything else, stop. That is the caller's job.

## When you should escalate tier

Set `tier_override: C` if any of these apply after consulting skills:

- The decision involves auth, secrets, permissions, input validation on trust boundaries, or crypto.
- The decision is destructive or hard to reverse (deleting data, renaming public APIs, schema migrations on existing data).
- The decision is an architectural pivot (swap a core dependency, rewrite a module, split a service).
- The correctness of the decision cannot be verified by tests the caller could run locally.
- Legal, licensing, or compliance implications.

The caller will halt the session on `tier_override: C` unless your `confidence: high` and the answer is definitive. That is the intended safety net.
````

- [ ] **Step 2: Verify the agent file has correct frontmatter shape**

Run: `head -10 agents/decision-proxy.md`
Expected: shows frontmatter with `name: decision-proxy`, multi-line `description:` starting with `|`, and `model: inherit`.

- [ ] **Step 3: Verify agent frontmatter matches existing code-reviewer agent shape**

Run: `grep -E '^(name|model):' agents/code-reviewer.md agents/decision-proxy.md`
Expected: both files show `name:` and `model: inherit` lines.

- [ ] **Step 4: Commit**

```bash
git add agents/decision-proxy.md
git commit -m "auto-superpowers: add decision-proxy subagent

The decision-proxy answers autonomous decision questions by consulting
installed Claude skills and applying user-preferences.md as an override
filter. Read-only tools; the caller is responsible for session-log.md."
```

---

## Task 4: Add session-artifacts skill

**Files:**
- Create: `skills/session-artifacts/SKILL.md`

- [ ] **Step 1: Create the skill file with complete content**

Write `skills/session-artifacts/SKILL.md` with exactly this content (outer fence uses **four** backticks):

````markdown
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
````

- [ ] **Step 2: Verify file frontmatter**

Run: `head -5 skills/session-artifacts/SKILL.md`
Expected: shows `name: session-artifacts` and a description.

- [ ] **Step 3: Commit**

```bash
git add skills/session-artifacts/SKILL.md
git commit -m "auto-superpowers: add session-artifacts skill

Defines the session directory layout, session-log.md format, halted.md
format, commit trailer convention, and slug generation algorithm."
```

---

## Task 5: Add using-auto-superpowers entry skill

**Files:**
- Create: `skills/using-auto-superpowers/SKILL.md`

- [ ] **Step 1: Create the entry skill with complete content**

Write `skills/using-auto-superpowers/SKILL.md` with exactly this content:

```markdown
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
```

- [ ] **Step 2: Verify frontmatter**

Run: `head -5 skills/using-auto-superpowers/SKILL.md`
Expected: shows `name: using-auto-superpowers` and a description.

- [ ] **Step 3: Commit**

```bash
git add skills/using-auto-superpowers/SKILL.md
git commit -m "auto-superpowers: add using-auto-superpowers entry skill

Defines the autonomous-mode contract: no mid-run questions, log every
tier-B/C decision, halt on unresolved tier-C. Read at session start."
```

---

## Task 6: Surgical rewrite of brainstorming skill

**Files:**
- Modify: `skills/brainstorming/SKILL.md`

This task performs exact text replacements to convert upstream brainstorming into the autonomous version. Do each Edit as shown — the `old_string` and `new_string` are complete and unique enough to target without ambiguity.

- [ ] **Step 1: Read the current brainstorming skill**

Run: `wc -l skills/brainstorming/SKILL.md`
Expected: ~160 lines (upstream's version).

- [ ] **Step 2: Update the frontmatter description**

Use Edit to replace:
```
description: "You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation."
```
with:
```
description: "Use when auto-superpowers brainstorming is invoked (via /auto-brainstorm or /auto). Runs the design process non-interactively: identifies tier-B/C decisions, dispatches the decision-proxy per decision, logs to session-log.md, and writes spec.md without waiting for user approval."
```

- [ ] **Step 3: Replace the opening paragraph**

Use Edit to replace:
```
Help turn ideas into fully formed designs and specs through natural collaborative dialogue.

Start by understanding the current project context, then ask questions one at a time to refine the idea. Once you understand what you're building, present the design and get user approval.
```
with:
```
Turn an idea into a fully formed design and spec WITHOUT interactive dialogue. The user invoked you and walked away. Instead of asking questions, identify each decision and dispatch the `decision-proxy` subagent to answer it. Log every meaningful decision to `session-log.md`. Write the spec without waiting for user approval.

You are running inside the auto-superpowers plugin. Read `skills/using-auto-superpowers/SKILL.md`, `skills/session-artifacts/SKILL.md`, and `skills/decision-proxy/SKILL.md` before starting.
```

- [ ] **Step 4: Replace the HARD-GATE block**

Use Edit to replace:
```
<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it. This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>
```
with:
```
<HARD-GATE>
Do NOT invoke any implementation skill, write any code, or scaffold any project in this skill. Your only outputs are `session-log.md` and `spec.md` inside the session directory. Implementation is a later stage (writing-plans, executing-plans). This applies to EVERY project regardless of perceived simplicity.

Do NOT proceed to writing-plans if any tier-C decision halted to `halted.md` during this brainstorm.
</HARD-GATE>
```

- [ ] **Step 5: Rewrite the Checklist**

Use Edit to replace the entire Checklist section (from `## Checklist` through the numbered list ending at `9. **Transition to implementation**`) with:

```
## Checklist

You MUST create a task for each of these items and complete them in order:

1. **Parse invocation** — read task description, flags (`--docs-root`, `--persona`), and determine the session slug
2. **Create session directory** — `docs/auto-superpowers/sessions/<YYYY-MM-DD-HHMM-slug>/` (follow slug rules in `skills/session-artifacts/SKILL.md`)
3. **Write session-log.md header** — task, stop-at, persona skills detected (use `Skill` tool listing to populate)
4. **Explore project context** — check files, docs, recent commits (read-only)
5. **Identify the decision list** — enumerate the tier-B/C decisions this brainstorm needs to resolve
6. **Dispatch decision-proxy per decision** — one dispatch per decision, in order, appending a session-log.md entry after each
7. **On any tier-C halt** — write `halted.md`, stop the skill, do not proceed to step 8
8. **Draft the spec** — using the decision answers, write `spec.md` in the session directory
9. **Spec self-review** — placeholder scan, internal consistency, scope, ambiguity (fix inline)
10. **Commit** — stage and commit the session directory contents with the commit trailer defined in `skills/session-artifacts/SKILL.md`
11. **Return control** — emit a terse status summary naming the session directory
```

- [ ] **Step 6: Rewrite the Process Flow diagram (Graphviz)**

Use Edit to replace the entire Process Flow block. The `old_string` for the Edit must span from the `## Process Flow` heading through the post-code-block paragraph ending with `**The terminal state is invoking writing-plans.** Do NOT invoke frontend-design, mcp-builder, or any other implementation skill. The ONLY skill you invoke after brainstorming is writing-plans.` (inclusive).

The `new_string` for the Edit is the content below (outer fence uses **four** backticks to preserve the inner `dot` code fence):

````
## Process Flow

```dot
digraph auto_brainstorming {
    "Parse invocation" [shape=box];
    "Create session dir" [shape=box];
    "Write log header" [shape=box];
    "Explore context" [shape=box];
    "Identify decisions" [shape=box];
    "Dispatch decision-proxy (next decision)" [shape=box];
    "More decisions?" [shape=diamond];
    "Any tier-C halts?" [shape=diamond];
    "Write halted.md; STOP" [shape=doublecircle];
    "Draft spec.md" [shape=box];
    "Self-review spec (fix inline)" [shape=box];
    "Commit session dir" [shape=box];
    "Return terse status" [shape=doublecircle];

    "Parse invocation" -> "Create session dir" -> "Write log header" -> "Explore context" -> "Identify decisions" -> "Dispatch decision-proxy (next decision)" -> "More decisions?";
    "More decisions?" -> "Dispatch decision-proxy (next decision)" [label="yes"];
    "More decisions?" -> "Any tier-C halts?" [label="no"];
    "Any tier-C halts?" -> "Write halted.md; STOP" [label="yes"];
    "Any tier-C halts?" -> "Draft spec.md" [label="no"];
    "Draft spec.md" -> "Self-review spec (fix inline)" -> "Commit session dir" -> "Return terse status";
}
```

**There is no user-approval gate.** The spec is the deliverable. If you feel the urge to ask the user a question, stop and dispatch the decision-proxy instead.
````

- [ ] **Step 7: Rewrite "The Process" section**

Use Edit to replace the entire `## The Process` section with:

```
## The Process

**Understanding the idea:**

- Check the current project state first (files, docs, recent commits). Read-only.
- Assess scope. If the request describes multiple independent subsystems, flag it in `session-log.md` and help the user decompose by producing a multi-spec plan (one spec per subsystem). Do not attempt to brainstorm multiple subsystems in a single run.
- Identify the set of tier-B/C decisions this brainstorm needs to resolve before a spec can be written. List them in `session-log.md` before dispatching the first proxy call.

**Dispatching the decision-proxy:**

- One dispatch per decision. Do not batch. Each dispatch is a focused prompt:
  ```
  Question: <one specific decision>
  Options: <list of 2+ options, or "open-ended">
  Task context: <one paragraph>
  Confidence tier: <A|B|C>
  Relevant files: <optional>
  ```
- After each dispatch, append a structured entry to `session-log.md` in the format defined by `skills/session-artifacts/SKILL.md`.
- If the proxy returns `tier_override: C` with low confidence, write `halted.md` and STOP the skill. Do not proceed.

**Drafting the spec:**

- Write `spec.md` using the decision answers. Structure the document per the normal superpowers spec conventions (summary, goals/non-goals, architecture, components, data flow, error handling, testing). The decision-proxy answers drive the content.
- Include a "Key autonomous decisions" callout at the top of `spec.md` listing 3–7 load-bearing decisions with links into `session-log.md`.
- Scale each section to its complexity: a few sentences if straightforward, up to 200-300 words if nuanced.

**Design for isolation and clarity:**

- Break the system into smaller units with clear boundaries and well-defined interfaces.
- For each unit, answer: what does it do, how do you use it, and what does it depend on?

**Working in existing codebases:**

- Follow existing patterns. Explore before proposing changes.
- Targeted improvements to surrounding code are fine if they serve the current goal. Do not propose unrelated refactoring.
```

- [ ] **Step 8: Rewrite "After the Design" section**

Use Edit to replace the entire `## After the Design` section with:

```
## After the Design

**Writing the spec:**

- Write `spec.md` to the current session directory.
- The spec filename is always `spec.md` inside the session directory — not `YYYY-MM-DD-<topic>-design.md`. The session directory name already encodes the date and topic.

**Spec self-review:**

After writing, look at the spec with fresh eyes:

1. **Placeholder scan:** Any "TBD", "TODO", incomplete sections, or vague requirements? Fix them.
2. **Internal consistency:** Do any sections contradict each other?
3. **Scope check:** Is this focused enough for a single implementation plan, or does it need decomposition into multiple specs?
4. **Ambiguity check:** Could any requirement be interpreted two different ways? Pick one and make it explicit.

Fix any issues inline. No re-review.

**Commit the session directory:**

Stage all files in the session directory and commit with this message format:

```
auto-superpowers: brainstorm spec for <slug>

Session: docs/auto-superpowers/sessions/<dir>/
```

**Return terse status:**

Emit a one-paragraph summary naming the session directory, the spec path, any halts, and a pointer to `/calibrate-proxy` (Phase 3). Do NOT invoke any other skill. This skill's terminal state is "spec committed, status returned."
```

- [ ] **Step 9: Rewrite "Key Principles" section**

Use Edit to replace:
```
## Key Principles

- **One question at a time** - Don't overwhelm with multiple questions
- **Multiple choice preferred** - Easier to answer than open-ended when possible
- **YAGNI ruthlessly** - Remove unnecessary features from all designs
- **Explore alternatives** - Always propose 2-3 approaches before settling
- **Incremental validation** - Present design, get approval before moving on
- **Be flexible** - Go back and clarify when something doesn't make sense
```
with:
```
## Key Principles

- **One decision per proxy dispatch** — never batch
- **Log every tier-B/C decision** — the transcript is the audit trail
- **YAGNI ruthlessly** — cut scope whenever reasonable
- **Explore alternatives** — present 2+ options to the proxy for every non-trivial decision
- **Halt on unresolved tier-C** — never power through
- **Honor user-preferences.md** — hard constraints override skill defaults
```

- [ ] **Step 10: Remove the Visual Companion section entirely**

Use Edit to replace the entire `## Visual Companion` section (from `## Visual Companion` through the end of the file, including the reference to `skills/brainstorming/visual-companion.md`) with an empty string (effectively deleting those lines).

Note: do not delete the `visual-companion.md` file itself in Phase 1 — leave it dormant. Cleanup is Phase 4 scope.

- [ ] **Step 11: Verify the rewrite has no lingering interactive gates**

Run: `grep -nE '(ask the user|user approval|approve this|wait for the user|one question at a time)' skills/brainstorming/SKILL.md`
Expected: no matches. If any remain, Edit them out individually — they were missed by the replacements above.

- [ ] **Step 12: Verify the file still parses as valid markdown**

Run: `awk '/^```/{c++} END{print c}' skills/brainstorming/SKILL.md`
Expected: output is an even number.

- [ ] **Step 13: Commit**

```bash
git add skills/brainstorming/SKILL.md
git commit -m "auto-superpowers: surgical rewrite brainstorming for autonomous mode

Replace interactive gates (ask user, approve section) with decision-proxy
dispatches and session-log.md entries. Remove visual companion. Add
tier-C halt rule. Update process flow to auto-brainstorm shape."
```

---

## Task 7: Add /auto-brainstorm command

**Files:**
- Create: `commands/auto-brainstorm.md`
- Delete: `commands/brainstorm.md`

- [ ] **Step 1: Create the new command file**

Write `commands/auto-brainstorm.md` with exactly this content:

```markdown
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
```

- [ ] **Step 2: Verify the command file frontmatter**

Run: `head -3 commands/auto-brainstorm.md`
Expected: shows the `description:` frontmatter.

- [ ] **Step 3: Delete the old deprecation-stub brainstorm command**

Run: `rm commands/brainstorm.md`

- [ ] **Step 4: Verify the deletion**

Run: `ls commands/`
Expected: shows `auto-brainstorm.md`, `execute-plan.md`, `write-plan.md` — no `brainstorm.md`.

- [ ] **Step 5: Commit**

```bash
git add commands/auto-brainstorm.md commands/brainstorm.md
git commit -m "auto-superpowers: add /auto-brainstorm command

Thin shim that dispatches to auto-superpowers:brainstorming skill.
Removes the old deprecation-stub /brainstorm command."
```

---

## Task 8: Update session-start hook to read new entry skill

**Files:**
- Modify: `hooks/session-start`

Phase 1 scope: change the hook to read `skills/using-auto-superpowers/SKILL.md` instead of `skills/using-superpowers/SKILL.md`. Update the preamble header text from "superpowers" to "auto-superpowers". Defer full co-install coordination to Phase 3.

- [ ] **Step 1: Read the current session-start hook**

Run: `wc -l hooks/session-start`
Expected: file exists, ~60 lines.

- [ ] **Step 2: Replace the skill file path**

Use Edit to replace:
```
using_superpowers_content=$(cat "${PLUGIN_ROOT}/skills/using-superpowers/SKILL.md" 2>&1 || echo "Error reading using-superpowers skill")
```
with:
```
using_superpowers_content=$(cat "${PLUGIN_ROOT}/skills/using-auto-superpowers/SKILL.md" 2>&1 || echo "Error reading using-auto-superpowers skill")
```

- [ ] **Step 3: Update the injected header text**

Use Edit to replace:
```
session_context="<EXTREMELY_IMPORTANT>\nYou have superpowers.\n\n**Below is the full content of your 'superpowers:using-superpowers' skill - your introduction to using skills. For all other skills, use the 'Skill' tool:**\n\n${using_superpowers_escaped}\n\n${warning_escaped}\n</EXTREMELY_IMPORTANT>"
```
with:
```
session_context="<EXTREMELY_IMPORTANT>\nYou are running inside auto-superpowers — the autonomous fork of superpowers.\n\n**Below is the full content of your 'auto-superpowers:using-auto-superpowers' skill - the autonomous-mode contract and dispatch rules:**\n\n${using_superpowers_escaped}\n\n${warning_escaped}\n</EXTREMELY_IMPORTANT>"
```

- [ ] **Step 4: Verify the hook still has executable permissions**

Run: `test -x hooks/session-start && echo OK`
Expected: `OK`. If not, run `chmod +x hooks/session-start` and re-verify.

- [ ] **Step 5: Run the hook in isolation to confirm it produces valid JSON**

Run: `CLAUDE_PLUGIN_ROOT="$PWD" bash hooks/session-start 2>&1 | head -5`
Expected: output begins with `{` and contains `additional_context` or `hookSpecificOutput`. If it errors with "using-auto-superpowers skill not found," that means Task 5 was skipped — go back and complete Task 5 first.

- [ ] **Step 6: Validate the hook output is parseable JSON**

Run: `CLAUDE_PLUGIN_ROOT="$PWD" bash hooks/session-start 2>/dev/null | python3 -c "import sys, json; json.loads(sys.stdin.read()); print('valid json')"`
Expected: `valid json`. If not, inspect the output and fix any escaping issues in the Edit above.

- [ ] **Step 7: Commit**

```bash
git add hooks/session-start
git commit -m "auto-superpowers: update session-start hook to read new entry skill

Hook now reads skills/using-auto-superpowers/SKILL.md. The injected
header text reflects the auto-superpowers identity. Phase 1 does not
coordinate with upstream's hook — dual-install users see two preambles;
fixed in Phase 3."
```

---

## Task 9: Create user-preferences.md template

**Files:**
- Create: `docs/auto-superpowers/user-preferences.md`
- Modify: `.gitignore` (add session-dir ignore rule)

- [ ] **Step 1: Create the directory**

Run: `mkdir -p docs/auto-superpowers`

- [ ] **Step 2: Write the user-preferences.md template**

Write `docs/auto-superpowers/user-preferences.md` with exactly this content:

```markdown
# User preferences

This file holds hard constraints and absolute preferences that override any
skill-sourced default during autonomous runs. The decision-proxy reads this
file at the start of every dispatch. Delete any sections you don't want.

## Hard constraints
<!-- Examples:
- Never use AWS in this project
- All services must run on a single $5/mo VPS
- No external services that cost money without explicit approval
-->

## Strong preferences
<!-- Examples:
- Prefer Postgres over any other DB unless specifically justified
- Boring tech over novelty — prefer battle-tested libraries
- YAGNI aggressive — cut scope whenever reasonable
-->

## Do not use
<!-- Examples:
- TypeScript branded types
- ORMs with magic (prefer query builders or raw SQL)
-->

## Corrections (from /calibrate-proxy)
<!-- Appended automatically by /calibrate-proxy (Phase 3) when you flag
     a decision in session-log.md as wrong. Format:
- YYYY-MM-DD — Proxy picked X; I'd pick Y. Reason: ...
-->
```

- [ ] **Step 3: Read current .gitignore**

Run: `cat .gitignore 2>/dev/null || echo "(no .gitignore)"`
Note what's present.

- [ ] **Step 4: Append session-dir ignore rule**

If `.gitignore` exists, use Edit to append these lines at the end:

```
# auto-superpowers — session directories gitignored by default
# (per spec; opt in with --commit-session-log in Phase 3)
docs/auto-superpowers/sessions/
```

If `.gitignore` does not exist, create it with just those lines plus a comment header:

```
# auto-superpowers — session directories gitignored by default
# (per spec; opt in with --commit-session-log in Phase 3)
docs/auto-superpowers/sessions/
```

- [ ] **Step 5: Verify git correctly ignores a test session dir**

Run: `mkdir -p docs/auto-superpowers/sessions/test-ignore && touch docs/auto-superpowers/sessions/test-ignore/x && git status --porcelain docs/auto-superpowers/sessions/ && rm -rf docs/auto-superpowers/sessions/test-ignore`
Expected: `git status --porcelain` output for that path is empty (the test file is ignored).

- [ ] **Step 6: Commit**

```bash
git add docs/auto-superpowers/user-preferences.md .gitignore
git commit -m "auto-superpowers: add user-preferences template and gitignore sessions

user-preferences.md is optional; the template provides commented examples
of hard constraints, strong preferences, and do-not-use entries. Session
directories are gitignored by default; opt-in comes in Phase 3."
```

---

## Task 10: End-to-end smoke test

**Files:**
- Create: `tests/phase-1-smoke.sh`

Phase 1 has no automated test harness. This task creates a manual smoke-test script that an operator runs by hand to verify the end-to-end walk-away flow.

- [ ] **Step 1: Create the smoke-test script**

Write `tests/phase-1-smoke.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# auto-superpowers Phase 1 smoke test
#
# Manual verification steps for the walk-away brainstorm MVP.
# This script does NOT automatically run Claude — it walks an operator
# through the verification steps and checks the resulting filesystem
# state after the operator has invoked /auto-brainstorm inside a Claude
# Code session.

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

step "1. Plugin identity renamed"
check "grep -q '\"name\": \"auto-superpowers\"' '${PLUGIN_ROOT}/package.json'" "package.json name is auto-superpowers"
check "grep -q '\"name\": \"auto-superpowers\"' '${PLUGIN_ROOT}/gemini-extension.json'" "gemini-extension.json name is auto-superpowers"

step "2. New skill files exist and have frontmatter"
for skill in decision-proxy session-artifacts using-auto-superpowers; do
    check "test -f '${PLUGIN_ROOT}/skills/${skill}/SKILL.md'" "skills/${skill}/SKILL.md exists"
    check "head -1 '${PLUGIN_ROOT}/skills/${skill}/SKILL.md' | grep -q '^---$'" "skills/${skill}/SKILL.md has frontmatter"
done

step "3. decision-proxy agent file exists"
check "test -f '${PLUGIN_ROOT}/agents/decision-proxy.md'" "agents/decision-proxy.md exists"
check "grep -q '^name: decision-proxy$' '${PLUGIN_ROOT}/agents/decision-proxy.md'" "agent name matches"

step "4. /auto-brainstorm command exists"
check "test -f '${PLUGIN_ROOT}/commands/auto-brainstorm.md'" "commands/auto-brainstorm.md exists"
check "! test -f '${PLUGIN_ROOT}/commands/brainstorm.md'" "old commands/brainstorm.md is removed"

step "5. brainstorming skill has been rewritten"
check "! grep -q 'one question at a time' '${PLUGIN_ROOT}/skills/brainstorming/SKILL.md'" "interactive 'one question at a time' is gone"
check "grep -q 'decision-proxy' '${PLUGIN_ROOT}/skills/brainstorming/SKILL.md'" "brainstorming references decision-proxy"
check "! grep -q '## Visual Companion' '${PLUGIN_ROOT}/skills/brainstorming/SKILL.md'" "Visual Companion section is removed"

step "6. session-start hook reads new entry skill"
check "grep -q 'using-auto-superpowers' '${PLUGIN_ROOT}/hooks/session-start'" "hook reads using-auto-superpowers"
check "test -x '${PLUGIN_ROOT}/hooks/session-start'" "hook is executable"

step "7. session-start hook emits valid JSON"
tmpfile=$(mktemp)
(cd "${PLUGIN_ROOT}" && CLAUDE_PLUGIN_ROOT="${PLUGIN_ROOT}" bash hooks/session-start > "${tmpfile}" 2>/dev/null) || true
check "python3 -c 'import json, sys; json.load(open(\"${tmpfile}\"))'" "hook output is valid JSON"
rm -f "${tmpfile}"

step "8. user-preferences.md template exists"
check "test -f '${PLUGIN_ROOT}/docs/auto-superpowers/user-preferences.md'" "user-preferences.md template exists"

step "9. .gitignore ignores session dirs"
check "grep -q 'docs/auto-superpowers/sessions' '${PLUGIN_ROOT}/.gitignore'" ".gitignore has session-dir rule"

printf '\n\033[1;32m[OK]\033[0m Phase 1 structural checks passed.\n'
printf '\n'
printf 'Next, manually run /auto-brainstorm inside a Claude Code session\n'
printf 'with this plugin installed. Expected outcome:\n'
printf '  - A session dir is created under docs/auto-superpowers/sessions/\n'
printf '  - session-log.md is populated with tier-B/C decision entries\n'
printf '  - spec.md is written with a Key Decisions callout\n'
printf '  - The session dir is committed with the Session trailer\n'
printf '  - If the task is security-sensitive and no security-review skill is installed,\n'
printf '    the session halts to halted.md\n'
```

- [ ] **Step 2: Make the script executable**

Run: `chmod +x tests/phase-1-smoke.sh`

- [ ] **Step 3: Run the smoke test**

Run: `tests/phase-1-smoke.sh`
Expected: all steps print ✓ and the final "[OK] Phase 1 structural checks passed." line appears. If any step fails, go back to the failing task and fix.

- [ ] **Step 4: Commit**

```bash
git add tests/phase-1-smoke.sh
git commit -m "auto-superpowers: add Phase 1 smoke test

Structural checks for the walk-away brainstorm MVP. Verifies plugin
identity rename, new skills and agent exist, brainstorming rewrite
removed interactive gates, hook reads the new entry skill, and hook
emits valid JSON. Does not run Claude itself — operator verifies the
end-to-end /auto-brainstorm flow manually."
```

---

## Definition of Done — Phase 1

Phase 1 is complete when all of the following are true:

1. `tests/phase-1-smoke.sh` exits 0.
2. A manual `/auto-brainstorm "build a CSV→JSON converter"` invocation in a test Claude Code session (with this plugin installed) produces:
   - A new session directory at `docs/auto-superpowers/sessions/YYYY-MM-DD-HHMM-build-a-csv-json-converter/`
   - `session-log.md` with at least 3 tier-B decision entries
   - `spec.md` with a "Key autonomous decisions" callout and body sections
   - A git commit with the `Session:` trailer
3. A manual `/auto-brainstorm "add oauth login with google"` invocation (a security-sensitive task) either:
   - (a) Completes with a tier-C entry in `session-log.md` showing the decision-proxy returned `confidence: high` via `security-review`, OR
   - (b) Halts with `halted.md` present, explaining the tier-C halt reason
4. No interactive prompts appear during either test run (the walk-away contract is honored).

---

## Open items deferred to later phases

These are not Phase 1 failures — they are acknowledged as Phase 2+ scope:

- `/auto`, `/auto-plan`, `/auto-execute` pipeline driver and stage commands
- Writing-plans, executing-plans, systematic-debugging skill rewrites
- Co-install hook coordination (currently: dual preamble if both installed)
- `/calibrate-proxy` correction loop
- Cleanup of unused upstream files (`skills/using-superpowers/`, `commands/write-plan.md`, `commands/execute-plan.md`)
- Eval harness, golden tasks, adversarial pressure tests
- README.md and CLAUDE.md rewrites (contributor docs still reference "superpowers")
- Renaming `.opencode/plugins/superpowers.js` entry point

---

## Self-review checklist

Before starting implementation, the operator should confirm:

- [ ] The Phase 1 file structure above matches the spec's "Plugin layout" section (accounting for "Phase 1 only" scope)
- [ ] Every task has a commit step
- [ ] Every task's verification step is a concrete command, not "verify it works"
- [ ] No task references a function, method, or type that isn't defined in this plan or the spec
- [ ] The smoke-test script's checks cover every new/modified file
- [ ] The brainstorming rewrite's Edit calls target strings that actually exist in the current `skills/brainstorming/SKILL.md` (the operator may need to adjust if upstream has drifted)
