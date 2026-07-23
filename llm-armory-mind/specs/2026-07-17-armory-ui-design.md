# llm-armory UI upgrade — design spec

**Date:** 2026-07-17 · **Status:** approved · **Phase:** 1 of the fleet UI campaign
**Inputs (binding):** the llm-armory section of `~/.cache/armory-research/UPGRADE-BRIEF.md` (the five-row table IS the feature list), `~/.cache/armory-research/PLAYBOOK.md` (visual recipes), GREEN-UI-KIT at `~/Repositories/green-ui-kit` (`README.md` = consumer API).

## Problem
llm-armory is the fleet's launcher and has ZERO color — plus real bugs: `llm-statusline` hardcodes `:grok-xhigh` for every grok lane, `llm-pool-report` prints an empty console.table and `last NaNh`, `--list` misaligns the host column (24 vs 32 widths), dry-run dumps empty `KEY=` lines with mixed stdout/stderr streams.

## The one absolute constraint
**`armory <loadout> -p <prompt>` is production infrastructure** — this machine's agent fleets launch through it non-interactively (nohup, no TTY). Its contract MUST NOT change: same exec of the underlying CLI, same exit-code propagation, same prompt passing, no new required env, no TTY requirement, never blocks on input. All new chrome goes to stderr and silences itself when stderr is not a TTY (kit law). Breaking the launch path = failed task.

## Features (per the brief table)
1. **Dry-run mission card** — `--dry-run` renders a kit panel: loadout name, model @ effort (effort as small gauge), rules file size, exact would-exec command, warnings section. Fix the empty `KEY=` dump and route data to stdout, chrome to stderr (streams currently mixed).
2. **`llm-statusline` truth** — show the REAL model @ effort per lane (kill the hardcoded `:grok-xhigh`), `★` marks the primary lane, dim styling when unarmed. Keep it fast (<50ms) — it runs in status bars.
3. **Arsenal rack `--list` / `pick`** — aligned columns (fix 24-vs-32 bug), READY/SKIP/DEAD badge per loadout (binary present? key present?), `pick` uses fzf with the kit's `green_fzf_opts` theme + preview of the loadout definition; numbered fallback without fzf.
4. **Arm checklist on launch** — before exec: a compact kit checklist (resolve loadout → check binary → check auth/key → arm) then an armed mission banner; ALL on stderr, all silent when non-TTY (nohup logs stay clean — at most the existing `▶ executor:` line).
5. **`armory doctor` (new subcommand)** — whole-armory health: each loadout's binary on PATH, key/auth material present, rules files readable; kit checklist rendering; exit 0 healthy / 1 problems. `--fix` NOT in scope (defer).
6. **Bug: `llm-pool-report`** — no empty console.table, no `NaNh`; show a dash/`—` for missing data.

## Kit consumption pattern (first consumer — sets the fleet precedent)
Source `${GREEN_UI:-$HOME/.local/lib/green-ui.sh}` when readable; otherwise define minimal no-op fallbacks (ok/warn/die/banner/checklist/panel print plain text, colors empty) so armory works on machines without the kit. This guard block should match the kit README's vendoring instructions.

## Acceptance
- a1: `armory <loadout> -p x --dry-run </dev/null 2>/dev/null` — stdout contains the would-exec data, zero ANSI bytes, exit 0 (non-TTY chrome silence).
- a2: dry-run card via forced TTY mode shows loadout, model@effort, would-exec; no empty `KEY=` lines anywhere.
- a3: statusline for a grok lane configured at effort=high renders `high` (not `xhigh`); primary lane carries `★`.
- a4: `--list` columns align for the real loadout set (assert against column positions); badges READY/SKIP present.
- a5: doctor exits 0 when all loadouts healthy, 1 when a binary is missing (fixture PATH), output is a kit checklist.
- a6: pool-report with empty/missing data prints `—` (no `NaN`, no empty table).
- a7: launch-path compat — non-TTY launch of a stub loadout execs the stub with identical args/exit code as before the change (golden test).
- Existing repo tests (discover the harness) stay green; kit-absent fallback: suite passes with GREEN_UI pointed at /nonexistent.
