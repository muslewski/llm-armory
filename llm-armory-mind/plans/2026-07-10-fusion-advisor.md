# fusion-advisor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author a global skill, `~/.claude/skills/fusion-advisor/SKILL.md`, that turns an Opus 4.8 (Claude Code) session into a two-model advisor — it consults Grok as a context-isolated peer at high-leverage decision points, reconciles by verifying, then delegates execution via `using-llm-armory`.

**Architecture:** A single self-contained SKILL.md (no `references/`), styled after the existing `using-llm-armory` skill (terse tables, recipe blocks, Common-mistakes table). The skill is authored section-by-section; each section is verified by a presence-grep. One task runs a live `grok -p` consult to confirm the transport recipe and the degradation path behave as specified.

**Tech Stack:** Markdown skill file; `grok` CLI (Grok Build, SuperGrok Heavy) as advisor transport; `git` in two repos (`~/.claude` for the skill, `~/Repositories/llm-armory` for docs); `grep` for presence checks.

## Global Constraints

- **Deliverable path:** `~/.claude/skills/fusion-advisor/SKILL.md` — a real directory (like `eve`, `handoff`, `using-llm-armory`), NOT a symlink.
- **Skill commits repo:** `~/.claude` IS a git repo. All SKILL.md commits use `git -C ~/.claude` on branch `skill/fusion-advisor`. Do NOT commit the skill into the `llm-armory` repo.
- **Docs repo:** the spec (`docs/superpowers/specs/2026-07-10-fusion-advisor-design.md`) and this plan live in `~/Repositories/llm-armory` on branch `docs/fusion-advisor-design`. Already committed; no further action needed on the spec.
- **Transport recipe (verified 2026-07-10):** `grok -p "<prompt>" --effort xhigh --always-approve`. `--effort` is an alias of `--reasoning-effort`. Web search is ON by default (only `--disable-web-search` disables it). NEVER attach the executor `--rules` contract to an advisor consult — that belongs to `armory grok-xhigh` execution children only.
- **Voice:** match `~/.claude/skills/using-llm-armory/SKILL.md` — imperative, terse, tables and recipe blocks, a Common-mistakes table. Single file.
- **Six guardrails MUST all be present** in SKILL.md: echo-chamber, self-preference (verify), capability-floor, complementarity, cost-gate, transport-distinction.
- **Trigger:** manual invoke only. No auto-triggering language in v1.
- **Source of truth:** the design spec `docs/superpowers/specs/2026-07-10-fusion-advisor-design.md`. Where this plan and the spec disagree, the spec wins — stop and reconcile.

---

### Task 1: Scaffold — branch, dir, frontmatter, Overview, cost gate

**Files:**
- Create: `~/.claude/skills/fusion-advisor/SKILL.md`

**Interfaces:**
- Consumes: nothing.
- Produces: the SKILL.md file with frontmatter (`name: fusion-advisor`) and the top two sections (`## Overview`, `## When to use / when NOT (cost gate)`). Later tasks append sections to this same file.

- [ ] **Step 1: Preflight — branch the skills repo**

Run:
```bash
git -C ~/.claude rev-parse --abbrev-ref HEAD
git -C ~/.claude checkout -b skill/fusion-advisor 2>/dev/null || git -C ~/.claude checkout skill/fusion-advisor
mkdir -p ~/.claude/skills/fusion-advisor
```
Expected: on branch `skill/fusion-advisor`; directory exists.

- [ ] **Step 2: Write the failing presence test**

Run (before creating the file):
```bash
grep -qE '^name: fusion-advisor' ~/.claude/skills/fusion-advisor/SKILL.md 2>/dev/null && echo PASS || echo FAIL
grep -q 'cost gate' ~/.claude/skills/fusion-advisor/SKILL.md 2>/dev/null && echo PASS || echo FAIL
```
Expected: `FAIL` then `FAIL` (file absent).

- [ ] **Step 3: Create SKILL.md with frontmatter + Overview + cost gate**

