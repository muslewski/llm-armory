# llm-armory (formerly llm-lab): Named Executor Lanes for Advisor Sessions

**Date:** 2026-07-05
**Status:** Approved (design review complete)
**Owner:** kento

## Problem

A solo developer on Claude Code Max ($200/mo) runs a highly autonomous pipeline (brainstorm → spec → plan → subagent-driven development → verification → human merge gate) across many parallel worktree sessions. Even after ~80% token-per-hour optimization, parallel implementation work always exhausts Max usage limits. Implementation tokens are the binding constraint; judgment tokens (planning, verification) are not.

## Goal

Route each tier of work to an independently chosen provider, switchable by named preset, while keeping Claude Code as the only harness and staying inside Anthropic's terms of service.

Three tiers:

1. **Judgment** — brainstorming, specs, plans, verification, merge decisions. Needs frontier quality (Fable/Opus).
2. **Execution** — implementing plan tasks. Needs ≥ Opus 4.6 quality *after* verification compensates; volume and concurrency matter most.
3. **Chores** — commit messages, summaries, doc generation, lint fixes. Quality floor is low.

Any tier must be assignable to any provider (including deliberately "wrong" combinations, e.g. GLM-5.2 for all three, or free models for all three).

## Constraints (researched 2026-07-03 → 2026-07-05)

- **ToS:** Since January 2026, Anthropic bans Max/Pro OAuth tokens in third-party harnesses (OpenCode lost Max login by legal request; Crush dropped Claude; Roo blocked; enforcement is real). The only sanctioned way to spend the Max plan is the real `claude` binary. Consequently: **Max traffic never goes through a router or proxy.** Cross-billing tier mixing happens at the orchestration level — a native Max session spawns cheap API-billed `claude -p` children.
- **Compatibility:** Every target provider speaks the Anthropic Messages API natively: DeepSeek (`https://api.deepseek.com/anthropic`), z.ai (`https://api.z.ai/api/anthropic`), OpenRouter (`/v1/messages`, including server-side `@preset/` slugs), freellmapi (self-hosted `/v1/messages` with explicit Claude Code support). So one harness + env vars covers everything; no protocol translation layer needed.
- **Model naming:** DeepSeek aliases `deepseek-chat` / `deepseek-reasoner` are retired 2026-07-24. Configs must use `deepseek-v4-pro` / `deepseek-v4-flash`.
- **Budget:** $400/mo hard roof; target ≈ $245–330 all-in.
- **Quality floor:** Execution output must land at ≥ Opus 4.6 quality *post-verification*. Verification is strong from day 1 (see below) precisely so the execution tier can be cheap.
- **Simplicity:** No new harness. The existing stack (superpowers skills, agentic-sage, caveman, advisor-plans, SDD) is Claude-Code-native and must keep working unchanged.

## Architecture

### Rejected alternatives

- **claude-code-router (Desktop):** API-only (no Max support ever), rewritten as a desktop app with SQLite config; its per-route rules are replicable with env files. Heavier, no benefit for this setup.
- **OpenCode as execution harness:** 182k stars, excellent per-agent model config — but it is a second harness (loses superpowers/sage/skills), and its Max login was removed at Anthropic's request anyway.
- **LiteLLM one-gateway (OAuth header-forward):** most unified on paper, but the `/v1/messages` translation layer documentedly breaks on Claude Code updates, it is a server to maintain, and it is the grayest ToS variant.

### Wheel-reinvention check (verified 2026-07-05)

No popular tool implements the Max-orchestrator + cheap-executor handoff:

