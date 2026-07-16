#!/usr/bin/env bash
# Self-contained test suite for bin/llm. No network, no real claude.
set -uo pipefail
cd "$(dirname "$0")/.."
LLM="$PWD/bin/llm"

# --- fixture lab home ---
export LLM_ARMORY_HOME="$(mktemp -d)"
export LLM_LAB_HOME="$LLM_ARMORY_HOME"  # compat for old references
# as_base is created later for agent-status tests; expanded empty until then.
as_base=""
trap 'rm -rf "$LLM_ARMORY_HOME" ${as_base:+"$as_base"}' EXIT
mkdir -p "$LLM_ARMORY_HOME/presets/providers"

cat > "$LLM_ARMORY_HOME/presets/test.env" <<'EOF'
export LLM_PRESET=test
export ANTHROPIC_BASE_URL=https://example.test/anthropic
export ANTHROPIC_AUTH_TOKEN=sk-fixture-token-123456
export ANTHROPIC_MODEL=fixture-model-pro
export API_TIMEOUT_MS=600000
EOF

cat > "$LLM_ARMORY_HOME/presets/nokey.env" <<'EOF'
export LLM_PRESET=nokey
export ANTHROPIC_BASE_URL=https://example.test/anthropic
EOF

cat > "$LLM_ARMORY_HOME/presets/native.env" <<'EOF'
export LLM_PRESET=native
EOF

cat > "$LLM_ARMORY_HOME/presets/needsprovider.env" <<'EOF'
export LLM_PRESET=needsprovider
export LLM_REQUIRES_CREDENTIAL=1
[[ -f "$PRESETS_DIR/providers/nope.env" ]] && source "$PRESETS_DIR/providers/nope.env"
export ANTHROPIC_MODEL=some-remote-model
EOF

# --- fake claude + grok on PATH ---
FAKEBIN="$(mktemp -d)"
cat > "$FAKEBIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "CLAUDE_ARGS:$*"
echo "CLAUDE_URL:${ANTHROPIC_BASE_URL:-none}"
echo "CLAUDE_MODEL:${ANTHROPIC_MODEL:-none}"
echo "CLAUDE_PID:$$"
EOF
chmod +x "$FAKEBIN/claude"
cat > "$FAKEBIN/grok" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  echo "grok 0.0.0-fixture"
  exit 0
fi
echo "GROK_ARGS:$*"
echo "GROK_MODEL:${GROK_MODEL:-none}"
echo "GROK_EFFORT:${GROK_EFFORT:-none}"
echo "GROK_PID:$$"
EOF
chmod +x "$FAKEBIN/grok"
export PATH="$FAKEBIN:$PATH"

# Fixture URLs are fake — skip the pool preflight globally; section 7 tests it
# explicitly against a dead local port.
export LLM_SKIP_PREFLIGHT=1

# Executor hooks fixture: bin/llm looks for hooks/ under LLM_ARMORY_HOME.
mkdir -p "$LLM_ARMORY_HOME/hooks"
cp "$PWD/hooks/executor-settings.json" "$LLM_ARMORY_HOME/hooks/"

cat > "$LLM_ARMORY_HOME/presets/executor.env" <<'EOF'
export LLM_PRESET=executor
export ANTHROPIC_BASE_URL=https://example.test/anthropic
export ANTHROPIC_AUTH_TOKEN=sk-fixture-token-123456
export ANTHROPIC_MODEL=fixture-model-pro
export LLM_SYSTEM_APPEND='persist until done'
export LLM_EXECUTOR_HOOKS=1
EOF

cat > "$LLM_ARMORY_HOME/presets/deadpool.env" <<'EOF'
export LLM_PRESET=deadpool
export ANTHROPIC_BASE_URL=http://127.0.0.1:9
export ANTHROPIC_AUTH_TOKEN=sk-fixture-token-123456
export ANTHROPIC_MODEL=fixture-model-pro
EOF

# Fixtures specifically for parent-pollution tests (one pretending to be grok lane, one clean)
cat > "$LLM_ARMORY_HOME/presets/grokfixture.env" <<'EOF'
export LLM_PRESET=grokfixture
export LLM_GROK=1
export GROK_EFFORT=high
export ANTHROPIC_MODEL=grok-fixture
EOF

cat > "$LLM_ARMORY_HOME/presets/clifixture.env" <<'EOF'
export LLM_PRESET=clifixture
export ANTHROPIC_MODEL=cli-fixture
EOF

