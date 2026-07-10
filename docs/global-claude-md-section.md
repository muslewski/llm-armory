# armory — llm-armory (executor lanes / loadouts)

`armory <lane>` (or `llm <lane>` during transition) lets Claude Code advisor sessions
arm themselves with specialist executor lanes.

Home: `~/Repositories/llm-armory` (the llm-armory).

**Current primary lane:** `armory grok-xhigh` — delegate heavy execution to SuperGrok Heavy (xhigh) from Fable sessions.

Legacy free/balanced dispatch rules are disabled. This doc is retained for historical notes.

- `llm free -p "<task>"` — headless executor on the self-hosted freellmapi free pool ($0).
  Model is PINNED (kimi-k2.6; glm-4.7 for haiku-tier) — never switch the preset back to
  `auto`, it routes per-request by availability and destroys session coherence.
- `llm quality` / plain `claude` — native Max. NEVER set `ANTHROPIC_BASE_URL` on a Max session.
- `llm balanced -p "<task>"` — paid executor on DeepSeek direct (v4-pro[1m] main,
  v4-flash haiku-slot). Same child contract + guardrail hooks as `free`. This is the
  "sonnet = deepseek" lane: opus judgment stays native Max, implementation runs here.
  Unkeyed until `presets/providers/deepseek.env` exists — refuses to launch without it.
- `glm` — exists but unkeyed for now; refuses to launch.

## Dispatch rule (IMPORTANT)

When the user says to run/spawn/implement something "on llm free" / "free executor" /
"cheap executor" / "executor tier", they mean: spawn child processes via Bash
`llm free -p "<complete self-contained prompt>"` — NOT the built-in Agent/Task tool with
haiku or any Claude Code subagent. Built-in subagents bill this session's Max plan;
`llm free` children bill $0. Division of labor: judgment (brainstorm/spec/plan/review/verify)
stays on Max in this session; implementation/chores go to `llm free` children.

Mechanics:
- Parallel children editing the same repo → one git worktree per child, merge after review.
  Seed any untracked inputs (plan files, briefs) into each worktree before launch —
  worktrees only carry committed state.
- Cap free-lane parallelism at 2-3 children; queue the rest. Free-provider daily quotas are
  shared — 4+ parallel plan-scale children exhausted the pool mid-run and later children
  launched into nothing.
- Long tasks: launch with `run_in_background: true` (plan executions run 10min+; foreground
  Bash times out at 10min).
- Each child is a full Claude Code session (loads repo CLAUDE.md, edits, commits). Give it a
  complete prompt: plan/brief path, branch or worktree, verification commands, "report
  tasks/commits/results at the end". Tell it NOT to run repo generators/side-effect scripts
  (e.g. a project's own build/generate script) unless the plan names them.
- `llm` preflights the pool before launching and exits NONZERO if the pool is dead or
  exhausted — a nonzero exit means don't blind-retry; check `llm-pool-report` first.
- Children run under guardrail hooks (auto-injected): every Write/Edit is checked for
  syntax/phantom-import/garbage with errors fed back to the child; a stop gate blocks
  ending the session with uncommitted work.

Child contract (the free preset injects it): one commit per completed task; PROGRESS.md
ledger in the worktree (untracked — ignore it in diffs, read it for state); final message
ends with `RESULT: ok|partial|failed — commits: <n> — <summary>`.

Monitoring children (do this, don't wait blind):
- Heartbeat every ~5 min per worktree: `git -C <wt> log --oneline -1 && git status --short`
  plus `cat <wt>/PROGRESS.md`. No commits after the first task-sized interval, or no change
  across two polls → the child is dead or looping: kill it and relaunch ONE fresh child with
  a resume prompt naming (a) what PROGRESS.md says is done, (b) concrete defects/leftovers.
- Parse the child's final `RESULT:` line before auditing diffs — a truthful `failed` report
  saves a full diff audit.
- After a batch, run `llm-pool-report [hours]` to attribute which pool models/providers
  actually served and what errored (child transcripts only record the requested model).
- After children finish: review their diffs in THIS session (Max) — free-tier output gets a
  skeptical spec-compliance + quality review before merge.
