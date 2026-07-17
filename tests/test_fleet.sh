#!/usr/bin/env bash
# Fleet verb suite for bin/llm. No network, no real claude/grok.
set -uo pipefail
cd "$(dirname "$0")/.."
LLM="$PWD/bin/llm"

# --- fixture lab home ---
export LLM_ARMORY_HOME="$(mktemp -d)"
export LLM_LAB_HOME="$LLM_ARMORY_HOME"
export LLM_SKIP_PREFLIGHT=1
export AGENT_STATUS_DIR=/dev/null

REPO="$(mktemp -d)"
MANIFEST_DIR="$(mktemp -d)"
trap 'rm -rf "$LLM_ARMORY_HOME" "$REPO" "$MANIFEST_DIR"' EXIT

mkdir -p "$LLM_ARMORY_HOME/presets"
cat >"$LLM_ARMORY_HOME/presets/test.env" <<'EOF'
export LLM_PRESET=test
export ANTHROPIC_BASE_URL=https://example.test/anthropic
export ANTHROPIC_AUTH_TOKEN=sk-fixture-token-123456
export ANTHROPIC_MODEL=fixture-model-pro
EOF

# Fake bins on PATH (unused when LLM_FLEET_CHILD_CMD is set, but present for safety).
FAKEBIN="$(mktemp -d)"
trap 'rm -rf "$LLM_ARMORY_HOME" "$REPO" "$MANIFEST_DIR" "$FAKEBIN"' EXIT
cat >"$FAKEBIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "CLAUDE_ARGS:$*"
exit 0
EOF
cat >"$FAKEBIN/grok" <<'EOF'
#!/usr/bin/env bash
echo "GROK_ARGS:$*"
exit 0
EOF
chmod +x "$FAKEBIN/claude" "$FAKEBIN/grok"
export PATH="$FAKEBIN:$PATH"

# Scratch git repo for worktrees.
git -C "$REPO" init -q
printf '.claude/worktrees/\nPROGRESS.md\n' >"$REPO/.gitignore"
git -C "$REPO" add .gitignore
git -C "$REPO" commit -qm init
git -C "$REPO" branch -M main 2>/dev/null || true

mkdir -p "$MANIFEST_DIR/prompts"
echo 'prompt for alpha child — do the alpha work' >"$MANIFEST_DIR/prompts/alpha.md"
echo 'prompt for beta child — do the beta work' >"$MANIFEST_DIR/prompts/beta.md"
echo 'prompt for gamma' >"$MANIFEST_DIR/prompts/gamma.md"

pass=0; fail=0
check() {
  local desc=$1; shift
  if "$@" >/dev/null 2>&1; then pass=$((pass + 1)); echo "ok   - $desc"
  else fail=$((fail + 1)); echo "FAIL - $desc"; fi
}

# ---------------------------------------------------------------------------
# 1. Manifest parsing: comments, blanks, missing prompt, dup name, unsafe name
# ---------------------------------------------------------------------------
cat >"$MANIFEST_DIR/manifest-parse.txt" <<EOF
# leading comment

alpha|prompts/alpha.md

# mid comment
beta|prompts/beta.md
badname|prompts/missing-nope.md
alpha|prompts/alpha.md
../evil|prompts/alpha.md
gamma|prompts/gamma.md
EOF

parse_err=$(mktemp)
parse_out=$("$LLM" fleet test --manifest "$MANIFEST_DIR/manifest-parse.txt" --cwd "$REPO" \
  --max-parallel 5 --stagger 0 \
  --dry-run 2>"$parse_err"); parse_rc=$?
# dry-run still parses and prints all names that passed validation — but wait,
# dry-run currently includes all names that made it into the names array.
# Missing prompt is only checked at launch time, not parse time for dry-run.
# Unsafe/dup are rejected at parse and set problems=1 — but dry-run exits 0
# before checking problems! That may be wrong for unsafe/dup.
# Re-check implementation: dry-run happens after parse, and always exit 0.
# Spec: dry-run prints what would launch and exit 0 without touching git.
# Unsafe/dup should not appear as would-launch. Missing prompt still printed
# with "(missing prompt file)".
check "parse dry-run exits 0" test $parse_rc -eq 0
check "parse dry-run includes alpha" grep -q 'dry-run: alpha ' <<<"$parse_out"
check "parse dry-run includes beta" grep -q 'dry-run: beta ' <<<"$parse_out"
check "parse dry-run includes gamma" grep -q 'dry-run: gamma ' <<<"$parse_out"
check "parse dry-run omits unsafe name" sh -c '! grep -q "evil" <<<"$1"' _ "$parse_out"
check "parse dry-run omits duplicate second alpha as extra line" \
  test "$(grep -c 'dry-run: alpha ' <<<"$parse_out" || true)" -eq 1
