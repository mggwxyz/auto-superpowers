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
