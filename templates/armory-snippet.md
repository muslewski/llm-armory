# llm-armory usage (for CLAUDE.md / AGENTS.md)

Add this to your repo's `CLAUDE.md` (or `AGENTS.md` for Grok) so agents know how to use the armory.

---

## llm-armory — choose the right executor

The armory provides named **loadouts** for deliberate delegation from advisor sessions.

**Primary pattern (Fable advisor + Grok executors):**

When you (the advisor) want heavy implementation done:

```
armory grok-xhigh -p "Implement task N from the plan in docs/plan.md. Work in a fresh worktree if appropriate." -w feature-xyz
```

- `quality` — pure native Fable/Max advisor session (no overrides).
- `grok-xhigh` — the main heavy loadout: SuperGrok Heavy at `--effort xhigh`, with executor contract (one commit per task, PROGRESS.md, RESULT line).

**Rules for using the armory:**
- Only use when the current user prompt or your top-level instructions explicitly say to arm a child (e.g. "use the armory", "delegate to grok-xhigh", "run this on grok xhigh").
- Always pass a complete self-contained prompt with the task brief / plan reference.
- Use `-w <name>` / `--worktree` for isolation on non-trivial tasks.
- After the child finishes, review its `RESULT:` line and diffs in this (advisor) session before merging.
- Never use `armory` inside a pure Grok session — use Grok's native `spawn_subagent` tool instead.

**Examples**
- `armory --list`
- `armory --dry-run grok-xhigh`
- `armory grok-xhigh -p "..." -w my-task --max-turns 40`

The launcher is usually available as `armory` (symlink to the repo's bin/llm) or `./bin/llm` inside the llm-armory repo.

**Important:** This mechanism is **for Claude Code CLI (Fable) sessions** to delegate to Grok. If you are Grok, prefer your native tools and subagents.

---

Copy the relevant parts into your CLAUDE.md. Run `armory --list` to see current loadouts.
