---
title: "Documentation"
description: "llm-armory product docs — loadouts, install, fleet launch, and fleet interop."
section: home
order: 0
---

# llm-armory documentation

**llm-armory** holds named **loadouts** (executor lanes) you pull for different kinds of work. Fable (Claude Code) stays the advisor; you **arm** a session by choosing a loadout — primarily **`grok-high`** (Grok 4.5 at effort high).

Site: [armory.muslewski.com](https://armory.muslewski.com) · npm: [`llm-armory`](https://www.npmjs.com/package/llm-armory)

## Start here

| Path | For |
|------|-----|
| [Getting started](./getting-started.md) | Install → `armory --list` → doctor → first armed launch |
| [Works with](./works-with.md) | Fleet siblings (sage, herald, oracle, atlas, ferry) |
| [Recipe: agent status](./recipes/agent-status.md) | Launch stamps for co-installed judges / curtains |

## Doctrine (short)

1. **Standalone-first** — loadouts launch the same way with or without siblings.
2. **Explicit arm** — the advisor chooses a loadout; pure Grok sessions use native `spawn_subagent`.
3. **Stamp once, then exec** — Agent Status records are written immediately before `exec`; soft-fail never blocks launch.
4. **Loose coupling** — readers (herald, sage, oracle) own their own truth after launch.

## Where other knowledge lives

| Kind | Location |
|------|----------|
| **Public product docs** | `docs/` (this tree) |
| **Architecture mind (Atlas)** | [`llm-armory-mind/`](../llm-armory-mind/) — zones, decisions; specs/plans pipeline |
| **Agent install / status runbook** | [`AGENTS.md`](../AGENTS.md) |
| **Agent Status writer side** | [`INTEROP.md`](../INTEROP.md) |
| **Human README** | [`README.md`](../README.md) |
| **Changelog** | [`CHANGELOG.md`](../CHANGELOG.md) |

Agent design notes under `docs/superpowers/` are historical; new specs/plans go to the mind vault (`llm-armory-mind/specs/`, `llm-armory-mind/plans/`).
