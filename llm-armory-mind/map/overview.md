# llm-armory — overview

**llm-armory** is a standalone CLI arsenal for hybrid **advisor + executor** agent work: Fable/Claude Code stays the judgment layer; you explicitly **arm** implementation children by picking a named **loadout** (`armory grok-high`, `quality`, `free`, …). The launcher (`bin/llm`) resolves presets, enforces auth/preflight, optionally injects executor hooks, stamps Agent Status records for sibling tools, and `exec`s `grok` or `claude` — with a hard rule that the non-TTY launch path stays production-compatible.

Optional extras: **fusion-advisor** skill (two-frontier-model verify-not-vote decisions), **fleet** parallel worktrees, **freellmapi** self-host notes for the free lane, green-ui chrome when present.

## Seeded zones (2026-07-21)

| Slug | Purpose |
|------|---------|
| [[launcher]] | `bin/llm` CLI: arm, fleet, doctor, dry-run, agent-status, exec |
| [[loadouts]] | `presets/*` named lanes + executor-append + provider examples |
| [[executor-hooks]] | post-edit-check + stop-gate + executor-settings.json |
| [[ui-surfaces]] | `lib/ui.sh`, statusline, pool-report |
| [[fusion-advisor]] | two-model advisor skill |
| [[freellmapi-runbook]] | free-tier aggregator self-host NOTES |
| [[tests]] | bash harness for launcher / fleet / UI |

All cards are `status: seeded` / `verifiedAt: unverified` until a human review + `atlas stamp`.

## Out of zone (this pass)

Tracked but not partitioned into their own cards: `docs/`, `demo/`, `bakeoff/`, `assets/`, community meta (`CONTRIBUTING.md`, issue templates). Claim them later if they become load-bearing product surfaces.
