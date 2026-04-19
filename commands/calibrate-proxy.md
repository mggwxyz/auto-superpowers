---
description: "Review autonomous decisions from a session and calibrate the decision-proxy by correcting mistakes and adding preferences to user-preferences.md."
---

You have been invoked via the `/calibrate-proxy` command. Unlike all other auto-superpowers commands, this one IS interactive — the user is at the keyboard and expects a conversation.

**Parse arguments from `$ARGUMENTS`:**

- `--session <dir>` — the session directory to review. Optional; defaults to the most recent directory under `docs/auto-superpowers/sessions/`.

**Steps:**

1. **Find the session directory.** If `--session` was provided, use it. Otherwise, find the most recent directory under `docs/auto-superpowers/sessions/` (by directory name sort, which encodes date). If no session directory exists, emit usage error and stop:
   ```
   calibrate-proxy: no session found. Usage: /calibrate-proxy [--session <dir>]
   ```

2. **Read session-log.md.** Parse all decision entries (sections matching `### Decision N — <title>` or `### HH:MM | <title>` with `- **Tier:** B` or `- **Tier:** C`). If no tier-B/C decisions found, emit:
   ```
   calibrate-proxy: No tier-B/C decisions found in <session-dir>/session-log.md. Nothing to calibrate.
   ```
   and stop.

3. **For each tier-B/C decision, present to the user:**

   ```
   Decision N: <question or title>
   Proxy chose: <answer>
   Reasoning: <one-line summary from reasoning field>
   Confidence: <high/medium/low>

   [k]eep / [c]orrect / [a]dd preference / [s]kip? _
   ```

   Wait for the user's response.

4. **Handle responses:**

   - **`k` (keep):** Move to the next decision. No action.
   - **`c` (correct):** Ask: "What would you have chosen?" Record the user's answer in `docs/auto-superpowers/user-preferences.md` under the `## Corrections` section with format:
     ```
     - YYYY-MM-DD — Proxy picked <X>; I'd pick <Y>. Reason: <user's reason>
     ```
   - **`a` (add preference):** Ask: "What preference should guide future decisions like this?" Add to the appropriate section of `docs/auto-superpowers/user-preferences.md`:
     - Security, compliance, or "never do X" → `## Hard constraints`
     - Technology, library, or pattern preferences → `## Strong preferences`
     - Specific tools or patterns to avoid → `## Do not use`
     - Correction from a past decision → `## Corrections`
     Ask which section if ambiguous (this is interactive, so asking is fine).
   - **`s` (skip):** Move to the next decision. No action.

5. **After all decisions reviewed, emit summary:**
   ```
   calibrate-proxy: Reviewed N decisions. K kept, C corrected, A preferences added, S skipped.
   ```

**Notes:**
- This is the ONLY interactive command in auto-superpowers. All other commands run non-interactively.
- The corrections and preferences written here improve future autonomous sessions — the decision-proxy reads user-preferences.md at the start of every dispatch.
- Do NOT modify session-log.md — it is an immutable audit trail of what happened during the session.