# grok-high fixture for agent-status launch-record tests (mirrors real pin)
cat > "$LLM_ARMORY_HOME/presets/grok-high.env" <<'EOF'
export LLM_PRESET=grok-high
export LLM_GROK=1
export GROK_MODEL=grok-4.5
export GROK_EFFORT=high
EOF

pass=0; fail=0
check() {  # check <description> <command...>  (command must exit 0)
  local desc=$1; shift
  if "$@" >/dev/null 2>&1; then pass=$((pass+1)); echo "ok   - $desc"
  else fail=$((fail+1)); echo "FAIL - $desc"; fi
}

# 1. --list exits 0 and shows all fixture presets
out=$("$LLM" --list 2>/dev/null)
check "--list exits 0" test $? -eq 0
check "--list shows test preset"   grep -q '^test'   <<<"$out"
check "--list shows native preset" grep -q '^native' <<<"$out"

# 2. --dry-run resolves env and masks the token
dry=$("$LLM" --dry-run test 2>/dev/null)
check "dry-run shows base url"   grep -q 'ANTHROPIC_BASE_URL=https://example.test/anthropic' <<<"$dry"
check "dry-run shows model"      grep -q 'ANTHROPIC_MODEL=fixture-model-pro' <<<"$dry"
check "dry-run masks token"      grep -q 'sk-fix.*masked' <<<"$dry"
if grep -q 'sk-fixture-token-123456' <<<"$dry"; then
  fail=$((fail+1)); echo "FAIL - dry-run must not print full token"
else
  pass=$((pass+1)); echo "ok   - dry-run does not leak full token"
fi

# 3. unknown preset → exit 1 + stderr message
"$LLM" doesnotexist >/dev/null 2>"$LLM_ARMORY_HOME/err" ; rc=$?
check "unknown preset exits 1" test $rc -eq 1
check "unknown preset names problem" grep -q "armory: unknown loadout 'doesnotexist'" "$LLM_ARMORY_HOME/err"

# 4. remote endpoint without credential → exit 1
"$LLM" nokey >/dev/null 2>"$LLM_ARMORY_HOME/err2" ; rc=$?
check "missing key exits 1" test $rc -eq 1
check "missing key explains fix" grep -q 'ANTHROPIC_AUTH_TOKEN' "$LLM_ARMORY_HOME/err2"

# remote preset whose provider file is missing → must refuse (not fall back to Max)
"$LLM" needsprovider >/dev/null 2>"$LLM_ARMORY_HOME/err4" ; rc=$?
check "missing provider file exits 1" test $rc -eq 1
check "missing provider explains fix" grep -q 'needs provider credentials' "$LLM_ARMORY_HOME/err4"

# 5. launch path: args pass through, env applied, banner on stderr only
run_out=$("$LLM" test -p hello 2>"$LLM_ARMORY_HOME/err3")
check "claude receives args"  grep -q 'CLAUDE_ARGS:-p hello' <<<"$run_out"
check "claude sees preset url" grep -q 'CLAUDE_URL:https://example.test/anthropic' <<<"$run_out"
check "banner on stderr"       grep -q '▶ executor: fixture-model-pro @ https://example.test/anthropic (loadout: test)' "$LLM_ARMORY_HOME/err3"
if grep -q '▶ executor' <<<"$run_out"; then
  fail=$((fail+1)); echo "FAIL - banner leaked to stdout"
else
  pass=$((pass+1)); echo "ok   - banner not on stdout"
fi

# 6. native preset: no url override, no credential demanded
nat=$("$LLM" native -p hi 2>/dev/null)
check "native has no url override" grep -q 'CLAUDE_URL:none' <<<"$nat"

# 7. preflight: dead pool refuses to launch; LLM_SKIP_PREFLIGHT bypasses
env -u LLM_SKIP_PREFLIGHT "$LLM" deadpool -p hi >/dev/null 2>"$LLM_ARMORY_HOME/err5"; rc=$?
check "dead pool exits nonzero" test $rc -ne 0
check "dead pool names preflight" grep -q 'preflight FAILED' "$LLM_ARMORY_HOME/err5"
skip_out=$("$LLM" deadpool -p hi 2>/dev/null)
check "skip-preflight launches" grep -q 'CLAUDE_ARGS:-p hi' <<<"$skip_out"

# 8. executor preset: system append + hooks settings injected, in order
exe=$("$LLM" executor -p go 2>/dev/null)
check "executor passes system append" grep -q -- '--append-system-prompt persist until done' <<<"$exe"
check "executor passes hooks settings" grep -q -- "--settings $LLM_ARMORY_HOME/hooks/executor-settings.json" <<<"$exe"
check "executor keeps user args last" grep -q -- '-p go$' <<<"$exe"
dry2=$("$LLM" --dry-run executor 2>/dev/null)
check "dry-run shows executor hooks flag" grep -q 'LLM_EXECUTOR_HOOKS=1' <<<"$dry2"

