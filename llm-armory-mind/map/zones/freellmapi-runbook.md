---
type: zone
summary: "Self-host runbook for freellmapi (free loadout backend): Docker Compose on host port 8791, pinned models (not auto), CHAT_TIMEOUT_MS local patch notes. Upstream clone under freellmapi/src is gitignored — only NOTES.md is tracked."
tags: [freellmapi, free-tier, self-host, docker]
status: seeded
created: 2026-07-21
updated: 2026-07-21
verifiedAt: unverified
owns:
  routes: []
  testids: []
  globs:
    - "freellmapi/**"
  tools: []
depends: []
invariants: []
skills: []
related:
  - "[[loadouts]]"
  - "[[ui-surfaces]]"
sources: []
---

## What this is

Operational notes for running **[freellmapi](https://github.com/tashfeenahmed/freellmapi)** as the backend behind the `free` loadout. This repo is not affiliated with upstream; the clone lives at `freellmapi/src/` and is **gitignored**.

## Runtime shape

- Docker Compose image `ghcr.io/tashfeenahmed/freellmapi:latest`, volume `freellmapi-data`
- Host port **8791** (avoid 3000–3010 reserved for local web-dev)
- Claude wiring: `ANTHROPIC_BASE_URL=http://localhost:8791` + `ANTHROPIC_AUTH_TOKEN` (not `ANTHROPIC_API_KEY`)

## Model pin policy

`presets/free.env` pins models (e.g. kimi-k2.6 / glm-4.7). `auto` routed 59 models in one bake-off hour → incoherent multi-step sessions. Pins still fail over across providers hosting that model id.

## Local patch memory

Upstream `fetchWithTimeout` default 15s is too short for agentic prompts; NOTES documents raising to 90s via `CHAT_TIMEOUT_MS` and rebuild after pull.

## Anchors

Git tracks only `freellmapi/NOTES.md` under this glob. Everything under `freellmapi/src/` is local operational state, not Atlas ownership of upstream code.

## Lineage

Inferred from `freellmapi/NOTES.md` and README credits on 2026-07-21 atlas-seed pass.