Write `~/.claude/skills/fusion-advisor/SKILL.md` with exactly this content:
````markdown
---
name: fusion-advisor
description: Use when you want two different frontier models fused into one advisor brain for a high-leverage decision — "fuse", "fusion advisor", "get a second/peer model on this", "have Grok weigh in", "advisor fusion", "am I sure — bring in another model". This Opus session reasons, consults Grok as a context-isolated peer, reconciles by verifying (not voting), then delegates execution via using-llm-armory. NOT for routine steps (cost gate), and NOT for execution dispatch (that is using-llm-armory).
---

# Fusion Advisor (two-model peer fusion at the reasoning layer)

## Overview

Turns this Opus 4.8 (Claude Code) session into a **two-model advisor**. At a high-leverage
decision point, Opus consults **Grok** (different vendor → different blind spots) as a
context-isolated peer, reconciles the two positions by **verifying claims — not voting**, and
emits the advisor artifact: a plan, a `/loop` decision, a review. Execution then flows down to
grok/sonnet children via `using-llm-armory`. **Fusion decides; armory executes.**

Naive "two models beat one" is false (see Guardrails). Fusion pays off only on hard judgment,
and only with structure. This skill IS that structure.

Advisor half stays here (frame, reconcile, verify, decide). Peer half is one isolated Grok
consult per invocation. Never a debate club.

## When to use / when NOT (cost gate)

**Use at high-leverage points only:** design forks, plan approval, a genuine "am I sure?"
moment, `/loop` course-corrections, risky diffs (auth, billing, migrations, concurrency,
cross-zone). This is the same bar as `adversarial-review`.

**Do NOT use for:** routine or mechanical steps; execution dispatch (that is
`using-llm-armory`); or as a second code executor. Fusion costs 2–10× tokens and over-fusing
invites the echo chamber (see Guardrails). **Manual invoke only** — this skill never
self-triggers.
````

- [ ] **Step 4: Run the presence test — verify PASS**

Run:
```bash
grep -qE '^name: fusion-advisor' ~/.claude/skills/fusion-advisor/SKILL.md && echo PASS || echo FAIL
grep -q 'cost gate' ~/.claude/skills/fusion-advisor/SKILL.md && echo PASS || echo FAIL
grep -q 'Fusion decides; armory executes' ~/.claude/skills/fusion-advisor/SKILL.md && echo PASS || echo FAIL
```
Expected: `PASS` `PASS` `PASS`.

- [ ] **Step 5: Commit**

```bash
git -C ~/.claude add skills/fusion-advisor/SKILL.md
git -C ~/.claude commit -m "feat(skill): scaffold fusion-advisor — frontmatter, overview, cost gate"
```

---

### Task 2: Default protocol (topology A) + transport recipe

**Files:**
- Modify: `~/.claude/skills/fusion-advisor/SKILL.md` (append)

**Interfaces:**
- Consumes: the file from Task 1.
- Produces: `## Default protocol — parallel-independent → reconcile` and `## Transport recipe` sections. The transport recipe (`grok -p … --effort xhigh --always-approve`) is referenced by Task 7's smoke test.

- [ ] **Step 1: Write the failing presence test**

Run:
```bash
grep -q 'parallel-independent → reconcile' ~/.claude/skills/fusion-advisor/SKILL.md && echo PASS || echo FAIL
grep -q 'grok -p' ~/.claude/skills/fusion-advisor/SKILL.md && echo PASS || echo FAIL
```
Expected: `FAIL` `FAIL`.

- [ ] **Step 2: Append the protocol + transport sections**

Append to `~/.claude/skills/fusion-advisor/SKILL.md`:
````markdown
## Default protocol — parallel-independent → reconcile

1. **Frame.** Write a crisp brief: the decision/question + the minimal shared facts (paths,
   constraints). Same discipline as `adversarial-review`. Keep your own leaning OUT of it —
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
   executors, or the next `/loop` action. Then hand implementation to `using-llm-armory`.

## Transport recipe

