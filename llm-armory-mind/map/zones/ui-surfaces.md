---
type: zone
summary: "Terminal chrome and auxiliary bins: lib/ui.sh (green-ui-kit source-or-fallback), llm-statusline (armed loadout model@effort for status bars), llm-pool-report (freellmapi router DB attribution)."
tags: [ui, statusline, green-ui, pool-report]
status: seeded
created: 2026-07-21
updated: 2026-07-21
verifiedAt: unverified
owns:
  routes: []
  testids: []
  globs:
    - "lib/ui.sh"
    - "bin/llm-statusline"
    - "bin/llm-pool-report"
  tools: []
depends: []
invariants: []
skills: []
related:
  - "[[launcher]]"
  - "[[loadouts]]"
  - "[[freellmapi-runbook]]"
sources: []
---

## What this is

Non-launch chrome and helper binaries. Kit law: colors/panels only when stderr is a TTY; plain fallbacks when `GREEN_UI` kit is absent so armory still works headless.

## green-ui integration

`lib/ui.sh` sources `${GREEN_UI:-$HOME/.local/lib/green-ui.sh}` when readable; otherwise defines no-op / plain-text `ok` / `warn` / `banner` / `checklist` / `panel` helpers. Sourced by `bin/llm` at startup for dry-run mission cards, arsenal rack, doctor checklists, arm banners.

## Statusline

`bin/llm-statusline` — fast command for Claude Code `statusLine` config. Must show **real** model@effort per lane (not a hardcoded `:grok-xhigh`); primary loadout marked ★; dim when unarmed.

## Pool report

`bin/llm-pool-report` queries the freellmapi router DB (`requests` table) for which provider+model actually served over a time window — postmortem tool for the free lane. Must degrade cleanly on missing data (dash, not `NaN` / empty table).

## Anchors

Three tracked paths only: `lib/ui.sh`, `bin/llm-statusline`, `bin/llm-pool-report`.

## Lineage

Inferred from UI design spec (`docs/superpowers/specs/2026-07-17-armory-ui-design.md`) and bin headers on 2026-07-21 atlas-seed pass.
