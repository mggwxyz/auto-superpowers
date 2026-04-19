---
name: receiving-code-review
description: "Use when auto-superpowers receives code review feedback during autonomous execution. Dispatches decision-proxy for unclear feedback and pushback decisions instead of asking the user. Tier-based routing replaces source-based handling."
---

# Code Review Reception

## Overview

Code review requires technical evaluation, not emotional performance.

**Context:** You are running inside the auto-superpowers plugin. The user is not at the keyboard. Any feedback you receive comes from a code-reviewer subagent or from GitHub PR comments discovered during execution. Never ask the user for clarification — dispatch the decision-proxy instead.

**Input parsing:** Look for `SESSION_DIR: <path>` sentinel in the input prompt. If present, use it for session-log.md entries.

<HARD-GATE>
Do NOT proceed if `<session-dir>/halted.md` exists. A prior stage halted on a tier-C decision and the user has not resumed. Return terse status reporting the halt and stop.
</HARD-GATE>

**Core principle:** Verify before implementing. Ask before assuming. Technical correctness over social comfort.

## The Response Pattern

```
WHEN receiving code review feedback:

1. READ: Complete feedback without reacting
2. UNDERSTAND: Restate requirement in own words (or ask)
3. VERIFY: Check against codebase reality
4. EVALUATE: Technically sound for THIS codebase?
5. RESPOND: Technical acknowledgment or reasoned pushback
6. IMPLEMENT: One item at a time, test each
```

## Forbidden Responses

**NEVER:**
- "You're absolutely right!" (explicit CLAUDE.md violation)
- "Great point!" / "Excellent feedback!" (performative)
- "Let me implement that now" (before verification)

**INSTEAD:**
- Restate the technical requirement
- Ask clarifying questions
- Push back with technical reasoning if wrong
- Just start working (actions > words)

## Handling Unclear Feedback

```
IF any feedback item is unclear:
  Dispatch decision-proxy with tier: B for each unclear item
  Question: "Review feedback says '<item>'. What does this mean in context of <file/function>?"
  Options: [interpret as X, interpret as Y, skip — not actionable]

  IF proxy resolves it: apply the resolution, log to session-log.md
  IF proxy cannot resolve (low confidence): add to halted.md as tier-C halt, STOP

WHY: Guessing at unclear feedback produces wrong fixes. The proxy either resolves it or halts.
```

## Source-Specific Handling

### From code-reviewer subagent
- **Tier A/B by default** — the subagent is a peer, not a user
- Implement after verification against codebase
- No performative agreement (same as upstream)
- If feedback contradicts the plan or spec, dispatch `decision-proxy` with tier: B to resolve the conflict

### From GitHub PR comments (external reviewers)
- **Tier B/C depending on scope:**
  - Style, naming, minor refactors → tier B: dispatch `decision-proxy`, apply resolution
  - Architecture changes, scope expansion, security concerns → tier C: dispatch `decision-proxy` with `tier: C`. If proxy returns high confidence, apply. Otherwise halt to `halted.md`.
- Before implementing: verify technically correct for THIS codebase (same checks as upstream)
- If suggestion conflicts with the plan's architectural decisions, that is tier C — dispatch proxy

## YAGNI Check for "Professional" Features

```
IF reviewer suggests "implementing properly":
  grep codebase for actual usage

  IF unused: "This endpoint isn't called. Remove it (YAGNI)?"
  IF used: Then implement properly
```

**Design principle:** "You and reviewer both report to the spec. If we don't need this feature, don't add it."

## Implementation Order

```
FOR multi-item feedback:
  1. Clarify anything unclear FIRST
  2. Then implement in this order:
     - Blocking issues (breaks, security)
     - Simple fixes (typos, imports)
     - Complex fixes (refactoring, logic)
  3. Test each fix individually
  4. Verify no regressions
```

## When To Push Back

Push back when the same conditions as upstream apply (breaks functionality, reviewer lacks context, violates YAGNI, technically incorrect, legacy reasons, conflicts with architectural decisions).

**How to push back (autonomous mode):**
- For non-trivial pushback decisions, dispatch `decision-proxy` with the feedback item and your technical reasoning as context. The proxy can invoke `auto-superpowers:code-reviewer` for a second opinion.
- If the proxy agrees with pushback: note the pushback in session-log.md, do not implement the item.
- If the proxy disagrees: implement the feedback, note the override in session-log.md.
- If the proxy cannot decide (low confidence on tier-C scope): halt to `halted.md`.

## Acknowledging Correct Feedback

When feedback IS correct:
```
✅ "Fixed. [Brief description of what changed]"
✅ "Good catch - [specific issue]. Fixed in [location]."
✅ [Just fix it and show in the code]

❌ "You're absolutely right!"
❌ "Great point!"
❌ "Thanks for catching that!"
❌ "Thanks for [anything]"
❌ ANY gratitude expression
```

**Why no thanks:** Actions speak. Just fix it. The code itself shows you heard the feedback.

**If you catch yourself about to write "Thanks":** DELETE IT. State the fix instead.

## Gracefully Correcting Your Pushback

If you pushed back and were wrong:
```
✅ "You were right - I checked [X] and it does [Y]. Implementing now."
✅ "Verified this and you're correct. My initial understanding was wrong because [reason]. Fixing."

❌ Long apology
❌ Defending why you pushed back
❌ Over-explaining
```

State the correction factually and move on.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Performative agreement | State requirement or just act |
| Blind implementation | Verify against codebase first |
| Batch without testing | One at a time, test each |
| Assuming reviewer is right | Check if breaks things |
| Avoiding pushback | Technical correctness > comfort |
| Partial implementation | Clarify all items first |
| Can't verify, proceed anyway | State limitation, ask for direction |

## Real Examples

**Performative Agreement (Bad):**
```
Reviewer: "Remove legacy code"
❌ "You're absolutely right! Let me remove that..."
```

**Technical Verification (Good):**
```
Reviewer: "Remove legacy code"
✅ "Checking... build target is 10.15+, this API needs 13+. Need legacy for backward compat. Current impl has wrong bundle ID - fix it or drop pre-13 support?"
```

**YAGNI (Good):**
```
Reviewer: "Implement proper metrics tracking with database, date filters, CSV export"
✅ "Grepped codebase - nothing calls this endpoint. Remove it (YAGNI)? Or is there usage I'm missing?"
```

**Unclear Item (Good):**
```
the plan: "Fix items 1-6"
You understand 1,2,3,6. Unclear on 4,5.
✅ "Understand 1,2,3,6. Need clarification on 4 and 5 before implementing."
```

## GitHub Thread Replies

When replying to inline review comments on GitHub, reply in the comment thread (`gh api repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies`), not as a top-level PR comment.

## The Bottom Line

**External feedback = suggestions to evaluate, not orders to follow.**

Verify. Question. Then implement.

No performative agreement. Technical rigor always.