Advisor consult (verified flags):

```bash
grok -p "<brief + the question>" --effort xhigh --always-approve
# long consult → run in background, then poll the output file:
#   run_in_background: true, then Read the task output; heartbeat like armory monitoring.
```

- `--effort xhigh` (alias of `--reasoning-effort`) → maximum reasoning.
- `--always-approve` → headless, no tool-approval prompt hang.
- Web/X search is ON by default; add `--disable-web-search` only to force offline reasoning.
- **NEVER** attach the executor `--rules` contract here. `grok -p` (bare) = advisor consult.
  `armory grok-xhigh` (with the executor contract) = execution child. They are different jobs.
````

- [ ] **Step 3: Run the presence test — verify PASS**

Run:
```bash
for p in 'parallel-independent → reconcile' 'grok -p' 'effort xhigh' 'Steelman' 'NEVER' 'Transport recipe'; do
  grep -q "$p" ~/.claude/skills/fusion-advisor/SKILL.md && echo "PASS: $p" || echo "FAIL: $p"
done
```
Expected: all six lines `PASS`.

- [ ] **Step 4: Commit**

```bash
git -C ~/.claude add skills/fusion-advisor/SKILL.md
git -C ~/.claude commit -m "feat(skill): fusion-advisor default protocol + transport recipe"
```

---

### Task 3: critique mode (B) + council escalation (C)

**Files:**
- Modify: `~/.claude/skills/fusion-advisor/SKILL.md` (append)

**Interfaces:**
- Consumes: the file from Task 2.
- Produces: `## critique mode` and `## council escalation` sections, each cross-referencing `adversarial-review`.

- [ ] **Step 1: Write the failing presence test**

Run:
```bash
grep -q '## critique mode' ~/.claude/skills/fusion-advisor/SKILL.md && echo PASS || echo FAIL
grep -q '## council escalation' ~/.claude/skills/fusion-advisor/SKILL.md && echo PASS || echo FAIL
```
Expected: `FAIL` `FAIL`.

- [ ] **Step 2: Append the two mode sections**

Append to `~/.claude/skills/fusion-advisor/SKILL.md`:
````markdown
## critique mode (harden ONE artifact)

Asymmetric peer review for a single concrete artifact (a spec/plan) before it ships to
executors:

1. Opus drafts the artifact.
2. `grok -p "<draft>. Try to break this: where does it fail — gaps, races, wrong
   assumptions, missed cases? Assume it is broken until proven otherwise." --effort xhigh --always-approve`
3. Opus revises against Grok's attack (verify each claim first — reviewers are sometimes wrong).
4. Optional single Grok re-check.

1–2 bounded rounds, never more. This is `adversarial-review` with a genuinely different second
model instead of same-model-two-prompts.

## council escalation (rare, highest-stakes only)

Opus + Grok + ONE third independent voice, Opus chairs and verifies. The third voice is a
second isolated Grok consult with a different framing, OR a model lane the user has
**explicitly** named (do not silently pull in a skipped armory lane). ~3–4× cost and more
reconciliation overhead — reserve for irreversible, high-blast-radius calls. Not a default.
````

- [ ] **Step 3: Run the presence test — verify PASS**

Run:
```bash
for p in '## critique mode' '## council escalation' 'adversarial-review with a genuinely different' 'Opus chairs and verifies'; do
  grep -q "$p" ~/.claude/skills/fusion-advisor/SKILL.md && echo "PASS: $p" || echo "FAIL: $p"
done
```
Expected: all four `PASS`.

- [ ] **Step 4: Commit**

```bash
git -C ~/.claude add skills/fusion-advisor/SKILL.md
git -C ~/.claude commit -m "feat(skill): fusion-advisor critique mode + council escalation"
```

---

### Task 4: Guardrails (all six) + reconcile discipline

**Files:**
- Modify: `~/.claude/skills/fusion-advisor/SKILL.md` (append)

