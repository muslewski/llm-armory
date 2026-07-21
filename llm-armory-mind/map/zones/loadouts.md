---
type: zone
summary: "Named executor loadouts under presets/*.env — grok-high (primary Grok 4.5 @ effort high), quality (native Fable), free/burn/glm/balanced lanes, shared executor-append contract, provider *.env.example credential templates."
tags: [presets, loadouts, grok, providers]
status: seeded
created: 2026-07-21
updated: 2026-07-21
verifiedAt: unverified
owns:
  routes: []
  testids: []
  globs:
    - "presets/**"
  tools: []
depends: []
invariants: []
skills: []
related:
  - "[[launcher]]"
  - "[[executor-hooks]]"
  - "[[freellmapi-runbook]]"
sources: []
---

## What this is

The **arsenal**: one `.env` file per named loadout. The launcher sources `$ARMORY_HOME/presets/<name>.env` (override root via `LLM_ARMORY_HOME`). Each loadout sets identity vars (`LLM_PRESET`, model pins, optional `LLM_GROK` / `GROK_MODEL` / `GROK_EFFORT`) and may source a gitignored `providers/<provider>.env` for keys.

## Primary lanes

| Loadout | Backend | Role |
|---------|---------|------|
| `grok-high` | `grok` CLI, model `grok-4.5`, effort `high` | Primary executor; arm Fable advisor sessions |
| `grok-medium` | same CLI, effort `medium` | Routine / low-risk work |
| `grok-xhigh` | alias of grok-high | Deprecated name — Grok 4.5 has no xhigh |
| `quality` | native Max / Fable | Pure advisor (unarmed) |
| `free` | freellmapi self-host | $0 pool; models pinned not `auto` |
| `burn` / `glm` / `balanced` | Anthropic API / z.ai / DeepSeek | Secondary paid lanes |

## Executor contract text

`presets/executor-append.txt` is the shared discipline blob (commit-per-task, `PROGRESS.md`, single `RESULT:` line). Grok lanes inject it via `--rules`; Claude-compat lanes via system append / hooks.

## Provider credentials

Tracked files are `presets/providers/*.env.example` only. Real keys live in untracked `*.env` next to them. Missing provider file + `LLM_REQUIRES_CREDENTIAL` → launcher refuses (no silent Max fallback).

## Anchors

Directory `presets/**` is the full zone boundary — loadout env files, executor-append, and provider examples.

## Lineage

Inferred from README loadout table and preset file headers on 2026-07-21 atlas-seed pass.
