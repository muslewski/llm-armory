---
name: fusion-advisor
description: Use when you want two different frontier models fused into one advisor brain for a high-leverage decision — "fuse", "fusion advisor", "get a second/peer model on this", "have Grok weigh in", "advisor fusion", "am I sure — bring in another model". This session reasons, consults a second frontier model (Grok) as a context-isolated peer, reconciles by verifying (not voting), then delegates execution via the `armory` launcher. NOT for routine steps (cost gate), and NOT for execution dispatch (that is the `armory` launcher).
---

# Fusion Advisor (two-model peer fusion at the reasoning layer)

## Overview

Turns your advisor session (Claude Code / Opus) into a **two-model advisor**. At a high-leverage
decision point, the advisor consults **Grok** (different vendor → different blind spots) as a
context-isolated peer, reconciles the two positions by **verifying claims — not voting**, and
emits the advisor artifact: a plan, a `/loop` decision, a review. Execution then flows down to
grok/sonnet executor children via the `armory` launcher (`bin/llm`). **Fusion decides; armory executes.**

Naive "two models beat one" is false (see Guardrails). Fusion pays off only on hard judgment,
and only with structure. This skill IS that structure.

Advisor half stays here (frame, reconcile, verify, decide). Peer half is one isolated Grok
consult per invocation. Never a debate club.

**Requires:** the `grok` CLI (Grok Build) and this repo's `armory` / `bin/llm` launcher. The
advisor is Claude Code (Opus); either peer can be swapped for another frontier CLI.

## When to use / when NOT (cost gate)

**Use at high-leverage points only:** design forks, plan approval, a genuine "am I sure?"
moment, `/loop` course-corrections, risky diffs (auth, billing, migrations, concurrency,
cross-zone). This is the same bar you would apply to an adversarial review.

**Do NOT use for:** routine or mechanical steps; execution dispatch (that is the `armory`
launcher); or as a second code executor. Fusion costs 2–10× tokens and over-fusing
invites the echo chamber (see Guardrails). **Manual invoke only** — this skill never
self-triggers.

## Default protocol — parallel-independent → reconcile

1. **Frame.** Write a crisp brief: the decision/question + the minimal shared facts (paths,
   constraints). Same discipline as a good adversarial review. Keep your own leaning OUT of it —
   isolation is the objectivity device.
2. **Consult, isolated.** Run the Transport recipe below to send the brief to Grok in
   **advisor mode**. Grok reasons with no knowledge of your position. Long consult → launch
   with `run_in_background: true` and poll the output file.
3. **Reason in parallel.** Form your OWN independent position while Grok runs. Do not wait
   idle; do not peek at a partial Grok answer and anchor on it.
4. **Reconcile.** Compare the two positions:
   - **Agreements** → higher confidence, but NOT proof (two peers can share a blind spot).
   - **Disagreements** → THE SIGNAL. Resolve each explicitly by verifying against
     codebase/reality. Steelman Grok's dissent before you override it.
   - **Grok-only points** → candidate blind-spot catches; verify, then fold in.
5. **Emit + delegate.** Output the advisor artifact — decision + residual risks, a plan for
   executors, or the next `/loop` action. Then hand implementation to the `armory` launcher (`bin/llm`).

## Transport recipe

Advisor consult (verified flags):

```bash
grok -p "REASON ONLY — do not run commands, edit files, or execute anything; return your analysis as text. <brief + the question>" --effort xhigh --always-approve
# long consult → run in background, then poll the output file:
#   run_in_background: true, then Read the task output; heartbeat like armory monitoring.
```

- `--effort xhigh` (alias of `--reasoning-effort`) → maximum reasoning.
- `--always-approve` → headless, no tool-approval prompt hang.
- Web/X search is ON by default; add `--disable-web-search` only to force offline reasoning.
- **NEVER** attach the executor `--rules` contract here. `grok -p` (bare) = advisor consult.
  `armory grok-xhigh` (with the executor contract) = execution child. They are different jobs.
- ⚠️ **`--always-approve` runs headless in your CURRENT directory and lets Grok execute tools.**
  A pure advisor consult must open with "REASON ONLY — do not run commands or edit files" (as
  above), or be launched from a neutral/scratch cwd. An action-ambiguous brief (e.g. just
  "test") makes Grok run commands against your repo.

## critique mode (harden ONE artifact)

Asymmetric peer review for a single concrete artifact (a spec/plan) before it ships to
executors:

