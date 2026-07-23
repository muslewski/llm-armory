---
title: "Works with"
description: "How llm-armory fits the muslewski fleet — real interop, not a laundry list."
section: recipes
order: 5
---

# Works with

The armory is **standalone-first**: loadouts launch the same way with or without sibling tools. When co-installed, optional extras appear via the [Agent Status Providers](https://github.com/muslewski/status-herald/blob/main/docs/AGENT-STATUS-PROVIDERS.md) convention (armory **writes** launch records; details in [`INTEROP.md`](../INTEROP.md)). This page is the short honesty map.

| Package | Relationship to llm-armory | Links |
|---------|----------------------------|--------|
| **agentic-sage** | Fleet **judge** for sessions armory spawns. At launch, if `SAGE_PARENT` is unset, the launcher exports it from `CLAUDE_SESSION_ID` / `GROK_SESSION_ID` when present and stamps `parent_session` on the session record — nested fleet provenance for SAGE, not orchestration. SAGE does not arm children; armory does not run the board. | [sage.muslewski.com](https://sage.muslewski.com) · [npm](https://www.npmjs.com/package/agentic-sage) |
| **status-herald** | Curtain / bars can show `model@effort` (and preset) for armory children from the long-TTL launch session stamp (`written_by: "llm-armory"`, pid-checked). Without herald, stamps still write; without armory, optional model lines stay empty. | [herald.muslewski.com](https://herald.muslewski.com) · [npm](https://www.npmjs.com/package/status-herald) |
| **token-oracle** | Owns **live** model / cap truth after launch. Armory only stamps what was known at `exec`; oracle refreshes forecasts and session truth when present. Desk neighbor — no mutual import. | [oracle.muslewski.com](https://oracle.muslewski.com) · [npm](https://www.npmjs.com/package/token-oracle) |
| **memory-atlas** | Code-verified architecture vaults. This repo’s understanding lives in `llm-armory-mind/` (Atlas); public guides live in `docs/`. Sessions armory spawns recollect into an Atlas **when the target repo has a vault**. Atlas does not invoke armory. | [atlas.muslewski.com](https://atlas.muslewski.com) · [npm](https://www.npmjs.com/package/memory-atlas) |
| **mossferry** | Remote tmux/mosh “ferry” to the host where your fleet (and armory) actually run. Armory launches on the **app host**; ferry is how a laptop reaches that host. No code bridge — adjacency of workflow only. | [mossferry.muslewski.com](https://mossferry.muslewski.com) · [npm](https://www.npmjs.com/package/mossferry) |

## Writer surface (shared edge)

Armory is a **writer** only in Agent Status schema 1:

- Session: `$AGENT_STATUS_DIR/sessions/<source_cli>-pid<pid>.json` (pid-key fallback; `$$` becomes the child after `exec`)
- Heartbeat: `$AGENT_STATUS_DIR/providers/llm-armory.json` (`capabilities: ["launch"]`)
- Soft-fail always; kill switch: `AGENT_STATUS_DIR=/dev/null`
- Normative reader rules live in status-herald’s convention doc — not forked here

Recipe: [Agent status at launch](./recipes/agent-status.md).

## Rules for authors

1. **Contextual first** — when documenting a feature that displays or depends on a sibling, say so on that page (one clear sentence + link).
2. **Update this table** when you add or remove a real edge.
3. **Do not invent** — if code does not wire it, do not claim it.

## See also

- [Getting started](./getting-started.md)
- [Agent status recipe](./recipes/agent-status.md)
- [`INTEROP.md`](../INTEROP.md) — fields armory writes
- [README — Works well with](../README.md#works-well-with)
