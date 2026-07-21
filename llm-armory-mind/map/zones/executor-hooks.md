---
type: zone
summary: "Claude Code executor guardrails: PostToolUse post-edit-check.mjs (transport garbage, parse fails, phantom imports) and Stop stop-gate.sh (block exit with dirty worktree). Wired via hooks/executor-settings.json when LLM_EXECUTOR_HOOKS=1."
tags: [hooks, guardrails, executor-contract]
status: seeded
created: 2026-07-21
updated: 2026-07-21
verifiedAt: unverified
owns:
  routes: []
  testids: []
  globs:
    - "hooks/**"
  tools: []
depends: []
invariants: []
skills: []
related:
  - "[[launcher]]"
  - "[[loadouts]]"
sources: []
---

## What this is

Machine-checkable discipline for **Claude-compat executor children** (especially the free pool). Born from the 2026-07-06 bake-off postmortem: weak models wrote deliberation into source, emitted tool-call markup as file content, and invented phantom imports.

## Post-edit check

`hooks/post-edit-check.mjs` (bun) runs on `Write|Edit|MultiEdit`. Detects:

1. Transport garbage (`<tool_call>`, `<function=` in file body)
2. Deliberation prose that fails TS/JS parse
3. Relative / `@/` imports that do not resolve or name missing exports

Exit 2 feeds stderr back as a blocking correction. Uncertain cases **fail open** (exit 0).

## Stop gate

`hooks/stop-gate.sh` on session Stop: if the worktree is dirty, returns a Claude Code block decision requiring commit-per-task cleanup or an honest `RESULT: failed` line.

## Settings wire-up

`hooks/executor-settings.json` is passed as Claude `--settings` when a loadout sets `LLM_EXECUTOR_HOOKS=1` (e.g. `free`). Paths resolve via `LLM_ARMORY_HOME` / `LLM_LAB_HOME`.

## Anchors

- `hooks/executor-settings.json` — hook registration surface
- `hooks/post-edit-check.mjs` — PostToolUse tripwire
- `hooks/stop-gate.sh` — Stop-time dirty-tree gate

## Lineage

Inferred from hook file headers and freellmapi bake-off notes on 2026-07-21 atlas-seed pass.
