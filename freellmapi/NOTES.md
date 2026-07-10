# freellmapi self-host runbook

Self-hosted free-tier aggregator (github.com/tashfeenahmed/freellmapi) backing the `free` preset.
Everything under `freellmapi/src/` is the upstream clone and is gitignored.

## Layout

- Clone: `freellmapi/src/` (`git clone --depth 1 https://github.com/tashfeenahmed/freellmapi src`)
- Runtime: Docker Compose, image `ghcr.io/tashfeenahmed/freellmapi:latest`, named volume `freellmapi-data`
- Config: `src/.env` (gitignored) — `ENCRYPTION_KEY` (openssl rand -hex 32) + `PORT=8791`

## Ports

- Host port **8791** (stable, rarely-used). 3000-3010 are reserved for local web-dev — never use them.
- Container listens on 3001 internally; compose maps `${PORT:-3001}:3001`, so `PORT=8791` in `src/.env` publishes 8791.

## Start / stop

```bash
sudo systemctl start docker        # daemon is socket-activated but usually inactive
cd ~/Repositories/llm-armory/freellmapi/src
HOST_BIND=0.0.0.0 docker compose up -d   # 0.0.0.0 = reachable from LAN/tailnet
docker compose down                       # stop
docker inspect -f '{{.State.Health.Status}}' $(docker compose ps -q)  # expect: healthy
```

## Access

- This box (Claude Code / `llm free`): `http://localhost:8791`
- Another device on your LAN/VPN: `http://<host>:8791`
- Dashboard: email+password. Proxy: unified `freellmapi-…` key from the Keys page.

## Claude Code wiring (the `free` preset)

- `presets/providers/freellmapi.env` (gitignored): `ANTHROPIC_BASE_URL=http://localhost:8791` + `ANTHROPIC_AUTH_TOKEN=<unified key>`
- Must be `ANTHROPIC_AUTH_TOKEN`, NOT `ANTHROPIC_API_KEY` — Claude Code treats a set API key as a conflicting first-party credential.
- freellmapi speaks native Anthropic `/v1/messages`. Models are PINNED in `presets/free.env`
  (kimi-k2.6 / glm-4.7), not `auto`: the 2026-07-06 bake-off showed `auto` routes per-request
  by availability (59 distinct models in one hour → incoherent multi-step coding sessions).
  A pinned model id still fails over across the providers hosting it. `deepseek-v4-flash-free`
  leaks raw chain-of-thought into message text — keep it unpinned.
- Postmortem/attribution: `bin/llm-pool-report [hours]` queries the router DB
  (`requests` table) for which provider+model actually served and what errored.

## Local patch (reapply after `git pull` in src/)

`server/src/providers/base.ts` — `fetchWithTimeout` default timeout raised from 15s to
90s and made configurable via `CHAT_TIMEOUT_MS` (compose `env_file: .env` passes it in).
Why: 15s is a time-to-first-byte deadline; agentic coding prompts (50-150k tokens) take
free tiers >15s to ingest, so real work requests aborted while tiny probes passed —
34 aborts in the 2026-07-06 bake-off window. Rebuild to apply:

```bash
cd ~/Repositories/llm-armory/freellmapi/src
docker compose build && HOST_BIND=0.0.0.0 docker compose up -d
```

## Provider pool (keyed 2026-07-05)

Google AI Studio, Groq, Cerebras, Mistral, OpenRouter, Cohere, Cloudflare Workers AI,
Zhipu AI (Z.ai), HuggingFace Router, OpenCode Zen — all healthy. GitHub Models and
NVIDIA NIM optionally added later (both ToS-scoped to experimentation/evaluation only;
NVIDIA also capped at 40 RPM).

ToS note: free tiers are for personal experimentation/prototyping — not a production
backend. Shipped-code execution moves to a paid preset (`balanced`).

## Verified

- `llm --dry-run free` — banner `▶ executor: auto @ http://localhost:8791 (preset: free)`, token masked
- `llm free -p "Reply with exactly: EXECUTOR-OK free-tier"` — returned `EXECUTOR-OK free-tier` (2026-07-06)
- Post-hardening smoke (2026-07-06): `llm free -p` child on pinned kimi-k2.6 with executor
  hooks — preflight ✓, created + committed file, wrote PROGRESS.md, ended with
  `RESULT: ok — commits: 1 — …`; stop gate and post-edit check exercised in tests (34/34).
