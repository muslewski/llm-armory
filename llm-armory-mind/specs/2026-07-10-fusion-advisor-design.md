# fusion-advisor — design

- **Date:** 2026-07-10
- **Status:** Approved design → next: implementation plan
- **Deliverable:** one global skill, `~/.claude/skills/fusion-advisor/SKILL.md`
- **Owner session role:** Opus 4.8 (Claude Code) as orchestrator/aggregator

## 1. Problem

The current setup pairs a **strong premium advisor** (Fable 5 / Opus) that reasons, plans,
and watches over **cheaper executors** (grok/sonnet children via `using-llm-armory`) that
implement. The advisor's *judgment* is the load-bearing part.

When access to a single dominant advisor model narrows, the fallback is two peers of
**similar** capability from **different vendors** — here Opus 4.8 (Claude Code) and Grok
(Grok Build CLI, xhigh). The question this design answers: **how do you fuse two peer
models into one advisor brain that reasons better than either alone — without falling into
the well-documented traps of naive multi-model mixing?**

The fusion is at the **advisor/reasoning layer only**. Actual execution still flows down to
grok/sonnet children via the existing armory. Fusion decides; armory executes.

## 2. Non-goals

- Not a peer *executor* fusion (two models both writing code and merging diffs). Execution
  stays single-executor via `using-llm-armory`.
- Not a general "always use two models" mode. Fusion is reserved for high-leverage decision
  points; routine steps stay solo (see cost gate).
- Not a new launcher/proxy. Transport is plain `grok -p`; no `armory` change required.
- Not naive multi-round debate — explicitly ruled out by the research (§3).

## 3. Research grounding (what shaped the guardrails)

Sourced from three Grok live-X/web research passes (2026-07-10). The naive premise
"two models > one" is **false in general**; fusion only pays off under specific conditions.

**Traps (where multi-model mixing HURTS):**
- **Mixed-MoA often loses to Self-MoA** — mixing different LLMs dilutes average proposer
  quality; single-strong-model repeated sampling beat mixed-model MoA by +6.6% LC on
  AlpacaEval 2.0. (arXiv:2502.00674, "Rethinking Mixture-of-Agents", Princeton)
- **Heterogeneous debate can degrade *below* a single agent** — a weaker voice persuades
  the stronger via echo chamber; more rounds frequently make it worse. (arXiv:2509.05396)
- **Similar-capability models converge to a shared-misconception majority** — static
  dynamics / echo chamber; two peers agreeing is weak signal. (Estornell & Liu, NeurIPS 2024)
- **LLM-as-judge self-preference bias** — a model favors its own output, so "let one model
  pick the winner" is structurally biased.

**Payoff conditions (where fusion WINS):** hard reasoning, ambiguity, high-stakes
verification — *when* models are complementary + structure is strong + the aggregator is
strong. Cross-vendor medical consensus reached +16pp over a single LLM; OSS layered MoA beat
GPT-4o (65.1% vs 57.5% AlpacaEval); Perplexity Model Council / Nous Hermes MoA report
+6–11% on hard/agentic tasks. (arXiv:2406.04692; together.ai/blog/together-moa;
perplexity.ai model council; Hermes Agent MoA docs)

**Design consequences (each becomes a guardrail in §5):**
1. Both peers must be **frontier** (Opus + Grok-xhigh) → capability match avoids the
   weak-model-drags-group-down failure.
2. **Avoid naive multi-round debate** → use independent-then-reconcile, capped rounds.
3. **Value is complementarity, not redundancy** → mine disagreement, not agreement.
4. **Aggregator must verify, not vote** → self-preference bias means the reconciler checks
   claims against reality and steelmans dissent.
5. **Cost/latency is 2–10×** → reserve fusion for high-leverage points only.

## 4. Architecture

`fusion-advisor` is a **global skill** invoked manually in an Opus (Claude Code) session at a
decision point. The session is the orchestrator and the aggregator; Grok is a context-isolated
peer consulted per invocation.

```
                 fusion-advisor (this Opus session)
                 ┌───────────────────────────────────────┐
  decision  ───▶ │ 1 Frame  → 2 Consult Grok (isolated)   │
  point          │            ‖ 3 Opus reasons (parallel) │
                 │ 4 Reconcile (verify, steelman dissent)  │
                 │ 5 Emit advisor artifact + residual risk │
                 └──────────────────┬────────────────────┘
                                    │ delegates execution
                                    ▼
                 using-llm-armory → grok / sonnet executor children
```

### 4.1 Default protocol — topology A (parallel-independent → reconcile)

1. **Frame.** Opus writes a crisp brief: the decision/question + minimal shared facts
   (paths, constraints). Same discipline as `adversarial-review`.
2. **Consult, isolated.** `grok -p "<brief + question>" --effort xhigh` in **advisor mode**
   (web/X search on; **not** the armory executor `--rules` contract). Opus does *not* leak
   its own leaning into the prompt — isolation is the objectivity device. Long consults run
   in background (`run_in_background: true`) and are polled.
3. **Opus reasons in parallel.** Opus forms its own independent position while Grok runs.
4. **Reconcile.** Opus compares the two positions:
   - **Agreements** → high-confidence, but not proof (echo-chamber caveat).
   - **Disagreements** → the signal; resolve each explicitly by verifying against
     codebase/reality. Steelman Grok's dissent before overriding it.
   - **Grok-only points** → candidate blind-spot catches; verify and fold in.
5. **Emit + delegate.** Output the advisor artifact — a decision with residual risks, a plan
   for executors, or the next `/loop` action — then dispatch execution to grok/sonnet
   children per `using-llm-armory`.

