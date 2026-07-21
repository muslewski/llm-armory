---
type: zone
summary: "armory CLI entrypoint (bin/llm): resolve loadouts, preflight, fleet spawn, doctor, dry-run mission cards, agent-status stamp, then exec grok/claude. Absolute constraint — non-TTY launch path stays byte-compatible."
tags: [cli, launcher, fleet, executor]
status: seeded
created: 2026-07-21
updated: 2026-07-21
verifiedAt: unverified
owns:
  routes: []
  testids: []
  globs:
    - "bin/llm"
    - "INTEROP.md"
    - "templates/**"
    - "package.json"
  tools: []
depends:
  - "[[loadouts]]"
  - "[[ui-surfaces]]"
invariants: []
skills: []
related:
  - "[[executor-hooks]]"
  - "[[fusion-advisor]]"
  - "[[tests]]"
sources: []
---

## What this is

The product surface of **llm-armory**: `bin/llm` (npm bins `armory` | `llm-armory` | `llm`). It sources a loadout from `presets/`, sanitizes parent env (`sanitize_parent_loadout`), checks auth/preflight, optionally injects executor hooks, stamps Agent Status Provider records, and `exec`s the child CLI (`grok` or `claude`). Subcommands: `--list` / `pick` / `--dry-run` / `doctor` / `fleet` / `fleet-status` / `fleet-report`.

## Subcommands

- **Arm path** — `armory <loadout> [args…]` including `-p` prompt and `-w` worktree under `<repo>/.claude/worktrees/<name>`.
- **Fleet** — manifest-driven parallel children (`name|prompt-file`), max-parallel / stagger / seed copies, bookkeeping `.child-out.log` / `.child-pid` / `.child-exit`.
- **Doctor / rack** — whole-armory health and READY/SKIP/DEAD badges per loadout.

## Launch constraint

`armory <loadout> -p <prompt>` is production infrastructure: same exec, exit-code propagation, no TTY requirement, chrome only on stderr and silent when stderr is not a TTY. Breaking the launch path breaks fleets.

## Agent status stamp

Immediately before `exec`, soft-fail write of schema-1 session + heartbeat under `$AGENT_STATUS_DIR` (see `INTEROP.md`). Kill switch: `AGENT_STATUS_DIR=/dev/null`.

## Anchors

- `bin/llm` — sole launcher implementation (~1.4k lines bash).
- `INTEROP.md` — armory-as-writer side of Agent Status Providers.
- `templates/**` — paste blocks for consumer `CLAUDE.md` / task briefs.
- `package.json` — npm package bins and published `files` list.

## Invariants

Prefer empty until human verification. Load-bearing product rule (not yet `enforcedBy`-linked): non-TTY launch path must remain byte-compatible.

## Lineage

Inferred from README, AGENTS.md, INTEROP.md, and `bin/llm` on 2026-07-21 atlas-seed pass.
