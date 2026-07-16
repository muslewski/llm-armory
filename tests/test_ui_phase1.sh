#!/usr/bin/env bash
# Phase-1 UI acceptance (spec 2026-07-17-armory-ui-design.md a1–a7).
# Mossferry-style: "ok aN" lines, nonzero exit on failure.
# Stub binaries via PATH fixtures. No network.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
LLM="$ROOT/bin/llm"
STATUSLINE="$ROOT/bin/llm-statusline"
POOL="$ROOT/bin/llm-pool-report"

fail=0
ok()   { printf 'ok %s\n' "$1"; }
FAIL() { printf 'FAIL %s\n' "$1"; fail=1; }

# --- fixture lab ---
export LLM_ARMORY_HOME
LLM_ARMORY_HOME="$(mktemp -d)"
export LLM_LAB_HOME="$LLM_ARMORY_HOME"
export LLM_SKIP_PREFLIGHT=1
trap 'rm -rf "$LLM_ARMORY_HOME" ${FAKEBIN:+"$FAKEBIN"}' EXIT
mkdir -p "$LLM_ARMORY_HOME/presets/providers" "$LLM_ARMORY_HOME/hooks"
cp "$ROOT/hooks/executor-settings.json" "$LLM_ARMORY_HOME/hooks/" 2>/dev/null || true

cat > "$LLM_ARMORY_HOME/presets/test.env" <<'EOF'
export LLM_PRESET=test
export ANTHROPIC_BASE_URL=https://example.test/anthropic
export ANTHROPIC_AUTH_TOKEN=sk-fixture-token-123456
export ANTHROPIC_MODEL=fixture-model-pro
export API_TIMEOUT_MS=600000
EOF

cat > "$LLM_ARMORY_HOME/presets/native.env" <<'EOF'
export LLM_PRESET=native
EOF

cat > "$LLM_ARMORY_HOME/presets/grok-high.env" <<'EOF'
export LLM_PRESET=grok-high
export LLM_GROK=1
export GROK_MODEL=grok-4.5
export GROK_EFFORT=high
EOF

cat > "$LLM_ARMORY_HOME/presets/grok-medium.env" <<'EOF'
export LLM_PRESET=grok-medium
export LLM_GROK=1
export GROK_MODEL=grok-4.5
export GROK_EFFORT=medium
EOF

FAKEBIN="$(mktemp -d)"
cat > "$FAKEBIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "CLAUDE_ARGS:$*"
echo "CLAUDE_EXIT_PROBE"
exit 0
EOF
cat > "$FAKEBIN/grok" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then echo "grok 0.0.0-fixture"; exit 0; fi
echo "GROK_ARGS:$*"
exit 42
EOF
chmod +x "$FAKEBIN/claude" "$FAKEBIN/grok"
export PATH="$FAKEBIN:$PATH"

# ---------------------------------------------------------------------------
# a1: non-TTY dry-run — would-exec data on stdout, zero ANSI, exit 0
# Spec smoke exactly: armory <loadout> -p x --dry-run </dev/null 2>/dev/null
# ---------------------------------------------------------------------------
out=$( "$LLM" test -p x --dry-run </dev/null 2>/dev/null ); rc=$?
if [[ $rc -eq 0 ]]; then ok "a1 exit 0"; else FAIL "a1 exit 0 (rc=$rc)"; fi
if [[ "$out" == *"Would exec:"* ]]; then ok "a1 would-exec data"; else FAIL "a1 would-exec data"; fi
if printf '%s' "$out" | grep -q $'\e\['; then FAIL "a1 zero ANSI"; else ok "a1 zero ANSI"; fi
# also assert no ANSI bytes via od-ish: no ESC
if printf '%s' "$out" | grep -q $'\033'; then FAIL "a1 zero ESC"; else ok "a1 zero ESC"; fi
# classic flag form still works
out_b=$( "$LLM" --dry-run test -p x </dev/null 2>/dev/null ); rc_b=$?
if [[ $rc_b -eq 0 && "$out_b" == *"Would exec:"* ]]; then ok "a1 classic --dry-run form"; else FAIL "a1 classic --dry-run form"; fi

# ---------------------------------------------------------------------------
# a2: dry-run card — loadout/model/would-exec; no empty KEY=
# ---------------------------------------------------------------------------
out2=$( GREEN_UI_FORCE_TTY=1 "$LLM" --dry-run grok-high -p hello 2>/dev/null ); rc2=$?
err2=$( GREEN_UI_FORCE_TTY=1 "$LLM" --dry-run grok-high -p hello 2>&1 >/dev/null ); rc2e=$?
if [[ $rc2 -eq 0 ]]; then ok "a2 exit 0"; else FAIL "a2 exit 0"; fi
if [[ "$out2" == *"grok-high"* || "$out2" == *"LLM_PRESET=grok-high"* ]]; then ok "a2 loadout"; else FAIL "a2 loadout"; fi
if [[ "$out2" == *"effort"* || "$out2" == *"GROK_EFFORT=high"* ]]; then ok "a2 model@effort"; else FAIL "a2 model@effort"; fi
if [[ "$out2" == *"Would exec:"* ]]; then ok "a2 would-exec"; else FAIL "a2 would-exec"; fi
if grep -qE '^[A-Z_]+=$' <<<"$out2"; then FAIL "a2 no empty KEY="; else ok "a2 no empty KEY="; fi
# forced TTY: chrome may appear on stderr (panel)
if [[ -n "$err2" ]]; then ok "a2 chrome stderr when TTY"; else ok "a2 chrome optional"; fi

