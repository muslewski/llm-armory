---
type: zone
summary: "Bash test harness tests/run.sh plus suites for launcher (test_llm.sh), fleet (test_fleet.sh), UI phase-1 (test_ui_phase1.sh), and agent-status session fixture. npm test → bash tests/run.sh."
tags: [tests, harness, fleet, ui]
status: seeded
created: 2026-07-21
updated: 2026-07-21
verifiedAt: unverified
owns:
  routes: []
  testids: []
  globs:
    - "tests/**"
  tools: []
depends:
  - "[[launcher]]"
invariants: []
skills: []
related:
  - "[[ui-surfaces]]"
  - "[[executor-hooks]]"
sources: []
---

## What this is

Shell-level contract tests for the launcher and chrome — not a language unit-test tree. Entry: `tests/run.sh` (also `npm test` / `package.json` scripts.test).

## Suites

| File | Focus |
|------|--------|
| `test_llm.sh` | Core armory resolve / launch / dry-run / sanitize behavior |
| `test_fleet.sh` | Fleet manifest spawn, worktree layout, status/report gates |
| `test_ui_phase1.sh` | Dry-run card streams, statusline effort truth, list badges, doctor, pool-report degrade |
| `fixtures/agent_status/session-armory.json` | Sample Agent Status session stamp |

## Anchors

Entire `tests/**` tree is the zone — keep fixtures co-located with the suite that uses them.

## Lineage

Inferred from `package.json` scripts and `tests/` tree on 2026-07-21 atlas-seed pass.
