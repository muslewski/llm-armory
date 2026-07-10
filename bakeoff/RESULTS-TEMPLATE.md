# Bake-off verdict: <brief name> — <date>

| Preset | Model | Wall time | Cost (provider dashboard) | Tests pass? | Verify verdict (Max review) | Notes |
|---|---|---|---|---|---|---|
| balanced | deepseek-v4-pro | | | | | |
| glm | glm-5.2 | | | | | |
| free | (auto) | | | | | |
| quality | max sonnet/opus | | | | | |

## Verification method
Same Max session reviewed each worktree diff against the brief's done
criteria + ran the test suite. Adversarial pass for sensitive surfaces.

## Decision
- Fleet default stays/changes to: <preset>
- Demotions/promotions: <model → tier, evidence>
