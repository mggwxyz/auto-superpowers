#!/usr/bin/env bash
# auto-superpowers Phase 3 smoke test
#
# Structural checks for the completion pipeline, code review rewrites,
# calibrate-proxy, and housekeeping deliverables. Verifies that:
#   - finishing-a-development-branch is rewritten for autonomous mode
#   - receiving-code-review references decision-proxy, no "stop and ask"
#   - requesting-code-review references session-log.md
#   - /calibrate-proxy command exists with frontmatter
#   - .opencode/plugins/auto-superpowers.js exists, superpowers.js does not
#   - README.md contains "auto-superpowers" and "walk away"
#   - CLAUDE.md references auto-superpowers namespace
#   - Session-start hook has co-install detection
#
# Does NOT run Claude — filesystem state only.

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

step "1. finishing-a-development-branch rewritten"
check "grep -q 'auto-superpowers:finishing-a-development-branch' '${PLUGIN_ROOT}/skills/finishing-a-development-branch/SKILL.md'" "announces as auto-superpowers skill"
check "grep -qE '<HARD-GATE>' '${PLUGIN_ROOT}/skills/finishing-a-development-branch/SKILL.md'" "has HARD-GATE"
check "grep -q 'STOP_AT:' '${PLUGIN_ROOT}/skills/finishing-a-development-branch/SKILL.md'" "parses STOP_AT sentinel"
check "grep -q 'SESSION_DIR:' '${PLUGIN_ROOT}/skills/finishing-a-development-branch/SKILL.md'" "parses SESSION_DIR sentinel"
check "! grep -q 'Present exactly these 4 options' '${PLUGIN_ROOT}/skills/finishing-a-development-branch/SKILL.md'" "no interactive 4-option menu"
check "grep -q 'gh pr create' '${PLUGIN_ROOT}/skills/finishing-a-development-branch/SKILL.md'" "has PR creation"
check "grep -q 'allow-auto-merge' '${PLUGIN_ROOT}/skills/finishing-a-development-branch/SKILL.md'" "references auto-merge preference"

step "2. receiving-code-review rewritten"
check "grep -q 'decision-proxy' '${PLUGIN_ROOT}/skills/receiving-code-review/SKILL.md'" "references decision-proxy"
check "grep -qE '<HARD-GATE>' '${PLUGIN_ROOT}/skills/receiving-code-review/SKILL.md'" "has HARD-GATE"
check "! grep -qi 'stop and ask' '${PLUGIN_ROOT}/skills/receiving-code-review/SKILL.md'" "no 'stop and ask' language"
check "! grep -q 'From your human partner' '${PLUGIN_ROOT}/skills/receiving-code-review/SKILL.md'" "no 'from your human partner' section"

step "3. requesting-code-review updated"
check "grep -q 'session-log.md' '${PLUGIN_ROOT}/skills/requesting-code-review/SKILL.md'" "references session-log.md"
check "grep -q 'SESSION_DIR' '${PLUGIN_ROOT}/skills/requesting-code-review/SKILL.md'" "references SESSION_DIR"

step "4. /calibrate-proxy command exists"
check "test -f '${PLUGIN_ROOT}/commands/calibrate-proxy.md'" "commands/calibrate-proxy.md exists"
check "head -1 '${PLUGIN_ROOT}/commands/calibrate-proxy.md' | grep -q '^---$'" "has frontmatter"
check "grep -q 'interactive' '${PLUGIN_ROOT}/commands/calibrate-proxy.md'" "mentions interactive"
check "grep -q 'user-preferences.md' '${PLUGIN_ROOT}/commands/calibrate-proxy.md'" "references user-preferences.md"

step "5. OpenCode plugin renamed"
check "test -f '${PLUGIN_ROOT}/.opencode/plugins/auto-superpowers.js'" "auto-superpowers.js exists"
check "! test -f '${PLUGIN_ROOT}/.opencode/plugins/superpowers.js'" "superpowers.js is gone"
check "grep -q 'auto-superpowers' '${PLUGIN_ROOT}/.opencode/plugins/auto-superpowers.js'" "file references auto-superpowers"
check "grep -q '\"main\": \".opencode/plugins/auto-superpowers.js\"' '${PLUGIN_ROOT}/package.json'" "package.json main updated"

step "6. README rewritten"
check "grep -q 'auto-superpowers' '${PLUGIN_ROOT}/README.md'" "README mentions auto-superpowers"
check "grep -qi 'walk away' '${PLUGIN_ROOT}/README.md'" "README mentions walk away"
check "grep -q '/calibrate-proxy' '${PLUGIN_ROOT}/README.md'" "README mentions calibrate-proxy"

step "7. CLAUDE.md updated"
check "grep -q 'auto-superpowers' '${PLUGIN_ROOT}/CLAUDE.md'" "CLAUDE.md mentions auto-superpowers"
check "grep -q '94%' '${PLUGIN_ROOT}/CLAUDE.md'" "upstream voice preserved (94%)"

step "8. Session-start hook has co-install detection"
check "grep -q 'SUPERPOWERS_PREAMBLE_INJECTED' '${PLUGIN_ROOT}/hooks/session-start'" "checks for upstream env var"
check "grep -q 'AUTO_SUPERPOWERS_PREAMBLE_INJECTED' '${PLUGIN_ROOT}/hooks/session-start'" "exports own env var"

step "9. Pipeline wiring for --stop-at=pr/merged"
check "grep -q 'finishing-a-development-branch' '${PLUGIN_ROOT}/commands/auto.md'" "/auto references finishing skill"
check "grep -q 'STOP_AT:' '${PLUGIN_ROOT}/skills/executing-plans/SKILL.md'" "executing-plans parses STOP_AT"
check "grep -q 'finishing-a-development-branch' '${PLUGIN_ROOT}/skills/executing-plans/SKILL.md'" "executing-plans chains to finishing skill"

step "10. Phase 1 and Phase 2 smoke tests still pass"
check "bash '${SCRIPT_DIR}/phase-1-smoke.sh' >/dev/null 2>&1" "phase-1-smoke.sh still green"
check "bash '${SCRIPT_DIR}/phase-2-smoke.sh' >/dev/null 2>&1" "phase-2-smoke.sh still green"

printf '\n\033[1;32m[OK]\033[0m Phase 3 structural checks passed.\n'
printf '\n'
printf 'Next, manually test:\n'
printf '  - /auto "task" --stop-at=pr creates a real PR with the rich template\n'
printf '  - /calibrate-proxy on the resulting session walks through decisions\n'
printf '  - Session-start hook with upstream installed produces only one preamble\n'
