#!/usr/bin/env bash
# Stop gate for llm executor children: a session may not end while the
# worktree holds uncommitted work. 2026-07-06 bake-off: three children died
# silently leaving everything uncommitted — salvage triage cost hours. This
# converts silent death into one loud correction: the first stop attempt is
# blocked with instructions; the second (stop_hook_active) always passes so
# a hard-blocked child can still terminate.
set -euo pipefail

input=$(cat)

# Already blocked once this stop cycle — let the session end.
if printf '%s' "$input" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

# Run in the session's project dir when the payload names one.
cwd=$(printf '%s' "$input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
if [[ -n "$cwd" && -d "$cwd" ]]; then
  cd "$cwd"
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# PROGRESS.md is the child's untracked scratch ledger — never counts as dirty.
dirty=$(git status --porcelain 2>/dev/null | grep -v 'PROGRESS\.md$' || true)
[[ -z "$dirty" ]] && exit 0

# JSON-escape the file list (backslashes, quotes, newlines).
dirty_esc=$(printf '%s' "$dirty" | head -15 | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}')

cat <<EOF
{"decision": "block", "reason": "Your worktree has uncommitted changes:\n${dirty_esc}Do not end the session like this. Now: (1) commit completed work — one commit per finished task with a real message; (2) delete junk files you created by accident; (3) if a task failed, do not commit broken code — state it in your final report as: RESULT: failed — <reason>. Then end your turn."}
EOF
exit 0