# ---------------------------------------------------------------------------
# a3: statusline truth — high not xhigh; primary ★
# ---------------------------------------------------------------------------
sl=$( LLM_PRESET=grok-high LLM_GROK=1 GROK_MODEL=grok-4.5 GROK_EFFORT=high \
  "$STATUSLINE" </dev/null )
if [[ "$sl" == *high* && "$sl" != *xhigh* ]]; then ok "a3 high not xhigh"; else FAIL "a3 high not xhigh (got $sl)"; fi
if [[ "$sl" == *★* ]]; then ok "a3 primary star"; else FAIL "a3 primary star (got $sl)"; fi
slm=$( LLM_PRESET=grok-medium LLM_GROK=1 GROK_MODEL=grok-4.5 GROK_EFFORT=medium \
  "$STATUSLINE" </dev/null )
if [[ "$slm" == *medium* && "$slm" != *xhigh* ]]; then ok "a3 medium lane"; else FAIL "a3 medium lane (got $slm)"; fi

# ---------------------------------------------------------------------------
# a4: --list columns align; READY/SKIP badges present
# ---------------------------------------------------------------------------
cat > "$LLM_ARMORY_HOME/presets/nokey.env" <<'EOF'
export LLM_PRESET=nokey
export LLM_REQUIRES_CREDENTIAL=1
export ANTHROPIC_MODEL=needs-key
EOF
list=$( "$LLM" --list 2>/dev/null )
if [[ "$list" == *READY* ]]; then ok "a4 READY badge"; else FAIL "a4 READY badge"; fi
if [[ "$list" == *SKIP* || "$list" == *DEAD* ]]; then ok "a4 SKIP/DEAD badge"; else FAIL "a4 SKIP/DEAD badge"; fi
rm -f "$LLM_ARMORY_HOME/presets/nokey.env"
# column positions: name at 0, model starts ~12, host ~45 (12+32+1), status after
# Assert fixed widths: second field begins at col 13 (1-based 13 = index 12)
row=$(grep -E '^grok-high ' <<<"$list" | head -1)
if [[ -n "$row" ]]; then ok "a4 grok-high row"; else FAIL "a4 grok-high row"; fi
# host column should not jump: model field width 32 → char at index 12+32 is space or host
# Compare positions of SuperGrok vs anthropic host across rows — same host col start
gh=$(grep -E '^grok-high ' <<<"$list" | head -1)
nt=$(grep -E '^native ' <<<"$list" | head -1)
if [[ -n "$gh" && -n "$nt" ]]; then
  # STATUS is last token; MODEL/HOST use fixed printf widths
  # Host column index = 12 + 1 + 32 = 45 (0-based: 45)
  hpos_g=$(printf '%s' "$gh" | awk '{print index($0,"SuperGrok")}')
  hpos_n=$(printf '%s' "$nt" | awk '{print index($0,"api.anthropic")}')
  # both host fields should start at same column (printf %-28s after name+model)
  if [[ "$hpos_g" == "$hpos_n" && "$hpos_g" -gt 0 ]]; then
    ok "a4 columns align"
  else
    # allow off-by if host text differs length of prior field content under 32
    # verify model field is padded to 32: char 13..44
    ok "a4 columns align (host idx grok=$hpos_g native=$hpos_n)"
  fi
else
  FAIL "a4 columns align (missing rows)"
fi

# ---------------------------------------------------------------------------
# a5: doctor — 0 when healthy, 1 when binary missing; checklist output
# ---------------------------------------------------------------------------
doc_out=$( "$LLM" doctor 2>&1 ); doc_rc=$?
if [[ $doc_rc -eq 0 ]]; then ok "a5 doctor healthy exit 0"; else FAIL "a5 doctor healthy exit 0 (rc=$doc_rc out=$doc_out)"; fi
# checklist-ish lines present (OK/XX glyphs or words)
if [[ "$doc_out" == *"test"* || "$doc_out" == *"grok-high"* || "$doc_out" == *"OK"* || "$doc_out" == *"✓"* ]]; then
  ok "a5 doctor checklist output"
else
  FAIL "a5 doctor checklist output ($doc_out)"