check "parse dry-run notes missing prompt for badname" \
  grep -q 'badname' <<<"$parse_out" && grep -q 'missing prompt file' <<<"$parse_out"
check "parse stderr flags unsafe name" grep -q "unsafe child name" "$parse_err"
check "parse stderr flags duplicate" grep -q "duplicate child name 'alpha'" "$parse_err"

# Real launch: missing prompt LOUD skip + nonzero; safe children still launch.
export LLM_FLEET_CHILD_CMD='echo RESULT: ok — commits: 0 — fixture; exit 0'
launch_err=$(mktemp)
"$LLM" fleet test --manifest "$MANIFEST_DIR/manifest-parse.txt" --cwd "$REPO" \
  --max-parallel 5 --stagger 0 2>"$launch_err" >/tmp/fleet-launch-out.$$
launch_rc=$?
check "launch with bad rows exits nonzero" test $launch_rc -ne 0
check "launch skips missing prompt loudly" grep -q 'SKIP badname' "$launch_err"
check "launch refuses unsafe at parse (no worktree)" \
  test ! -e "$REPO/.claude/worktrees/../evil"
check "launch created alpha worktree" test -f "$REPO/.claude/worktrees/alpha/.git"
check "launch created beta worktree" test -f "$REPO/.claude/worktrees/beta/.git"
check "launch created gamma worktree" test -f "$REPO/.claude/worktrees/gamma/.git"

# Wait for children to finish writing .child-exit
for n in alpha beta gamma; do
  for _ in $(seq 1 100); do
    [[ -f "$REPO/.claude/worktrees/$n/.child-exit" ]] && break
    sleep 0.05
  done
done
check "alpha child wrote exit file" test -f "$REPO/.claude/worktrees/alpha/.child-exit"
check "alpha child wrote out log" test -f "$REPO/.claude/worktrees/alpha/.child-out.log"

# ---------------------------------------------------------------------------
# 2. --dry-run never touches git / creates no worktrees on clean repo
# ---------------------------------------------------------------------------
REPO2="$(mktemp -d)"
git -C "$REPO2" init -q
git -C "$REPO2" commit -q --allow-empty -m init
git -C "$REPO2" branch -M main 2>/dev/null || true
cat >"$MANIFEST_DIR/dry.txt" <<EOF
only|prompts/alpha.md
EOF
"$LLM" fleet test --manifest "$MANIFEST_DIR/dry.txt" --cwd "$REPO2" --dry-run >/dev/null 2>&1
check "dry-run creates no worktrees dir children" \
  sh -c '[[ ! -d "$1/.claude/worktrees/only" ]]' _ "$REPO2"
rm -rf "$REPO2"

# ---------------------------------------------------------------------------
# 3. Worktree-exists refusal (no silent reuse)
# ---------------------------------------------------------------------------
# alpha already exists from section 1
cat >"$MANIFEST_DIR/refuse.txt" <<EOF
alpha|prompts/alpha.md
fresh|prompts/beta.md
EOF
refuse_err=$(mktemp)
"$LLM" fleet test --manifest "$MANIFEST_DIR/refuse.txt" --cwd "$REPO" \
  --max-parallel 5 --stagger 0 2>"$refuse_err" >/dev/null
refuse_rc=$?
check "exists refusal exits nonzero" test $refuse_rc -ne 0
check "exists refusal is LOUD" grep -q 'REFUSE alpha' "$refuse_err"
check "exists refusal still launches fresh" test -f "$REPO/.claude/worktrees/fresh/.git"
for _ in $(seq 1 100); do
  [[ -f "$REPO/.claude/worktrees/fresh/.child-exit" ]] && break
  sleep 0.05
done

# ---------------------------------------------------------------------------
# 4. fleet-status states: running / exit / stalled via fixture files
# ---------------------------------------------------------------------------
STAT="$(mktemp -d)"
git -C "$STAT" init -q
git -C "$STAT" commit -q --allow-empty -m init
git -C "$STAT" branch -M main 2>/dev/null || true
mkdir -p "$STAT/.claude/worktrees/runme" "$STAT/.claude/worktrees/done" "$STAT/.claude/worktrees/stuck"