### 4.2 Second mode — `critique` (topology B: draft → cross-critique → revise)

Asymmetric peer review for hardening ONE concrete artifact (a spec/plan) before it ships to
executors: Opus drafts → Grok attacks as skeptic (`grok -p`, xhigh) → Opus revises →
optional Grok re-check. 1–2 bounded rounds. This is `adversarial-review` with a genuinely
different second model instead of same-model-two-prompts.

### 4.3 Council mode (topology C) — documented, not default

Opus + Grok + a third independent voice (2nd Grok subagent, or DeepSeek/GLM via armory),
Opus chairs and synthesizes. Reserved for rare highest-stakes calls; ~3–4× cost. Included in
the skill as an escalation, not a default.

## 5. Guardrails (must appear in SKILL.md)

- **Echo-chamber guard** — no naive N-round debate; independent-then-reconcile, capped rounds.
- **Self-preference guard** — the aggregator (Opus) verifies claims against reality and
  steelmans dissent; agreement between the two models is *not* evidence of correctness.
- **Capability floor** — both peers must be frontier (Opus + Grok-xhigh). A weak model is an
  *executor*, never an advisor peer.
- **Complementarity focus** — spend the reconcile budget on where the two disagree.
- **Cost gate** — fuse only at high-leverage points: design forks, plan approval, "am I
  sure?", `/loop` course-corrections, risky diffs. Routine steps stay solo Opus.
- **Transport distinction** — `grok -p … --effort xhigh` for advisor consults;
  `armory grok-xhigh` for execution children. Never cross them: an advisor consult must not
  carry the executor coding contract, and an executor child must not be treated as a peer
  advisor.

## 6. Trigger model

**Manual invoke** (approved). The user, or a parent skill (`/improve`, `/loop`,
brainstorming), explicitly invokes `fusion-advisor` at a decision point. No auto-triggering
in v1 — predictable, no surprise token spend. (An opt-in auto mode for long autonomous loops
is a possible future extension, out of scope here.)

## 7. Integration with existing assets

- **`using-llm-armory`** — fusion-advisor sits *above* it. Fusion produces the plan/decision;
  the skill then hands implementation to armory executor children. The SKILL explicitly
  cross-references and defers to `using-llm-armory` for all execution dispatch.
- **`improve`** — `improve` is the read-only senior-advisor workflow (audit → plans for other
  agents). fusion-advisor is the *reasoning upgrade* for that role: run improve-style
  judgment as a two-model fusion. Fusion = "how it thinks"; improve = "what it produces".
- **`/loop` (ralph-loop)** — inside an autonomous program of work, the per-iteration decision
  ("what next / is this right / stop?") is a natural fusion checkpoint, invoked manually at
  course-correction points.
- **`adversarial-review`** — its isolate-then-reconcile structure is the backbone;
  `critique` mode (§4.2) is essentially adversarial-review with a real second model. SKILL
  notes the lineage and points to it for the same-model variant.

## 8. Graceful degradation & edge cases

- **Grok unavailable / errors / times out** → fall back to solo Opus and state
  "fusion unavailable — solo advisory" in the output. Never silently pretend a consult happened.
- **Unresolved disagreement** (verification can't settle it) → surface to the human as a
  stop-and-ask. This is a feature: genuine peer disagreement that survives verification is
  exactly the signal worth escalating.
- **Long consult** → background launch + heartbeat poll, mirroring armory monitoring.
- **Grok returns low-quality/off-topic** → Opus discards and proceeds solo, noting it; does
  not average a bad response into the decision (quality-over-diversity finding).

## 9. SKILL.md shape (deliverable outline)

Frontmatter `description` triggers on: "fuse", "fusion advisor", "second model / peer model
on this", "have Grok weigh in", "advisor fusion", "am I sure — get another model".
Body sections: Overview → When to use / when NOT to (cost gate) → Default protocol (A) →
critique mode (B) → council escalation (C) → Guardrails → Transport (`grok -p` recipe, xhigh,
search on, background+poll) → Reconcile discipline (verify, steelman, disagreement=signal) →
Integration & handoff to `using-llm-armory` → Degradation → Common mistakes table.

## 10. Validation (how we know it works)

- **Dry-run consult** — invoke on a real recent decision; confirm `grok -p … --effort xhigh`
  fires, returns a position, and Opus produces a reconciled artifact naming ≥1 concrete
  agreement and ≥1 disagreement resolved by verification.
- **Degradation path** — simulate Grok failure (e.g. bad flag), confirm clean solo fallback
  with the explicit note.
- **Transport separation** — confirm advisor consults use `grok -p` (no executor `--rules`)
  and that a follow-on execution correctly routes through `using-llm-armory`.
- **Guardrail presence** — SKILL.md contains all six §5 guardrails and the cost gate.

## 11. Residual risks / open questions

- **Self-preference bias in Opus-as-aggregator** — Opus reconciles and may favor its own
  view. Mitigated by the steelman-dissent rule and verify-against-reality, but not eliminated.
  Acceptable for v1 (human supervises the session). Revisit if fusion runs unattended in loops.
- **Grok CLI advisor-mode assumptions** — assumes `grok -p … --effort xhigh` with
  `--always-approve` runs headless with web/X search and returns a clean final answer to
  stdout. Verified working during research passes; the plan should re-confirm the exact flag
  set in a smoke test.
- **Cost discipline is behavioral** — the cost gate is a rule, not an enforced limit. Relies
  on the advisor honoring it.
