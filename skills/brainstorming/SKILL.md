---
name: brainstorming
description: "Use when auto-superpowers brainstorming is invoked (via /auto-brainstorm or /auto). Runs the design process non-interactively: identifies tier-B/C decisions, dispatches the decision-proxy per decision, logs to session-log.md, and writes spec.md without waiting for user approval."
---

# Brainstorming Ideas Into Designs

Turn an idea into a fully formed design and spec WITHOUT interactive dialogue. The user invoked you and walked away. Instead of asking questions, identify each decision and dispatch the `decision-proxy` subagent to answer it. Log every meaningful decision to `session-log.md`. Write the spec without waiting for user approval.

You are running inside the auto-superpowers plugin. Read `skills/using-auto-superpowers/SKILL.md`, `skills/session-artifacts/SKILL.md`, and `skills/decision-proxy/SKILL.md` before starting.

<HARD-GATE>
Do NOT invoke any implementation skill, write any code, or scaffold any project in this skill. Your only outputs are `session-log.md` and `spec.md` inside the session directory. Implementation is a later stage (writing-plans, executing-plans). This applies to EVERY project regardless of perceived simplicity.

Do NOT proceed to writing-plans if any tier-C decision halted to `halted.md` during this brainstorm.
</HARD-GATE>

## Anti-Pattern: "This Is Too Simple To Need A Design"

Every project goes through this process. A todo list, a single-function utility, a config change — all of them. "Simple" projects are where unexamined assumptions cause the most wasted work. The design can be short (a few sentences for truly simple projects), but you MUST produce one.

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

## Key Principles

- **One decision per proxy dispatch** — never batch
- **Log every tier-B/C decision** — the transcript is the audit trail
- **YAGNI ruthlessly** — cut scope whenever reasonable
- **Explore alternatives** — present 2+ options to the proxy for every non-trivial decision
- **Halt on unresolved tier-C** — never power through
- **Honor user-preferences.md** — hard constraints override skill defaults
