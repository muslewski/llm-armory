# Interop — Agent Status Providers (llm-armory)

llm-armory is a **writer** in the Agent Status Providers convention (schema 1).
It stamps launch labels so co-installed siblings can label armory children
without parsing the process environment.

Normative schema (fields, lease rules, reader precedence):
[status-herald `docs/AGENT-STATUS-PROVIDERS.md`](https://github.com/muslewski/status-herald/blob/main/docs/AGENT-STATUS-PROVIDERS.md).

This file documents **only armory’s side**: what `bin/llm` writes, when, and
the env fallback surface. Schema details live in the herald doc — not here.

---

## When records are written

Immediately before `exec` of the child CLI (`grok` or `claude`), the launcher
calls `write_agent_status_record`. Every path soft-fails: missing/unwritable
status dir never blocks or delays a launch.

| Artifact | Path |
|----------|------|
| Session | `<dir>/sessions/<source_cli>-pid<pid>.json` |
| Heartbeat | `<dir>/providers/llm-armory.json` |

`<dir>` resolution (first match wins), matching the convention:

1. `$AGENT_STATUS_DIR` if set
2. `$XDG_RUNTIME_DIR/agent-status/`
3. `~/.local/state/agent-status/`

### Session key (pid-key fallback)

No host session id exists before `exec`, so keys are always
`<source_cli>-pid$$` (`grok-pid…` or `claude-pid…`). Because `exec` replaces
the launcher process, `$$` **is** the child pid.

### Session record fields armory writes

Built in `bin/llm` → `write_agent_status_record`. Empty optionals are **omitted**
(no nulls).

| Field | Source |
|-------|--------|
| `schema` | always `1` |
| `source_cli` | `"grok"` or `"claude"` |
| `pid` | launcher `$$` (becomes child pid after `exec`) |
| `cwd` | `pwd -P` at stamp time |
| `model` | Grok: `GROK_MODEL`; Claude: `ANTHROPIC_MODEL` (omit if unset) |
| `effort` | Grok: `GROK_EFFORT`; Claude: `CLAUDE_CODE_EFFORT_LEVEL` (omit if unset) |
| `preset` | `LLM_PRESET` (omit if unset) |
| `worktree` | `-w` / `--worktree` / `--worktree=` from user args (omit if absent) |
| `parent_session` | `SAGE_PARENT` (omit if unset) |
| `written_by` | always `"llm-armory"` |
| `started_at` / `updated_at` | unix ms at write |
| `ttl_ms` | `43200000` (12 hours) |

**Long TTL + pid-check:** records intentionally outlive a short lease. Readers
**must** treat `written_by: "llm-armory"` records as live only while `pid` is
still alive (`kill(pid, 0)`; EPERM counts alive). That is how “expires after
child exit” works without a refresher process. See the normative reader rules.

Atomic writes: `mktemp` in the destination directory + `mv -f`.

### Provider heartbeat

Written alongside each session stamp:

| Field | Value |
|-------|--------|
| `schema` | `1` |
| `tool` | `"llm-armory"` |
| `pid` | launcher `$$` |
| `ts` | unix ms at write |
| `ttl_ms` | `43200000` |
| `capabilities` | `["launch"]` |

---

## Env fallback (zero-install detection)

When no session record is available, detectors may read the child process
environment. Armory loadouts / the launcher set:

| Variable | Who sets it | What a detector may infer |
|----------|-------------|---------------------------|
| `LLM_PRESET` | loadout `.env` via launcher | resolved loadout name (e.g. `grok-high`) |
| `LLM_GROK` | grok loadouts (`=1`) | this process is a Grok-lane armory child |
| `GROK_MODEL` | grok loadouts | pinned Grok model (e.g. `grok-4.5`) |
| `GROK_EFFORT` | grok loadouts | Grok effort (`high` \| `medium` \| `low`) |
| `LLM_ARMORY_HOME` | launcher (or caller) | armory install root / presets home |

### Fleet provenance

If `SAGE_PARENT` is unset at launch, the launcher exports it from
`CLAUDE_SESSION_ID` or `GROK_SESSION_ID` when present (nested fleet
classification for agentic-sage). That value is also stamped as
`parent_session` on the session record when non-empty.

---

## Kill switch

Set `AGENT_STATUS_DIR=/dev/null` (or any unwritable path) to disable writes —
soft-fail swallows the failure and the child still launches normally.

---

## What armory does *not* do

- Does **not** refresh records after launch (stamp once, then `exec`).
- Does **not** read peer providers or depend on status-herald, token-oracle, or
  agentic-sage being installed.
- Does **not** own live model truth after launch — token-oracle refreshes that
  when present (see sibling INTEROP / the convention doc).
