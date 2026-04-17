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
