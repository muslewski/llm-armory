#!/usr/bin/env bash
# Self-contained test suite for bin/llm. No network, no real claude.
set -uo pipefail
cd "$(dirname "$0")/.."
LLM="$PWD/bin/llm"

# --- fixture lab home ---
export LLM_ARMORY_HOME="$(mktemp -d)"
export LLM_LAB_HOME="$LLM_ARMORY_HOME"  # compat for old references
trap 'rm -rf "$LLM_ARMORY_HOME"' EXIT
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

# --- fake claude on PATH ---
FAKEBIN="$(mktemp -d)"
cat > "$FAKEBIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "CLAUDE_ARGS:$*"
echo "CLAUDE_URL:${ANTHROPIC_BASE_URL:-none}"
echo "CLAUDE_MODEL:${ANTHROPIC_MODEL:-none}"
EOF
chmod +x "$FAKEBIN/claude"
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
export GROK_EFFORT=xhigh
export ANTHROPIC_MODEL=grok-fixture
EOF

cat > "$LLM_ARMORY_HOME/presets/clifixture.env" <<'EOF'
export LLM_PRESET=clifixture
export ANTHROPIC_MODEL=cli-fixture
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
pollute() { LLM_GROK=1 LLM_PRESET=grokfixture GROK_EFFORT=xhigh "$@"; }
poll_list=$(pollute "$LLM" --list 2>/dev/null)
check "polluted --list still lists clifixture" grep -q '^clifixture' <<<"$poll_list"
check "polluted --list clifixture not misclassified grok" sh -c '! grep -q "^clifixture.*grok-build" <<<"$1"' _ "$poll_list"
check "polluted --list grokfixture classified as grok" grep -q '^grokfixture.*grok-build' <<<"$poll_list"
poll_dry=$(pollute "$LLM" --dry-run clifixture 2>/dev/null)
check "polluted parent + clifixture dry-run has correct model" grep -q 'ANTHROPIC_MODEL=cli-fixture' <<<"$poll_dry"
check "polluted parent + clifixture dry-run not grok"  sh -c '! grep -q "grok-build" <<<"$1"' _ "$poll_dry"
clean_grok_dry=$("$LLM" --dry-run grokfixture 2>/dev/null)
check "clean parent + grokfixture dry-run shows grok" grep -q 'grok-build (effort=xhigh)' <<<"$clean_grok_dry"

echo "----"
echo "passed=$pass failed=$fail"
test "$fail" -eq 0