# 9. post-edit-check hook: catches bake-off failure modes, passes clean code
if command -v bun >/dev/null 2>&1; then
  HOOK="$PWD/hooks/post-edit-check.mjs"
  FIX="$(mktemp -d)"
  mkdir -p "$FIX/src"
  printf '{"compilerOptions": {"paths": {"@/*": ["./src/*"]}}}' > "$FIX/tsconfig.json"
  printf 'export const realThing = 1;\nexport const { destructured } = {destructured: 2};\n' > "$FIX/src/lib.ts"
  printf 'import { realThing, destructured } from "./lib";\nexport const ok = realThing + destructured;\n' > "$FIX/src/good.ts"
  printf 'We need to import the data and then find it.\nexport const x = 1;\n' > "$FIX/src/prose.ts"
  printf 'import { ghost } from "./lib";\nimport { thing } from "@/missing/module";\nexport const y = [ghost, thing];\n' > "$FIX/src/phantom.ts"
  printf 'export const z = 1;\n<tool_call><function=Edit\n' > "$FIX/src/garbage.ts"
  hookrc() { printf '{"tool_input":{"file_path":"%s"}}' "$1" | "$HOOK" >/dev/null 2>&1; echo $?; }
  check "hook passes clean file"        test "$(hookrc "$FIX/src/good.ts")" -eq 0
  check "hook blocks deliberation prose" test "$(hookrc "$FIX/src/prose.ts")" -eq 2
  check "hook blocks phantom imports"    test "$(hookrc "$FIX/src/phantom.ts")" -eq 2
  check "hook blocks tool-call garbage"  test "$(hookrc "$FIX/src/garbage.ts")" -eq 2
  rm -rf "$FIX"
else
  echo "skip - bun not found; post-edit-check tests skipped"
fi

# 10. stop-gate hook: blocks first stop on dirty tree, never loops, ignores PROGRESS.md
GATE="$PWD/hooks/stop-gate.sh"
GT="$(mktemp -d)"
git -C "$GT" init -q && git -C "$GT" commit -q --allow-empty -m init
gate() { printf '{"cwd":"%s","stop_hook_active":%s}' "$GT" "$2" | "$GATE"; }
check "gate silent on clean tree"    test -z "$(gate "$GT" false)"
echo dirty > "$GT/f.txt"
gout=$(gate "$GT" false)
check "gate blocks dirty tree"       grep -q '"decision": "block"' <<<"$gout"
check "gate emits valid json" python3 -c 'import json,sys; json.loads(sys.stdin.read())' <<<"$gout"
check "gate allows second stop"      test -z "$(gate "$GT" true)"
git -C "$GT" add f.txt && git -C "$GT" commit -qm t && echo scratch > "$GT/PROGRESS.md"
check "gate ignores PROGRESS.md"     test -z "$(gate "$GT" false)"
rm -rf "$GT"

# 11. parent loadout pollution resistance (using local test fixtures):
#     Parent claiming to be a "grok" loadout must not cause listing or
#     dry-run of a non-grok fixture to be misclassified or mis-resolved.
pollute() { LLM_GROK=1 LLM_PRESET=grokfixture GROK_EFFORT=high "$@"; }
poll_list=$(pollute "$LLM" --list 2>/dev/null)
check "polluted --list still lists clifixture" grep -q '^clifixture' <<<"$poll_list"
check "polluted --list clifixture not misclassified grok" sh -c '! grep -q "^clifixture.*grok-build" <<<"$1"' _ "$poll_list"
check "polluted --list grokfixture classified as grok" grep -qE '^grokfixture.*(grok-4\.5|grok-build)' <<<"$poll_list"
poll_dry=$(pollute "$LLM" --dry-run clifixture 2>/dev/null)
check "polluted parent + clifixture dry-run has correct model" grep -q 'ANTHROPIC_MODEL=cli-fixture' <<<"$poll_dry"
check "polluted parent + clifixture dry-run not grok"  sh -c '! grep -q "grok-build" <<<"$1"' _ "$poll_dry"
clean_grok_dry=$("$LLM" --dry-run grokfixture 2>/dev/null)
check "clean parent + grokfixture dry-run shows grok" grep -qE 'grok-(4\.5|build) \(effort=high\)' <<<"$clean_grok_dry"

