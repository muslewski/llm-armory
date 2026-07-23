---
title: "Agent status at launch"
description: "What llm-armory stamps for status-herald and agentic-sage before exec."
section: recipes
order: 10
---

# Agent status at launch

Armory children should be **labelable** by co-installed tools without those tools scraping the process environment. Immediately before `exec` of `grok` or `claude`, the launcher writes schema-1 Agent Status artifacts (soft-fail: missing dir never blocks launch).

Full writer-side field table: [`INTEROP.md`](../../INTEROP.md). Normative schema and reader rules: [status-herald AGENT-STATUS-PROVIDERS](https://github.com/muslewski/status-herald/blob/main/docs/AGENT-STATUS-PROVIDERS.md).

## What gets written

| Artifact | Path (under `$AGENT_STATUS_DIR` or XDG/state fallback) |
|----------|--------------------------------------------------------|
| Session | `sessions/<source_cli>-pid<pid>.json` |
| Heartbeat | `providers/llm-armory.json` |

Session keys use the **pid-key fallback** (`grok-pid…` / `claude-pid…`) because no host session id exists pre-`exec`. After `exec`, launcher `$$` **is** the child pid. Records use a long `ttl_ms` (12h); **readers must pid-check** `written_by: "llm-armory"` records.

Useful optional fields stamped when known:

- `model` / `effort` / `preset` — from the loadout
- `worktree` — from `-w` / `--worktree`
- `parent_session` — from `SAGE_PARENT` (or exported from `CLAUDE_SESSION_ID` / `GROK_SESSION_ID`)

## With agentic-sage (judge sessions)

SAGE is a **read-only fleet judge**. It does not spawn armory children. When you arm from an advisor that already has a session id (or set `SAGE_PARENT`), nested provenance lands on the stamp so SAGE can relate child → parent on the board / war view when hooks are on.

```bash
# From a judged advisor session, or with provenance set:
export SAGE_PARENT="$CLAUDE_SESSION_ID"   # if not already exported by armory
armory grok-high -p "implement the fix" -w fix-auth
# SAGE still only judges — it does not orchestrate the child
```

Without SAGE installed, the stamp still writes; nothing breaks.

## With status-herald (curtain model line)

Herald can render `model@effort` (and preset) for armory children when curtain model lines are enabled, reading the launch session stamp. Armory does **not** refresh after launch — if live model truth changes, that is **token-oracle**’s job when present.

## Disable without uninstalling

```bash
export AGENT_STATUS_DIR=/dev/null
armory grok-high -p "still launches"
```

## See also

- [Works with](../works-with.md) — full fleet honesty map
- [`AGENTS.md`](../../AGENTS.md) — env fallback surface for detectors
- [`INTEROP.md`](../../INTEROP.md) — complete field table
