# Changelog

All notable changes to llm-armory are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- **Launch records + provider heartbeat** — immediately before `exec`, `bin/llm`
  writes Agent Status Provider schema-1 artifacts so co-installed tools
  (status-herald, token-oracle, agentic-sage) can label armory children without
  reading the process environment:
  - session: `<dir>/sessions/<source_cli>-pid<pid>.json` (pid-key fallback;
    long `ttl_ms` 12h; readers must pid-check `written_by: "llm-armory"`)
  - heartbeat: `<dir>/providers/llm-armory.json` with `capabilities: ["launch"]`
  - soft-fail / atomic writes; kill switch `AGENT_STATUS_DIR=/dev/null`
  - optional fields: `worktree` (`-w`), `parent_session` (`SAGE_PARENT`)
- **Docs:** [`INTEROP.md`](INTEROP.md) (writer contract), README “Works well with”,
  agent notes in `AGENTS.md`. Normative schema:
  [status-herald AGENT-STATUS-PROVIDERS](https://github.com/muslewski/status-herald/blob/main/docs/AGENT-STATUS-PROVIDERS.md).
