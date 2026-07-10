#!/usr/bin/env bash
# Bake-off: run the same task brief through several presets, one worktree each.
# Usage: bakeoff/run.sh <brief-file> <preset> [preset...]
# Env:   BAKEOFF_REPO (required — path to the target repo the bake-off runs in)
set -euo pipefail

[[ $# -ge 2 ]] || { echo "usage: $0 <brief-file> <preset> [preset...]" >&2; exit 1; }
BRIEF_FILE=$(realpath "$1"); shift
[[ -f "$BRIEF_FILE" ]] || { echo "no such brief: $BRIEF_FILE" >&2; exit 1; }

REPO="${BAKEOFF_REPO:?set BAKEOFF_REPO to the target repo path}"
LAB="${LLM_ARMORY_HOME:-${LLM_LAB_HOME:-$HOME/Repositories/llm-armory}}"
STAMP=$(date +%Y%m%d-%H%M%S)
RESULTS="$LAB/bakeoff/results"
SUMMARY="$RESULTS/$STAMP-summary.md"
mkdir -p "$RESULTS"

echo "# Bake-off $STAMP" > "$SUMMARY"
echo "- brief: $BRIEF_FILE" >> "$SUMMARY"

for preset in "$@"; do
  wt="$REPO/.claude/worktrees/bakeoff-$preset-$STAMP"
  branch="bakeoff/$preset-$STAMP"
  echo "=== $preset → $wt" >&2
  git -C "$REPO" worktree add -b "$branch" "$wt" main >/dev/null

  start=$(date +%s)
  ( cd "$wt" && llm "$preset" -p "$(cat "$BRIEF_FILE")" --permission-mode acceptEdits ) \
      > "$RESULTS/$STAMP-$preset.log" 2>&1 || echo "(exit nonzero)" >> "$SUMMARY"
  dur=$(( $(date +%s) - start ))

  commits=$(git -C "$wt" log --oneline main..HEAD | wc -l)
  {
    echo "## $preset"
    echo "- duration: ${dur}s   commits: $commits   worktree: $wt"
    echo "- log: results/$STAMP-$preset.log"
    git -C "$wt" log --format='- %h %s%n  %(trailers:key=Executed-By,valueonly)' main..HEAD
  } >> "$SUMMARY"
done

echo "Summary: $SUMMARY" >&2