- **ruflo, ex claude-flow (63k stars):** multi-provider layer is a separate API-key SDK doing request-level load-balancing; agents inside a Claude Code session stay on the session endpoint. Wrong abstraction.
- **claude-code-router (35.6k):** whole session through the gateway — forfeits Max OAuth.
- **pal-mcp-server, ex zen-mcp (11.6k):** closest prior art. Its `clink` tool spawns real file-editing CLI children (`claude --permission-mode acceptEdits`) and returns only final results. Repo stale ~7 months; we adopt the spawn pattern, not the dependency.
- **opencode (182k) / cc-switch (113k) / CCS:** whole-session switching only; no mid-flow tier handoff; opencode's Max login was removed.
- **Claude Code native:** per-subagent endpoint/credentials remains an open feature request (anthropics/claude-code#38698) with no maintainer response.

Spawning env-differentiated `claude -p` children from a subscription-authed orchestrator is the sanctioned, community-converged pattern (Agent SDK docs, DeepSeek's official Claude Code integration guide). llm-armory writes only the glue nobody ships (~100 lines) and reuses community pieces where they are strong: freellmapi aggregation, OpenRouter server-side presets, native Anthropic-compatible endpoints, the clink spawn pattern.

**Billing hedge:** Anthropic announced, then paused (2026-06-15), moving `claude -p`/Agent SDK usage off subscription limits onto separate credit. Executors here are API-billed regardless, but this reinforces the wrapper boundary: skills only ever call `llm <preset>`, so the executor CLI can be swapped (e.g. to opencode against the same cheap endpoints) without touching any skill.

### Chosen: env-file presets + single launcher + OpenRouter server-side knob

One harness (`claude`), N environment files. A preset is a small `.env` file that sets:

- `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` — which provider bills the session (unset = native Max OAuth)
- `ANTHROPIC_DEFAULT_OPUS_MODEL` / `ANTHROPIC_DEFAULT_SONNET_MODEL` / `ANTHROPIC_DEFAULT_HAIKU_MODEL` — the three model slots, which map onto the three tiers within a session (judgment/execution/chores ≈ opus/sonnet/haiku slots)
- `CLAUDE_CODE_SUBAGENT_MODEL` — model for spawned subagents
- `API_TIMEOUT_MS` — no infinite hangs

### Preset matrix (initial)

| Preset | Judgment | Execution | Chores | Billing |
|---|---|---|---|---|
| `quality` | Fable/Opus high (native Max) | Max Sonnet | Max Haiku | Max only |
| `balanced` *(default)* | Fable/Opus high (native Max) | DeepSeek V4-Pro (fleet) / V4-Flash (light tasks) | freellmapi auto | Max + ~$30–80 API |
| `free` | freellmapi auto (best available free model) | freellmapi auto / GLM-4.7-Flash (free API) | freellmapi auto | $0 (GLM-5.2 judgment via z.ai plan is a paid variant of this preset) |
| `burn` | Fable high | Opus API or GLM-5.2 | DeepSeek V4-Flash | Uncapped; for limit-reset days |

Presets are files; adding one is copying a file. Deliberately "wrong" assignments (GLM-5.2 everywhere, free everywhere) are supported by design.

### Components

```
~/Repositories/llm-armory/
├── presets/
│   ├── quality.env  balanced.env  free.env  burn.env
│   ├── providers/   deepseek.env  zai.env  openrouter.env  freellmapi.env
│   └── *.env.example        # committed; real keys gitignored
├── bin/
│   └── llm                  # launcher, ~100 lines bash
├── freellmapi/              # docker-compose self-host config
├── bakeoff/                 # week-1 harness + results
└── docs/superpowers/specs/  # this document, future specs
```

- **`bin/llm`** — `llm <preset> [claude args...]`. Sources the preset env, prints the executor banner, `exec`s `claude`. `llm quality` executes native claude with no env. `llm --list` shows presets with their tier→model resolution. On PATH via symlink to `~/.local/bin/llm` (user-global, per decision).
- **OpenRouter server-side presets** — `@preset/execution` and `@preset/chores` defined on openrouter.ai; `openrouter.env` points model slots at them. Tier models and fallback chains become editable in the OpenRouter web UI without touching local files. Used for experimentation and fallback chains; the fleet default stays DeepSeek-direct (no ~5% surcharge on the volume path).
- **freellmapi (self-hosted)** — Docker, 18 providers / ~1.7B free tokens/mo, native `/v1/messages`, internal auto-failover on rate limits. Backbone of the chores tier and the `free` preset. Never the execution tier in `balanced`.
- **syndcast integration** — one new "Execution" tier row in syndcast's CLAUDE.md agents-and-effort table; SDD spawns `llm balanced -p "<task brief>"` per task in its worktree. Orchestrator stays a native Max session.

### Executor identity observability

Requirement: it must be visible which model is doing the work, live and after the fact.

1. **Launcher banner** — `llm` prints `▶ executor: deepseek-v4-pro @ api.deepseek.com (preset: balanced)` before exec.
2. **Statusline segment** — reads the same env and shows e.g. `⚡ deepseek/v4-pro` or `⚡ freellm/glm-4.7-flash` in the running session; native Max shows the stock model name.
3. **Audit trail** — every SDD task report carries an `Executor:` header and every executor commit a trailer `Executed-By: <model> (<preset>)`. Enables post-hoc attribution ("which model wrote this?") and feeds the bake-off.

### Data flow (one pipeline)

1. Native Max session: brainstorm → spec → plan (advisor-plan contract, written for the weakest plausible executor: drift checks, STOP conditions, machine-checkable done criteria).
2. Per task: the SDD skill spawns `llm balanced -p "<task brief>" --permission-mode acceptEdits` (clink pattern) in the task's worktree — the provider switch is made by the skill, invisible to the user. Executor implements, commits with the `Executed-By:` trailer, writes its task report; only the final result returns to the orchestrator.
3. Native Max session verifies: plan-contract reconcile + full test run + adversarial review (mandatory for auth/billing/migrations).
4. Human merge gate (unchanged).

### Error handling

- **Free tier flaky/dead:** freellmapi fails over internally; if the whole free pool is down, presets fall back to DeepSeek V4-Flash ($0.14/M in, 2500 concurrency — cheap enough that fallback is painless).
- **Executor drift/garbage:** plan STOP conditions stop the run; verification rejects the diff; worktree is disposable; task re-runs (same or better model).
- **Hangs:** `API_TIMEOUT_MS` set in every preset.
- **Provider model renames:** presets pin exact model IDs; `llm --list` surfaces them for quick audit.

### Verification (strong from day 1)

Every cheap-executed task is Max-verified before merge: reconcile against the plan contract, tests must pass, adversarial review on sensitive surfaces. This is the mechanism that lets execution quality float below the frontier while merged quality stays at it. If a model consistently fails verification, it is demoted in the preset (evidence from the audit trail).

## Week 1 plan (sketch — full plan via writing-plans)

1. Scaffold llm-armory: presets, `bin/llm` (the armory launcher), gitignore, examples.
2. Bake-off: advisor-plan 032 executed by DeepSeek V4-Pro, V4-Flash, GLM-5.2, and Max Sonnet; all Max-verified; results + costs recorded in `bakeoff/`.
3. freellmapi up (Docker); chores slot switched to it.
4. OpenRouter `@preset/execution` + `@preset/chores` created; `openrouter.env` wired.
5. First fleet run: parallel-safe advisor-plans (031–038, 005, 008–010, 018–021) via `llm balanced`.

## Budget

$200 Max + $30–80 DeepSeek + $12.60–50 z.ai GLM (optional) + $0 free tier ≈ **$245–330/mo**; roof $400.

## Out of scope (phase 2+)

- agentic-sage adapter for syndcast + `sage guard` ON for the cheap tier
- "Fusion" verification (GLM-5.2 cross-review, Opus judges only contested findings)
- CCS/cc-switch adoption if multi-account management ever becomes needed