**Interfaces:**
- Consumes: the file from Task 3.
- Produces: `## Guardrails` (six bullets) and `## Reconcile discipline` sections. Task 8's final validation greps every guardrail marker.

- [ ] **Step 1: Write the failing presence test**

Run:
```bash
grep -q '## Guardrails' ~/.claude/skills/fusion-advisor/SKILL.md && echo PASS || echo FAIL
grep -qi 'echo.chamber' ~/.claude/skills/fusion-advisor/SKILL.md && echo PASS || echo FAIL
```
Expected: `FAIL` `FAIL`.

- [ ] **Step 2: Append Guardrails + Reconcile discipline**

Append to `~/.claude/skills/fusion-advisor/SKILL.md`:
````markdown
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
````

- [ ] **Step 3: Run the presence test — verify PASS (all six guardrails)**

Run:
```bash
for p in 'Echo-chamber guard' 'Self-preference guard' 'Capability floor' 'Complementarity focus' 'Cost gate' 'Transport distinction' 'Reconcile discipline'; do
  grep -q "$p" ~/.claude/skills/fusion-advisor/SKILL.md && echo "PASS: $p" || echo "FAIL: $p"
done
```
Expected: all seven `PASS`.

- [ ] **Step 4: Commit**

```bash
git -C ~/.claude add skills/fusion-advisor/SKILL.md
git -C ~/.claude commit -m "feat(skill): fusion-advisor guardrails + reconcile discipline"
```

---

### Task 5: Integration/handoff + degradation + Common-mistakes table

**Files:**
- Modify: `~/.claude/skills/fusion-advisor/SKILL.md` (append)

**Interfaces:**
- Consumes: the file from Task 4.
- Produces: `## Integration`, `## Degradation`, and `## Common mistakes` sections — completing the SKILL.md body.

- [ ] **Step 1: Write the failing presence test**

Run:
```bash
grep -q '## Common mistakes' ~/.claude/skills/fusion-advisor/SKILL.md && echo PASS || echo FAIL
grep -q '## Degradation' ~/.claude/skills/fusion-advisor/SKILL.md && echo PASS || echo FAIL
```
Expected: `FAIL` `FAIL`.

- [ ] **Step 2: Append Integration + Degradation + Common mistakes**

Append to `~/.claude/skills/fusion-advisor/SKILL.md`:
````markdown
## Integration

- **`using-llm-armory`** — the execution layer BELOW this skill. Fusion produces the
  plan/decision; hand ALL implementation dispatch to armory executor children. Fusion never
  writes production code itself.
- **`improve`** — the read-only senior-advisor workflow (audit → plans for other agents).
  Fusion is the reasoning upgrade for that role: fusion = *how it thinks*; improve = *what it
  produces*.
- **`/loop` (ralph-loop)** — inside an autonomous program of work, invoke fusion manually at
  per-iteration course-corrections ("what next / is this right / stop?").
- **`adversarial-review`** — the structural ancestor (isolate-then-reconcile). Use it for the
  same-model variant; use `critique` mode here when you want a genuinely different model.

## Degradation

- **Grok unavailable / errors / times out** → fall back to solo Opus and STATE
  "fusion unavailable — solo advisory." Never silently pretend a consult happened.
- **Unresolved disagreement** (verification cannot settle it) → surface to the human as a
  stop-and-ask. Survived disagreement is exactly the signal worth escalating.
- **Long consult** → background launch + heartbeat poll (mirror armory monitoring).

## Common mistakes

| Mistake | Correct |
|---|---|
| Fusing on a routine step | Cost gate: fuse only at high-leverage decision points |
| Leaking your leaning into the Grok brief | Isolated brief — isolation is the objectivity device |
| Treating agreement as proof | Agreement ≠ correctness; mine the disagreement |
| Letting one model pick the "winner" | Aggregator verifies vs reality; steelman dissent |
| N-round debate to force consensus | Independent-then-reconcile, capped rounds |
| Attaching executor `--rules` to an advisor consult | Bare `grok -p` for advice; `armory grok-xhigh` for execution |
| Fusion writing the production code | Delegate implementation to `using-llm-armory` children |
| Averaging in a low-quality Grok answer | Discard it, proceed solo, note it |
| Silent solo fallback when Grok fails | State "fusion unavailable — solo advisory" |
````