# running: live sleep pid, no exit
(sleep 30) &
run_pid=$!
echo "$run_pid" >"$STAT/.claude/worktrees/runme/.child-pid"
: >"$STAT/.claude/worktrees/runme/.child-out.log"
echo 'task 1: done — running fixture' >"$STAT/.claude/worktrees/runme/PROGRESS.md"

# exit=7
echo 7 >"$STAT/.claude/worktrees/done/.child-exit"
echo 1 >"$STAT/.claude/worktrees/done/.child-pid"
: >"$STAT/.claude/worktrees/done/.child-out.log"
echo 'RESULT: failed — commits: 0 — boom' >"$STAT/.claude/worktrees/done/.child-out.log"

# stalled: dead pid, no exit
echo 999999 >"$STAT/.claude/worktrees/stuck/.child-pid"
: >"$STAT/.claude/worktrees/stuck/.child-out.log"

status_out=$("$LLM" fleet-status --cwd "$STAT" 2>/dev/null); status_rc=$?
check "fleet-status always exits 0" test $status_rc -eq 0
check "fleet-status shows running" grep -qE 'runme \| running\(pid '"$run_pid"'\)' <<<"$status_out"
check "fleet-status shows exit" grep -qE 'done \| exit=7' <<<"$status_out"
check "fleet-status shows stalled" grep -qE 'stuck \| stalled\?' <<<"$status_out"
check "fleet-status includes PROGRESS line" grep -q 'task 1: done' <<<"$status_out"
kill "$run_pid" 2>/dev/null || true
wait "$run_pid" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 5. fleet-report: ok / failed / missing RESULT + exit codes
# ---------------------------------------------------------------------------
REP="$(mktemp -d)"
git -C "$REP" init -q
git -C "$REP" commit -q --allow-empty -m init
git -C "$REP" branch -M main 2>/dev/null || true
mkdir -p "$REP/.claude/worktrees/"{okkid,badkid,misskid}

echo 0 >"$REP/.claude/worktrees/okkid/.child-exit"
printf 'noise\nRESULT: ok — commits: 1 — done\n' >"$REP/.claude/worktrees/okkid/.child-out.log"

echo 0 >"$REP/.claude/worktrees/badkid/.child-exit"
printf 'RESULT: failed — commits: 0 — nope\n' >"$REP/.claude/worktrees/badkid/.child-out.log"

echo 1 >"$REP/.claude/worktrees/misskid/.child-exit"
printf 'no result line here\n' >"$REP/.claude/worktrees/misskid/.child-out.log"

report_out=$("$LLM" fleet-report --cwd "$REP" 2>/dev/null); report_rc=$?
check "fleet-report exits 1 when any bad" test $report_rc -ne 0
check "fleet-report summary counts" grep -q 'fleet: 1 ok · 2 bad of 3' <<<"$report_out"
check "fleet-report shows ok RESULT" grep -q 'okkid | exit=0' <<<"$report_out"
check "fleet-report shows failed RESULT" grep -q 'RESULT: failed' <<<"$report_out"
check "fleet-report shows missing RESULT" grep -q 'RESULT: (missing)' <<<"$report_out"

# all-ok fleet-report exits 0
ALLOK="$(mktemp -d)"
git -C "$ALLOK" init -q
git -C "$ALLOK" commit -q --allow-empty -m init
mkdir -p "$ALLOK/.claude/worktrees/solo"
echo 0 >"$ALLOK/.claude/worktrees/solo/.child-exit"
echo 'RESULT: ok — commits: 0 — fine' >"$ALLOK/.claude/worktrees/solo/.child-out.log"
all_out=$("$LLM" fleet-report --cwd "$ALLOK" 2>/dev/null); all_rc=$?
check "fleet-report all-ok exits 0" test $all_rc -eq 0
check "fleet-report all-ok summary" grep -q 'fleet: 1 ok · 0 bad of 1' <<<"$all_out"
rm -rf "$ALLOK" "$REP" "$STAT"

# ---------------------------------------------------------------------------
# 6. max-parallel gating (fake sleeping children; never > N alive)
# ---------------------------------------------------------------------------
PAR="$(mktemp -d)"
git -C "$PAR" init -q
printf '.claude/worktrees/\n' >"$PAR/.gitignore"
git -C "$PAR" add .gitignore
git -C "$PAR" commit -qm init
git -C "$PAR" branch -M main 2>/dev/null || true