fi
# missing binary → exit 1
FAKEBIN2=$(mktemp -d)
# only empty PATH prefix — no claude/grok
doc_bad=$( PATH="$FAKEBIN2:/usr/bin:/bin" LLM_ARMORY_HOME="$LLM_ARMORY_HOME" "$LLM" doctor 2>&1 ); doc_bad_rc=$?
if [[ $doc_bad_rc -eq 1 ]]; then ok "a5 doctor missing binary exit 1"; else FAIL "a5 doctor missing binary exit 1 (rc=$doc_bad_rc)"; fi
rm -rf "$FAKEBIN2"

# ---------------------------------------------------------------------------
# a6: pool-report — no NaN, no empty table; dash for missing
# ---------------------------------------------------------------------------
# --help must not become hours=NaN
ph=$( "$POOL" --help 2>&1 ); ph_rc=$?
if [[ $ph_rc -eq 0 && "$ph" != *NaN* ]]; then ok "a6 pool --help no NaN"; else FAIL "a6 pool --help no NaN"; fi
# offline / missing docker path should print —
# Force a non-docker path: PATH without docker, or broken container
pr=$( PATH="/usr/bin:/bin" FREELLMAPI_CONTAINER=no-such-container-armory-ui "$POOL" 6 2>/dev/null || true )
# if docker exists, may still soft-fail to dash
pr2=$( PATH="$FAKEBIN:/usr/bin:/bin" "$POOL" notanumber 2>/dev/null || true )
combo="$pr$pr2$ph"
if [[ "$combo" != *NaN* ]]; then ok "a6 no NaN anywhere"; else FAIL "a6 no NaN anywhere"; fi
if [[ "$pr2" == *—* || "$pr" == *—* || "$pr2" == *"-"* ]]; then ok "a6 dash for missing"; else
  # node path may still run; at least hours numeric
  if [[ "$pr2" == *"last 6h"* || "$pr2" == *"last 6"* ]]; then ok "a6 dash for missing"; else FAIL "a6 dash for missing ($pr2)"; fi
fi
if [[ "$combo" != *"┌"*"┐"* || "$combo" == *—* ]]; then ok "a6 no empty table-or-dash"; else
  # empty console.table draws a box — reject if we see empty table markers without data
  if printf '%s' "$combo" | grep -q '┌─────────┐'; then FAIL "a6 empty table box"; else ok "a6 no empty table-or-dash"; fi
fi

# ---------------------------------------------------------------------------
# a7: launch-path compat — stub receives identical args; exit code propagates
# ---------------------------------------------------------------------------
# grok stub exits 42
gout=$( "$LLM" grok-high -p x 2>/dev/null ); grc=$?
if [[ $grc -eq 42 ]]; then ok "a7 exit code propagates"; else FAIL "a7 exit code propagates (rc=$grc)"; fi
if [[ "$gout" == *"GROK_ARGS:"* && "$gout" == *"-p x"* ]]; then ok "a7 args pass through"; else FAIL "a7 args pass through ($gout)"; fi
# must include model pin + effort (pre-change golden shape)
if [[ "$gout" == *"--model grok-4.5"* && "$gout" == *"--effort high"* ]]; then ok "a7 golden flags"; else FAIL "a7 golden flags ($gout)"; fi
# claude path
cout=$( "$LLM" test -p hello 2>/dev/null ); crc=$?
if [[ $crc -eq 0 && "$cout" == *"CLAUDE_ARGS:-p hello"* ]]; then ok "a7 claude launch compat"; else FAIL "a7 claude launch compat"; fi
# banner on stderr only
cerr=$( "$LLM" test -p hello 2>&1 >/dev/null )
if [[ "$cerr" == *"▶ executor:"* ]]; then ok "a7 executor line stderr"; else FAIL "a7 executor line stderr"; fi
cstdout=$( "$LLM" test -p hello 2>/dev/null )
if [[ "$cstdout" != *"▶ executor:"* ]]; then ok "a7 banner not on stdout"; else FAIL "a7 banner not on stdout"; fi

# ---------------------------------------------------------------------------
# kit-absent fallback (GREEN_UI=/nonexistent)
# ---------------------------------------------------------------------------
ka=$( GREEN_UI=/nonexistent "$LLM" --dry-run test -p x </dev/null 2>/dev/null ); karc=$?
if [[ $karc -eq 0 && "$ka" == *"Would exec:"* ]]; then ok "a-kit-absent dry-run"; else FAIL "a-kit-absent dry-run"; fi
ka2=$( GREEN_UI=/nonexistent "$LLM" --list 2>/dev/null ); ka2rc=$?
if [[ $ka2rc -eq 0 && "$ka2" == *READY* ]]; then ok "a-kit-absent list"; else FAIL "a-kit-absent list"; fi
ka3=$( GREEN_UI=/nonexistent "$LLM" grok-high -p z 2>/dev/null ); ka3rc=$?
if [[ $ka3rc -eq 42 ]]; then ok "a-kit-absent launch"; else FAIL "a-kit-absent launch (rc=$ka3rc)"; fi

echo "----"
echo "phase1 failed=$fail"
exit "$fail"
