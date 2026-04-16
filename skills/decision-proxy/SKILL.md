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