mkdir -p "$MANIFEST_DIR/parprompts"
for i in 1 2 3 4; do
  echo "p$i work" >"$MANIFEST_DIR/parprompts/p$i.md"
done
cat >"$MANIFEST_DIR/par.txt" <<EOF
p1|parprompts/p1.md
p2|parprompts/p2.md
p3|parprompts/p3.md
p4|parprompts/p4.md
EOF

# Children sleep ~1.5s so the launcher must gate; timing is generous.
export LLM_FLEET_CHILD_CMD='sleep 1.5; echo RESULT: ok — commits: 0 — sleeper; exit 0'

# Background monitor: sample alive .child-pid count every 0.1s
mon_log=$(mktemp)
(
  max_seen=0
  for _ in $(seq 1 200); do
    alive=0
    for n in p1 p2 p3 p4; do
      wt="$PAR/.claude/worktrees/$n"
      [[ -f "$wt/.child-pid" && ! -f "$wt/.child-exit" ]] || continue
      pid=$(tr -d '[:space:]' <"$wt/.child-pid" 2>/dev/null || true)
      [[ -n "$pid" ]] || continue
      if kill -0 "$pid" 2>/dev/null; then
        alive=$((alive + 1))
      fi
    done
    if (( alive > max_seen )); then max_seen=$alive; fi
    # stop early once all four have exit files
    done_n=0
    for n in p1 p2 p3 p4; do
      [[ -f "$PAR/.claude/worktrees/$n/.child-exit" ]] && done_n=$((done_n + 1))
    done
    if (( done_n == 4 )); then
      echo "$max_seen" >"$mon_log"
      exit 0
    fi
    sleep 0.1
  done
  echo "$max_seen" >"$mon_log"
) &
mon_pid=$!

"$LLM" fleet test --manifest "$MANIFEST_DIR/par.txt" --cwd "$PAR" \
  --max-parallel 2 --stagger 0 >/dev/null 2>"$LLM_ARMORY_HOME/par.err"
par_rc=$?
check "max-parallel fleet launch exits 0" test $par_rc -eq 0

# Wait for monitor (children may still be finishing after launch returns)
wait "$mon_pid" 2>/dev/null || true
# Also wait for any stragglers
for n in p1 p2 p3 p4; do
  for _ in $(seq 1 80); do
    [[ -f "$PAR/.claude/worktrees/$n/.child-exit" ]] && break
    sleep 0.1
  done
done

max_seen=$(cat "$mon_log" 2>/dev/null || echo 99)
check "max-parallel never exceeded 2 alive" test "$max_seen" -le 2
check "max-parallel actually ran some concurrency or serial" test "$max_seen" -ge 1
check "max-parallel all four finished" \
  test -f "$PAR/.claude/worktrees/p1/.child-exit" \
  -a -f "$PAR/.claude/worktrees/p2/.child-exit" \
  -a -f "$PAR/.claude/worktrees/p3/.child-exit" \
  -a -f "$PAR/.claude/worktrees/p4/.child-exit"

# Seed copy
SEED_SRC=$(mktemp)
echo 'SECRET=fixture' >"$SEED_SRC"
cat >"$MANIFEST_DIR/seed.txt" <<EOF
seeded|prompts/alpha.md
EOF
SEED_REPO="$(mktemp -d)"
git -C "$SEED_REPO" init -q
git -C "$SEED_REPO" commit -q --allow-empty -m init
export LLM_FLEET_CHILD_CMD='echo RESULT: ok — commits: 0 — seeded; exit 0'
"$LLM" fleet test --manifest "$MANIFEST_DIR/seed.txt" --cwd "$SEED_REPO" \
  --seed "$SEED_SRC" --stagger 0 --max-parallel 1 >/dev/null 2>&1
check "seed file copied into worktree" \
  grep -q 'SECRET=fixture' "$SEED_REPO/.claude/worktrees/seeded/$(basename "$SEED_SRC")"

rm -rf "$PAR" "$SEED_REPO" "$SEED_SRC"

# ---------------------------------------------------------------------------
# 7. Help lists fleet verbs
# ---------------------------------------------------------------------------
help_out=$("$LLM" --help 2>&1)
check "help mentions fleet" grep -q 'fleet <loadout>' <<<"$help_out"
check "help mentions fleet-status" grep -q 'fleet-status' <<<"$help_out"
check "help mentions fleet-report" grep -q 'fleet-report' <<<"$help_out"

echo "----"
echo "passed=$pass failed=$fail"
test "$fail" -eq 0