- [ ] **Step 3: Run the presence test — verify PASS**

Run:
```bash
for p in '## Integration' '## Degradation' '## Common mistakes' 'fusion unavailable — solo advisory' 'using-llm-armory'; do
  grep -q "$p" ~/.claude/skills/fusion-advisor/SKILL.md && echo "PASS: $p" || echo "FAIL: $p"
done
```
Expected: all five `PASS`.

- [ ] **Step 4: Commit**

```bash
git -C ~/.claude add skills/fusion-advisor/SKILL.md
git -C ~/.claude commit -m "feat(skill): fusion-advisor integration, degradation, common mistakes"
```

---

### Task 6: Cross-link from using-llm-armory

**Files:**
- Modify: `~/.claude/skills/using-llm-armory/SKILL.md` (append a "See also" line to its `## When NOT to use` / end section)

**Interfaces:**
- Consumes: nothing from prior tasks (independent edit).
- Produces: a one-line pointer so a session already in the armory knows the advisor-reasoning layer exists above it.

- [ ] **Step 1: Write the failing presence test**

Run:
```bash
grep -q 'fusion-advisor' ~/.claude/skills/using-llm-armory/SKILL.md && echo PASS || echo FAIL
```
Expected: `FAIL`.

- [ ] **Step 2: Read the tail of using-llm-armory to find the insertion point**

Run:
```bash
tail -12 ~/.claude/skills/using-llm-armory/SKILL.md
```
Note the final section heading (e.g. `## When NOT to use`).

- [ ] **Step 3: Append the cross-link**

Append to `~/.claude/skills/using-llm-armory/SKILL.md`:
````markdown

## See also

- **`fusion-advisor`** — the reasoning layer ABOVE this skill. When the *decision* about what
  to dispatch is itself high-leverage (design fork, risky diff, `/loop` course-correction),
  fuse Opus + Grok as an advisor first, then dispatch execution here.
````

- [ ] **Step 4: Run the presence test — verify PASS**

Run:
```bash
grep -q 'fusion-advisor' ~/.claude/skills/using-llm-armory/SKILL.md && echo PASS || echo FAIL
```
Expected: `PASS`.

- [ ] **Step 5: Commit**

```bash
git -C ~/.claude add skills/using-llm-armory/SKILL.md
git -C ~/.claude commit -m "docs(skill): cross-link using-llm-armory -> fusion-advisor"
```

---

### Task 7: Live transport smoke test + degradation check

**Files:**
- Modify (only if the recipe proves wrong): `~/.claude/skills/fusion-advisor/SKILL.md`

**Interfaces:**
- Consumes: the Transport recipe section from Task 2.
- Produces: confirmation the recipe works headless, OR a corrected recipe. This is the one behavioral test — do not skip it.

- [ ] **Step 1: Run a real advisor consult (small, cheap brief)**

Run (foreground is fine — tiny prompt):
```bash
grok -p "One short paragraph: name the single biggest risk when two similar-capability LLMs from different vendors act as peer advisors, and the one mitigation that matters most. Be concrete." --effort xhigh --always-approve 2>&1 | tail -30
```
Expected: a coherent non-empty paragraph on stdout (likely naming echo-chamber/correlated-error and independent-reconcile or verification). Confirms headless advisor mode returns a usable position.

- [ ] **Step 2: Confirm the degradation path (bad invocation fails cleanly)**

Run:
```bash
grok -p "test" --effort not-a-real-level --always-approve 2>&1 | tail -5; echo "EXIT=$?"
```
Expected: a clear error and a nonzero-ish signal (not a hang). Confirms a broken consult surfaces as an error the skill can catch and fall back from — matches the Degradation section. If it hangs instead of erroring, note that the skill's background+poll+timeout guidance is load-bearing.

