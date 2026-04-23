# auto-superpowers

An autonomous fork of [superpowers](https://github.com/obra/superpowers) that runs spec → plan → execute pipelines non-interactively. Tell it what to build, walk away, come back to working code — or a clear explanation of why it stopped.

## Quick start

```bash
# Add the marketplace
/plugin marketplace add mggwxyz/auto-superpowers

# Install the plugin
/plugin install auto-superpowers@mggwxyz-auto-superpowers

# Start a new session and run the full pipeline
/auto "build a CLI tool that counts words per line in a file"
```

That's it. The agent brainstorms a spec, writes an implementation plan, executes it with TDD and verification gates, and stops when done. Every meaningful decision is logged to a session directory you can review afterward.

## How it works

auto-superpowers replaces interactive dialogue with a **decision-proxy** — a subagent that consults installed skills and `user-preferences.md` to answer questions the agent would normally ask you. Decisions are classified into tiers:

- **Tier A** (mechanical): decided silently
- **Tier B** (substantive): decided by the proxy, logged to `session-log.md`
- **Tier C** (load-bearing): decided by the proxy if high confidence, otherwise the session **halts** to `halted.md` and waits for you

The session directory (`docs/auto-superpowers/sessions/<timestamp-slug>/`) contains the full audit trail: `session-log.md`, `spec.md`, `plan.md`, and `halted.md` (if halted).

## Commands

| Command | What it does |
|---------|-------------|
| `/auto "task"` | Full pipeline: brainstorm → plan → execute |
| `/auto-brainstorm "task"` | Brainstorm only — produces `spec.md` |
| `/auto-plan` | Plan only — reads `spec.md`, produces `plan.md` |
| `/auto-execute` | Execute only — reads `plan.md`, implements with TDD |
| `/calibrate-proxy` | Review session decisions interactively (the only interactive command) |

### Pipeline control

- `--stop-at spec` — stop after brainstorming
- `--stop-at plan` — stop after planning
- `--stop-at impl` — stop after implementation (default)
- `--stop-at pr` — stop after creating a pull request
- `--stop-at merged` — same as `pr` until you opt into auto-merge

### Resuming halted sessions

```bash
/auto --resume docs/auto-superpowers/sessions/<dir>/
```

Read `halted.md`, provide your answer in `session-log.md` or `user-preferences.md`, then resume.

## Configuration

### user-preferences.md

Create or edit `docs/auto-superpowers/user-preferences.md` to guide autonomous decisions:

- **Hard constraints** — rules the proxy must never violate
- **Strong preferences** — defaults the proxy should follow unless there's a good reason not to
- **Do not use** — specific tools, patterns, or libraries to avoid
- **Corrections** — past mistakes flagged via `/calibrate-proxy`

The decision-proxy reads this file at the start of every dispatch. The more you calibrate, the better autonomous decisions get.

### Calibrating after a session

Run `/calibrate-proxy` after a session to review each tier-B/C decision. Keep good ones, correct bad ones, add preferences to guide future sessions.

## Dual-install with upstream superpowers

auto-superpowers can coexist with the upstream [superpowers](https://github.com/obra/superpowers) plugin. Both are namespaced distinctly:

- `/auto`, `/auto-brainstorm`, `/auto-plan`, `/auto-execute` → `auto-superpowers:*` skills (autonomous)
- `/brainstorm`, `/write-plan`, `/execute-plan` → `superpowers:*` skills (interactive)

No command name collisions. The session-start hook detects co-installation and avoids duplicate preambles.

## Contributing

See [CLAUDE.md](CLAUDE.md) for contributor guidelines. The short version: this fork maintains the same high PR bar as upstream superpowers (94% rejection rate). Read the guidelines before submitting.

## License

MIT License — see [LICENSE](LICENSE) file for details.

## Credits

auto-superpowers is built on top of [superpowers](https://github.com/obra/superpowers) by [Jesse Vincent](https://blog.fsck.com) and [Prime Radiant](https://primeradiant.com).