# 12. Agent Status Provider launch records (schema 1)
#     Soft-fail law: unwritable status dir must never break launch.
#     Records use pid-key fallback; fake child prints GROK_PID/CLAUDE_PID.
as_base="$(mktemp -d)"

export AGENT_STATUS_DIR="$as_base/as1"
mkdir -p "$AGENT_STATUS_DIR"
grok_out=$("$LLM" grok-high -p noop 2>/dev/null)
child_pid=$(grep -oE 'GROK_PID:[0-9]+' <<<"$grok_out" | head -1 | cut -d: -f2)
rec="$AGENT_STATUS_DIR/sessions/grok-pid${child_pid}.json"
check "launch writes session record" test -f "$rec"
check "session record is valid JSON" python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$rec"
check "session record written_by" grep -q '"written_by": "llm-armory"' "$rec"
check "session record model pin" grep -q '"model": "grok-4.5"' "$rec"
check "session record preset" grep -q '"preset": "grok-high"' "$rec"
check "session record source_cli" grep -q '"source_cli": "grok"' "$rec"
check "session record ttl_ms" grep -q '"ttl_ms": 43200000' "$rec"
hb="$AGENT_STATUS_DIR/providers/llm-armory.json"
check "launch writes provider heartbeat" test -f "$hb"
check "heartbeat is valid JSON" python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$hb"
check "heartbeat tool name" grep -q '"tool": "llm-armory"' "$hb"
check "heartbeat capabilities" grep -q '"capabilities": \["launch"\]' "$hb"

# soft-fail: unwritable status dir must not break launch
export AGENT_STATUS_DIR="$as_base/ro"
mkdir -p "$AGENT_STATUS_DIR"
chmod 000 "$AGENT_STATUS_DIR"
soft_out=$("$LLM" grok-high -p noop 2>/dev/null); soft_rc=$?
chmod 755 "$AGENT_STATUS_DIR" 2>/dev/null || true
check "soft-fail: launch survives unwritable status dir" test $soft_rc -eq 0
check "soft-fail: fake grok still ran" grep -q 'GROK_ARGS:' <<<"$soft_out"

# worktree + parent_session fields
export AGENT_STATUS_DIR="$as_base/as2"
mkdir -p "$AGENT_STATUS_DIR"
export SAGE_PARENT="parent-1"
wt_out=$(SAGE_PARENT=parent-1 "$LLM" grok-high -w my-feature -p noop 2>/dev/null)
wt_pid=$(grep -oE 'GROK_PID:[0-9]+' <<<"$wt_out" | head -1 | cut -d: -f2)
wt_rec="$AGENT_STATUS_DIR/sessions/grok-pid${wt_pid}.json"
check "record includes worktree" grep -q '"worktree": "my-feature"' "$wt_rec"
check "record includes parent_session" grep -q '"parent_session": "parent-1"' "$wt_rec"
unset SAGE_PARENT

# json escaping: cwd with quotes/spaces survives python3 -m json.tool
export AGENT_STATUS_DIR="$as_base/as3"
mkdir -p "$AGENT_STATUS_DIR"
esc_cwd="$as_base/path with \"quotes\" and spaces"
mkdir -p "$esc_cwd"
esc_out=$(cd "$esc_cwd" && "$LLM" grok-high -p noop 2>/dev/null)
esc_pid=$(grep -oE 'GROK_PID:[0-9]+' <<<"$esc_out" | head -1 | cut -d: -f2)
esc_rec="$AGENT_STATUS_DIR/sessions/grok-pid${esc_pid}.json"
check "escaped cwd record exists" test -f "$esc_rec"
check "escaped cwd is valid JSON" python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$esc_rec"
check "escaped cwd preserves path substance" python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
assert 'quotes' in d['cwd'] and 'spaces' in d['cwd'], d['cwd']
" "$esc_rec"

# claude path also writes a record
export AGENT_STATUS_DIR="$as_base/as4"
mkdir -p "$AGENT_STATUS_DIR"
cli_out=$("$LLM" test -p hello 2>/dev/null)
cli_pid=$(grep -oE 'CLAUDE_PID:[0-9]+' <<<"$cli_out" | head -1 | cut -d: -f2)
cli_rec="$AGENT_STATUS_DIR/sessions/claude-pid${cli_pid}.json"
check "claude launch writes session record" test -f "$cli_rec"
check "claude record source_cli" grep -q '"source_cli": "claude"' "$cli_rec"
check "claude record model" grep -q '"model": "fixture-model-pro"' "$cli_rec"

unset AGENT_STATUS_DIR

echo "----"
echo "passed=$pass failed=$fail"
test "$fail" -eq 0