1. The advisor drafts the artifact.
2. `grok -p "REASON ONLY — do not run commands or edit files; return your critique as text. <draft>. Try to break this: where does it fail — gaps, races, wrong
   assumptions, missed cases? Assume it is broken until proven otherwise." --effort xhigh --always-approve`
3. Revise against Grok's attack (verify each claim first — reviewers are sometimes wrong).
4. Optional single Grok re-check.

1–2 bounded rounds, never more. This is adversarial review with a genuinely different second
model instead of same-model-two-prompts.

## council escalation (rare, highest-stakes only)

Advisor + Grok + ONE third independent voice, the advisor chairs and verifies. The third voice
is a second isolated Grok consult with a different framing, OR a model lane you have
**explicitly** named (do not silently pull in a skipped armory loadout). ~3–4× cost and more
reconciliation overhead — reserve for irreversible, high-blast-radius calls. Not a default.

## Guardrails

Each is a research-backed failure mode of naive multi-model fusion. Non-negotiable.

- **Echo-chamber guard** — no naive N-round debate. Independent-then-reconcile, capped rounds.
  Similar-capability models converge to a shared misconception; more rounds often make it worse.
- **Self-preference guard** — the aggregator (you) VERIFIES claims against reality and
  steelmans dissent. Agreement between the two models is NOT evidence of correctness, and a
  model favors its own output — so never "let one model pick the winner."
- **Capability floor** — both peers must be frontier (Opus + Grok xhigh). A weak model is an
  *executor*, never an advisor peer; a weak voice drags the group below solo performance.
- **Complementarity focus** — spend the reconcile budget where the two DISAGREE. That is where
  a different vendor's blind spots surface. Redundant agreement buys little.
- **Cost gate** — fuse only at high-leverage points (see When to use). Cost is 2–10×.
- **Transport distinction** — `grok -p` = advisor consult; `armory grok-xhigh` = execution
  child. Never cross them.

## Reconcile discipline

- Verify each claim (yours and Grok's) against codebase/reality before accepting it.
- Steelman Grok's dissent; state why you override it, with reasoning — no reflexive "agreed."
- Treat disagreement as signal, not noise: it marks where the real uncertainty lives.
- If Grok's response is low-quality or off-topic, DISCARD it and proceed solo, noting so — do
  NOT average a bad response into the decision (quality beats diversity).

## Integration

- **The `armory` launcher (`bin/llm` / `armory`)** — the execution layer BELOW this skill.
  Fusion produces the plan/decision; hand ALL implementation dispatch to armory executor
  children (`armory grok-xhigh …`). Fusion never writes production code itself.
- **`/loop` (ralph-loop plugin)** — inside an autonomous program of work, invoke fusion
  manually at per-iteration course-corrections ("what next / is this right / stop?").
- **Optional companion patterns** (swap in your own equivalents):
  - An *audit → self-contained-plans* pass — a read-only "senior advisor" that produces plans
    for other agents to execute. Fusion is the reasoning upgrade for that role.
  - A *same-model adversarial review* (architect vs skeptic, one model, two prompts). This
    skill is the structural descendant — use `critique` mode when you want a genuinely
    *different* model instead.

## Degradation

- **Grok unavailable / errors / times out** → fall back to solo advisor and STATE
  "fusion unavailable — solo advisory." Never silently pretend a consult happened.
- **Unresolved disagreement** (verification cannot settle it) → surface to the human as a
  stop-and-ask. Survived disagreement is exactly the signal worth escalating.
- **Long consult** → background launch + heartbeat poll (mirror armory monitoring).
- **Detecting a failed consult** → check for nonzero exit, error text, empty/off-topic output,
  or timeout. Do NOT rely on Grok rejecting a bad flag — it tolerates an invalid `--effort` and
  runs anyway. If the output is not a usable position, treat the consult as unavailable → solo.

## Common mistakes

| Mistake | Correct |
|---|---|
| Fusing on a routine step | Cost gate: fuse only at high-leverage decision points |
| Leaking your leaning into the Grok brief | Isolated brief — isolation is the objectivity device |
| Treating agreement as proof | Agreement ≠ correctness; mine the disagreement |
| Letting one model pick the "winner" | Aggregator verifies vs reality; steelman dissent |
| N-round debate to force consensus | Independent-then-reconcile, capped rounds |
| Attaching executor `--rules` to an advisor consult | Bare `grok -p` for advice; `armory grok-xhigh` for execution |
| Fusion writing the production code | Delegate implementation to `armory` executor children |
| Averaging in a low-quality Grok answer | Discard it, proceed solo, note it |
| Silent solo fallback when Grok fails | State "fusion unavailable — solo advisory" |
