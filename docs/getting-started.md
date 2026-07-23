---
title: "Getting started"
description: "Install llm-armory, list loadouts, run doctor, and arm a first Grok executor."
section: guide
order: 10
---

# Getting started

Choose the right executor for the job. Four steps, then you can arm a session.

## 1. Install

```bash
npm install -g llm-armory    # or: npx llm-armory …
# bins: armory | llm-armory | llm
armory --list
armory doctor
```

Requires **Node ≥ 18** (Unix; Windows is not supported). From a git checkout (dev):

```bash
mkdir -p ~/.local/bin
ln -sfn "$PWD/bin/llm" ~/.local/bin/armory
export PATH="$HOME/.local/bin:$PATH"
armory --list
```

Loadouts ship with the package (`presets/`). Override with `LLM_ARMORY_HOME` if you keep a custom arsenal.

## 2. List and dry-run

```bash
armory --list                     # available loadouts
armory --dry-run grok-high        # mission card without exec
```

Primary loadout today: **`grok-high`** — Grok 4.5 at effort **high** (Grok 4.5: high|medium|low only; `grok-xhigh` is a deprecated alias of the same lane).

## 3. Arm a session

Advisor (native Max/Fable) stays unarmed for judgment work:

```bash
armory quality                    # pure advisor / judgment session
```

Heavy lifting — explicit Grok executor (optional worktree + prompt):

```bash
armory grok-high -p "task brief" -w my-exec
```

Parallel fleet from a manifest:

```bash
armory fleet grok-high --manifest fleet.txt
armory fleet-status
armory fleet-report               # exit 1 if any child RESULT is bad
```

Each child lands in `<repo>/.claude/worktrees/<name>` (same layout as `-w`).

## 4. Doctor

```bash
armory doctor
```

Fix anything red (bins on PATH, presets, optional status dir). Green doctor means the arsenal is coherent enough to launch.

## Statusline (optional)

Show which loadout is currently armed in Claude Code:

```json
"statusLine": {
  "type": "command",
  "command": "~/Repositories/llm-armory/bin/llm-statusline"
}
```

(Adjust the path to your install.)

## Fleet neighbors (optional)

When co-installed, armory **writes** Agent Status schema-1 launch records so **status-herald** can label curtains and **agentic-sage** can keep parent provenance (`SAGE_PARENT` / `parent_session`). Nothing is required; missing siblings never break a launch.

Details: [Works with](./works-with.md) · [Agent status recipe](./recipes/agent-status.md) · [`INTEROP.md`](../INTEROP.md)

## Agent path

Launcher notes, env fallback surface, and status conventions for agents:

→ **[`AGENTS.md`](../AGENTS.md)**

## Next

- [Works with](./works-with.md) — honest fleet map
- [Agent status recipe](./recipes/agent-status.md) — what gets stamped at launch
- [README](../README.md) — loadout table, fleet flags, executor contract