- [ ] **Step 3: Reconcile recipe with observed behavior**

If Step 1's flags differed from the SKILL.md Transport recipe (e.g. `--effort` rejected, search off), edit `~/.claude/skills/fusion-advisor/SKILL.md` Transport recipe to the exact working flags. If it matched, make NO edit.

- [ ] **Step 4: Commit (only if Step 3 edited the file)**

```bash
git -C ~/.claude add skills/fusion-advisor/SKILL.md
git -C ~/.claude commit -m "fix(skill): fusion-advisor transport recipe reconciled with live grok flags"
```
If no edit was needed, skip the commit and record "recipe confirmed, no change" in the task notes.

---

### Task 8: Final validation gate (spec §10 coverage)

**Files:**
- Read-only: `~/.claude/skills/fusion-advisor/SKILL.md`

**Interfaces:**
- Consumes: the complete SKILL.md.
- Produces: a pass/fail report against spec §10. No new content unless a gap is found.

- [ ] **Step 1: Run the consolidated coverage check**

Run:
```bash
F=~/.claude/skills/fusion-advisor/SKILL.md
for p in \
  '^name: fusion-advisor' '## Overview' 'cost gate' \
  'parallel-independent → reconcile' 'grok -p' 'effort xhigh' \
  '## critique mode' '## council escalation' \
  'Echo-chamber guard' 'Self-preference guard' 'Capability floor' \
  'Complementarity focus' 'Cost gate' 'Transport distinction' \
  '## Reconcile discipline' '## Integration' 'using-llm-armory' \
  '## Degradation' 'fusion unavailable — solo advisory' '## Common mistakes' ; do
  grep -qE "$p" "$F" && echo "PASS: $p" || echo "FAIL: $p"
done
```
Expected: every line `PASS`. Any `FAIL` is a spec-coverage gap → add the missing content to the relevant section, re-run, then commit with `git -C ~/.claude`.

- [ ] **Step 2: Confirm the skill resolves by name**

Run:
```bash
ls -ld ~/.claude/skills/fusion-advisor && head -3 ~/.claude/skills/fusion-advisor/SKILL.md
```
Expected: directory exists; frontmatter starts with `---` then `name: fusion-advisor`. (In a live session, `/fusion-advisor` should now be invocable — mention this to the user for a manual confirm.)

- [ ] **Step 3: Report**

Summarize: branch `skill/fusion-advisor` in `~/.claude`, N commits, all coverage checks PASS, transport recipe confirmed (Task 7). Note that merging `skill/fusion-advisor` and `docs/fusion-advisor-design` is left to the user (no push/merge without explicit ask).

---

## Self-Review

**Spec coverage** (spec → task):
- §4.1 default protocol A → Task 2. §4.2 critique mode B → Task 3. §4.3 council C → Task 3.
- §5 six guardrails → Task 4 (+ Task 8 verifies all six). §6 manual trigger → Task 1 (cost-gate section states "manual invoke only").
- §7 integration (armory/improve/loop/adversarial-review) → Task 5 + Task 6 cross-link.
- §8 degradation → Task 5. §9 SKILL shape → Tasks 1–5 build every named section.
- §10 validation → Task 7 (live smoke + degradation) + Task 8 (coverage/name-resolve).
- §11 residual risks: self-preference bias → Guardrails (Task 4); confirm grok flags → Task 7. No gaps.

**Placeholder scan:** no TBD/TODO; every section step contains the actual markdown content; grep commands have exact expected output. Clear.

**Type/name consistency:** section headings referenced in Task 8's grep match the headings authored in Tasks 1–5 verbatim (`## Overview`, `## Guardrails`, `## Reconcile discipline`, `## Integration`, `## Degradation`, `## Common mistakes`, `## critique mode`, `## council escalation`). Transport recipe string `grok -p … --effort xhigh --always-approve` is identical in Task 2, Task 3 (critique), Task 7, and Global Constraints.
