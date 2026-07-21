---
type: zone
summary: "Optional Claude Code skill skills/fusion-advisor: two-model advisor fusion (Opus + isolated Grok peer). Verify-not-vote reconcile; cost-gated high-leverage decisions only; execution always delegated to armory launcher."
tags: [skill, fusion, advisor, multi-model]
status: seeded
created: 2026-07-21
updated: 2026-07-21
verifiedAt: unverified
owns:
  routes: []
  testids: []
  globs:
    - "skills/fusion-advisor/**"
  tools: []
depends:
  - "[[launcher]]"
invariants: []
skills: []
related:
  - "[[loadouts]]"
sources: []
---

## What this is

A **reasoning-layer** skill, not an executor. At high-leverage forks the Fable/Opus advisor consults Grok as a context-isolated peer (`grok -p` REASON ONLY, no executor `--rules`), reconciles by verifying claims against reality, then hands implementation to `armory grok-high` (or other loadouts).

## Protocol modes

- **Default** — parallel-independent positions → reconcile disagreements
- **critique** — asymmetric peer attack on one drafted artifact
- **council** — rare third voice; highest stakes only

## Guardrails (research-backed)

Echo-chamber (no N-round debate), self-preference (aggregator verifies), capability floor (frontier peers only), complementarity focus on disagreement, cost gate (2–10× tokens), transport distinction (`grok -p` consult vs `armory` execute).

## Anchors

- `skills/fusion-advisor/SKILL.md` — sole tracked skill content (install via symlink into `~/.claude/skills/`)

## Lineage

Inferred from skill frontmatter/body and README Skills section on 2026-07-21 atlas-seed pass.
