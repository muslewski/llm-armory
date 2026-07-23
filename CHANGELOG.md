# Changelog

All notable changes to llm-armory are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]


## [0.1.1] — 2026-07-23

### Added

- **Public product documentation** under `docs/` (docs-kit frontmatter, sidebar `_meta.json`, `docs:check` / `docs:health`)
- **`docs/works-with.md`** — fleet sibling map with honest interop edges
- **Contextual fleet mentions** in feature docs where integrations are real
- **Recollection soft-nudge** for docs health (memory-atlas `atlas-recollection` + docs-kit)

See [`docs/index.md`](docs/index.md) for the documentation hub.

### Added

- **`fleet` / `fleet-status` / `fleet-report` verbs** — first-class multi-child
  launch for advisor fleets (replacing hand-rolled bash that nohup'd armory
  per child). Manifest lines are `<name>|<prompt-file>`; each child gets
  `<repo>/.claude/worktrees/<name>`, seed copies, and `.child-{out.log,pid,exit}`
  bookkeeping. `--max-parallel` (default 10) + `--stagger` (default 3s) gate
  launches without pipeline-subshell `wait` bugs; existing worktrees are
  refused loudly. `fleet-status` is a read-only dashboard (running / exit /
  stalled); `fleet-report` parses the last `RESULT:` line and exits 1 if any
  child is bad. Shared worktree creation via `materialize_repo_worktree`
  (also used by `-w`). Test-only override: `LLM_FLEET_CHILD_CMD`.

### Fixed

- **`-w`/`--worktree` now actually isolates grok children** — the grok CLI
  silently ignores `-w`/`--worktree` in headless `-p` mode (verified 2026-07-16,
  grok 0.2.101), and grok-created worktrees live under `~/.grok/worktrees`
  rather than the repo-local convention. Every child launched with `-w` was in
  fact running on the repo's main checkout (2026-07-16 research fleet: all 75
  children). `bin/llm` now materializes `<repo>/.claude/worktrees/<name>`
  itself (branch `<name>`, optional `--worktree-ref <ref>` base), strips the
  worktree flags, and launches the child with `--cwd <worktree>`. Creation is
  concurrency-safe (retry with jitter on git lock races), idempotent (an
  existing valid worktree is reused), and failures are loud (`exit 1`) —
  never a silent fallback to the main checkout. Warns when
  `.claude/worktrees` is not gitignored. Repo base = `--cwd` if given,
  else `$PWD`; caller `--cwd` is replaced by the worktree path.

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
