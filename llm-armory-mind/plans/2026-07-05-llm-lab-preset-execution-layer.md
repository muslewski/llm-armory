# llm-lab Preset Execution Layer Implementation Plan

> **Status 2026-07-10:** Core phases shipped (launcher, presets, test suite, freellmapi runbook, global CLAUDE.md section) — the checkboxes below were never ticked and are stale. The remaining live-verification phases for the free/balanced lanes are dormant per the current directive (grok-xhigh focus). Repo since rebranded llm-lab → llm-armory.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A preset-switchable launcher (`llm <preset>`) that runs Claude Code executor sessions against any provider (Max native, DeepSeek, z.ai GLM, OpenRouter, self-hosted freellmapi), with visible executor identity and syndcast SDD integration.

**Architecture:** One harness (the real `claude` binary), N environment-file presets. A preset resolves to one billing domain per invocation; tier mixing happens at orchestration level (a native Max session spawns `llm <preset> -p` children). No proxy or router ever carries Max traffic.

**Tech Stack:** Bash (launcher + tests, no framework), Docker (freellmapi), git worktrees (bake-off).

**Spec:** `docs/superpowers/specs/2026-07-05-llm-lab-preset-execution-layer-design.md`

## Global Constraints

- Max subscription traffic only via the real `claude` binary with **no** `ANTHROPIC_BASE_URL` override — never through a proxy/router.
- DeepSeek model IDs must be `deepseek-v4-pro` / `deepseek-v4-flash` (aliases `deepseek-chat`/`deepseek-reasoner` retire 2026-07-24).
- Provider endpoints (exact): DeepSeek `https://api.deepseek.com/anthropic`, z.ai `https://api.z.ai/api/anthropic`, OpenRouter `https://openrouter.ai/api`.
- Real API keys live only in `presets/providers/*.env` (gitignored). `*.env.example` files are committed. No key ever appears in a commit.
- Launcher banner goes to **stderr** (stdout must stay clean for `-p` output consumed by orchestrators).
- Every preset that sets a remote endpoint must set `API_TIMEOUT_MS` (no infinite hangs).
- Executor commits carry trailer `Executed-By: <model-id> (<preset>)`.
- Tasks 4, 5, and 9 need human input (API keys / web-UI actions) — pause and ask, do not fake keys.

## File Structure

```
llm-lab/
├── .gitignore                      # replace: ignore only real provider envs
├── README.md                       # usage, presets, conventions
├── bin/
│   ├── llm                         # the launcher (Task 2)
│   └── llm-statusline              # optional statusline segment (Task 10)
├── presets/
│   ├── quality.env  balanced.env  glm.env  free.env  burn.env   # committed
│   └── providers/
│       ├── deepseek.env.example  zai.env.example
│       ├── openrouter.env.example  freellmapi.env.example
│       └── anthropic-api.env.example                            # committed
├── templates/
│   └── task-brief.md               # executor brief template (Task 6)
├── bakeoff/
│   ├── run.sh                      # harness (Task 8)
│   ├── results/.gitkeep
│   └── RESULTS-TEMPLATE.md
├── freellmapi/                     # self-host home; src/ clone gitignored (Task 5)
└── tests/
    └── test_llm.sh                 # launcher test suite (Task 2)
```

---

### Task 1: Repo scaffold and .gitignore

**Files:**
- Modify: `.gitignore` (repo root, currently ignores all preset envs — wrong: named presets hold no secrets and must be committed)
- Create: `README.md`, `bakeoff/results/.gitkeep`

**Interfaces:**
- Produces: directory layout + ignore rules every later task relies on.

- [ ] **Step 1: Replace .gitignore**

```gitignore
# real provider credentials — never committed
presets/providers/*.env
!presets/providers/*.env.example
# freellmapi upstream clone + its runtime config
freellmapi/src/
freellmapi/.env
# bake-off raw logs (summaries are committed)
bakeoff/results/*.log
```

- [ ] **Step 2: Create README.md**

```markdown
# llm-lab

Preset-switchable multi-provider execution layer for Claude Code.
Spec: `docs/superpowers/specs/2026-07-05-llm-lab-preset-execution-layer-design.md`

## Usage

    llm --list                     # presets + resolved endpoint/model
    llm --dry-run balanced         # show resolved env, don't launch
    llm balanced                   # interactive session on the preset
    llm balanced -p "task brief" --permission-mode acceptEdits   # executor child

## Tiers → presets

| Preset   | Billing            | Use for |
|----------|--------------------|---------|
| quality  | Max subscription   | judgment sessions (also just run `claude`) |
| balanced | DeepSeek API       | fleet implementation (V4-Pro; V4-Flash chores) |
| glm      | z.ai API           | hardest implementation tasks (GLM-5.2) |
| free     | freellmapi (local) | chores; $0 |
| burn     | Anthropic API key  | limit-reset days, uncapped Opus |

## Conventions

- Max never goes through a proxy. Cross-billing mixing = orchestrator (native
  Max) spawns `llm <preset> -p` children.
- Executor commits end with `Executed-By: <model-id> (<preset>)`.
- Keys live in `presets/providers/*.env` (gitignored); copy from `.env.example`.
```

- [ ] **Step 3: Create directories and commit**

```bash
mkdir -p bin presets/providers templates bakeoff/results freellmapi tests
touch bakeoff/results/.gitkeep
git add -A
git commit -m "chore: scaffold llm-lab layout, fix gitignore to commit named presets"
```

---

### Task 2: `bin/llm` launcher (TDD)

**Files:**
- Create: `tests/test_llm.sh`, `bin/llm`
- Modify: `~/.local/bin/` (symlink)

**Interfaces:**
- Consumes: `$LLM_LAB_HOME` (default `~/Repositories/llm-lab`), preset files `presets/<name>.env`.
- Produces: CLI `llm --list | llm --dry-run <preset> | llm <preset> [claude args...]`. Exports `PRESETS_DIR` so preset files can `source "$PRESETS_DIR/providers/x.env"`. Exit 1 + stderr message on unknown preset or missing credential. Banner line on stderr: `▶ executor: <model> @ <host> (preset: <name>)`.

- [ ] **Step 1: Write the failing test suite**

`tests/test_llm.sh`:

```bash
#!/usr/bin/env bash
# Self-contained test suite for bin/llm. No network, no real claude.
set -uo pipefail
cd "$(dirname "$0")/.."
LLM="$PWD/bin/llm"

# --- fixture lab home ---
export LLM_LAB_HOME="$(mktemp -d)"
trap 'rm -rf "$LLM_LAB_HOME"' EXIT
mkdir -p "$LLM_LAB_HOME/presets/providers"

cat > "$LLM_LAB_HOME/presets/test.env" <<'EOF'
export LLM_PRESET=test
export ANTHROPIC_BASE_URL=https://example.test/anthropic
export ANTHROPIC_AUTH_TOKEN=sk-fixture-token-123456
export ANTHROPIC_MODEL=fixture-model-pro
export API_TIMEOUT_MS=600000
EOF

cat > "$LLM_LAB_HOME/presets/nokey.env" <<'EOF'
export LLM_PRESET=nokey
export ANTHROPIC_BASE_URL=https://example.test/anthropic
EOF

cat > "$LLM_LAB_HOME/presets/native.env" <<'EOF'
export LLM_PRESET=native
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
"$LLM" doesnotexist >/dev/null 2>"$LLM_LAB_HOME/err" ; rc=$?
check "unknown preset exits 1" test $rc -eq 1
check "unknown preset names problem" grep -q "unknown preset 'doesnotexist'" "$LLM_LAB_HOME/err"

# 4. remote endpoint without credential → exit 1
"$LLM" nokey >/dev/null 2>"$LLM_LAB_HOME/err2" ; rc=$?
check "missing key exits 1" test $rc -eq 1
check "missing key explains fix" grep -q 'ANTHROPIC_AUTH_TOKEN' "$LLM_LAB_HOME/err2"

# 5. launch path: args pass through, env applied, banner on stderr only
run_out=$("$LLM" test -p hello 2>"$LLM_LAB_HOME/err3")
check "claude receives args"  grep -q 'CLAUDE_ARGS:-p hello' <<<"$run_out"
check "claude sees preset url" grep -q 'CLAUDE_URL:https://example.test/anthropic' <<<"$run_out"
check "banner on stderr"       grep -q '▶ executor: fixture-model-pro @ https://example.test/anthropic (preset: test)' "$LLM_LAB_HOME/err3"
if grep -q '▶ executor' <<<"$run_out"; then
  fail=$((fail+1)); echo "FAIL - banner leaked to stdout"
else
  pass=$((pass+1)); echo "ok   - banner not on stdout"
fi

# 6. native preset: no url override, no credential demanded
nat=$("$LLM" native -p hi 2>/dev/null)
check "native has no url override" grep -q 'CLAUDE_URL:none' <<<"$nat"

echo "----"
echo "passed=$pass failed=$fail"
test "$fail" -eq 0
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `chmod +x tests/test_llm.sh && ./tests/test_llm.sh`
Expected: FAIL lines (bin/llm does not exist), final `test "$fail" -eq 0` exits nonzero.

- [ ] **Step 3: Implement `bin/llm`**

```bash
#!/usr/bin/env bash
# llm — preset-switchable launcher for Claude Code sessions.
# Presets: $LLM_LAB_HOME/presets/*.env  (default lab home: ~/Repositories/llm-lab)
set -euo pipefail

LLM_LAB_HOME="${LLM_LAB_HOME:-$HOME/Repositories/llm-lab}"
PRESETS_DIR="$LLM_LAB_HOME/presets"
export PRESETS_DIR   # preset files use it to source providers/*.env

usage() {
  cat >&2 <<'EOF'
llm — preset-switchable Claude Code launcher

Usage:
  llm --list                     show presets with resolved model/endpoint
  llm --dry-run <preset>         print resolved env (token masked), don't launch
  llm <preset> [claude args...]  launch claude under the preset

Presets are env files in $LLM_LAB_HOME/presets (default ~/Repositories/llm-lab/presets).
The 'quality' preset (or plain `claude`) = native Max — never proxied.
EOF
}

resolve() {
  local preset=$1 file="$PRESETS_DIR/$1.env"
  if [[ ! -f "$file" ]]; then
    echo "llm: unknown preset '$preset' (looked in $PRESETS_DIR)" >&2
    echo -n "llm: available:" >&2
    for f in "$PRESETS_DIR"/*.env; do [[ -e "$f" ]] && echo -n " $(basename "$f" .env)" >&2; done
    echo >&2
    exit 1
  fi
  set -a
  # shellcheck disable=SC1090
  source "$file"
  set +a
}

check_auth() {
  if [[ -n "${ANTHROPIC_BASE_URL:-}" && -z "${ANTHROPIC_AUTH_TOKEN:-}${ANTHROPIC_API_KEY:-}" ]]; then
    echo "llm: preset '${LLM_PRESET:-?}' sets ANTHROPIC_BASE_URL but no ANTHROPIC_AUTH_TOKEN/ANTHROPIC_API_KEY." >&2
    echo "llm: copy presets/providers/<provider>.env.example to <provider>.env and add your key." >&2
    exit 1
  fi
}

banner() {
  local model="${ANTHROPIC_MODEL:-claude (native)}" host billing
  if [[ -n "${ANTHROPIC_BASE_URL:-}" ]]; then
    host="$ANTHROPIC_BASE_URL"
  elif [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    host="api.anthropic.com (API-billed)"
  else
    host="api.anthropic.com (Max subscription)"
  fi
  echo "▶ executor: ${model} @ ${host} (preset: ${LLM_PRESET:-?})" >&2
}

case "${1:-}" in
  ""|-h|--help)
    usage; exit 0 ;;
  --list)
    found=0
    for f in "$PRESETS_DIR"/*.env; do
      [[ -e "$f" ]] || continue
      found=1
      name=$(basename "$f" .env)
      (
        set +e; set -a
        # shellcheck disable=SC1090
        source "$f" >/dev/null 2>&1
        set +a
        printf '%-10s %-24s %s\n' "$name" "${ANTHROPIC_MODEL:-native}" \
          "${ANTHROPIC_BASE_URL:-api.anthropic.com (Max)}"
      )
    done
    [[ $found -eq 1 ]] || { echo "llm: no presets in $PRESETS_DIR" >&2; exit 1; }
    exit 0 ;;
  --dry-run)
    [[ $# -ge 2 ]] || { usage; exit 1; }
    resolve "$2"
    check_auth
    banner
    tok="${ANTHROPIC_AUTH_TOKEN:-${ANTHROPIC_API_KEY:-}}"
    echo "LLM_PRESET=${LLM_PRESET:-}"
    echo "ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL:-}"
    echo "ANTHROPIC_AUTH_TOKEN=${tok:+${tok:0:6}…(masked)}"
    echo "ANTHROPIC_MODEL=${ANTHROPIC_MODEL:-}"
    echo "ANTHROPIC_DEFAULT_OPUS_MODEL=${ANTHROPIC_DEFAULT_OPUS_MODEL:-}"
    echo "ANTHROPIC_DEFAULT_SONNET_MODEL=${ANTHROPIC_DEFAULT_SONNET_MODEL:-}"
    echo "ANTHROPIC_DEFAULT_HAIKU_MODEL=${ANTHROPIC_DEFAULT_HAIKU_MODEL:-}"
    echo "CLAUDE_CODE_SUBAGENT_MODEL=${CLAUDE_CODE_SUBAGENT_MODEL:-}"
    echo "API_TIMEOUT_MS=${API_TIMEOUT_MS:-}"
    exit 0 ;;
  --*)
    usage; exit 1 ;;
  *)
    preset=$1; shift
    resolve "$preset"
    check_auth
    banner
    exec claude "$@" ;;
esac
```

- [ ] **Step 4: Run tests, verify they pass**

Run: `chmod +x bin/llm && ./tests/test_llm.sh`
Expected: all `ok` lines, `passed=16 failed=0`, exit 0.

- [ ] **Step 5: Install user-global symlink**

```bash
mkdir -p ~/.local/bin
ln -sf "$PWD/bin/llm" ~/.local/bin/llm
command -v llm   # expect: /home/kento/.local/bin/llm
llm --help       # expect: usage text, exit 0
```

If `command -v llm` finds nothing, `~/.local/bin` is not on PATH — add `export PATH="$HOME/.local/bin:$PATH"` to `~/.bashrc` and re-check in a fresh shell.

- [ ] **Step 6: Commit**

```bash
git add bin/llm tests/test_llm.sh
git commit -m "feat: llm preset launcher with list/dry-run and stderr banner"
```

---

### Task 3: Preset and provider env files

**Files:**
- Create: `presets/quality.env`, `presets/balanced.env`, `presets/glm.env`, `presets/free.env`, `presets/burn.env`
- Create: `presets/providers/deepseek.env.example`, `presets/providers/zai.env.example`, `presets/providers/openrouter.env.example`, `presets/providers/freellmapi.env.example`, `presets/providers/anthropic-api.env.example`

**Interfaces:**
- Consumes: `$PRESETS_DIR` exported by `bin/llm`.
- Produces: the five named presets `llm` resolves. Provider files define `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` (or `ANTHROPIC_API_KEY`); presets define `LLM_PRESET`, model slots, `API_TIMEOUT_MS`.

- [ ] **Step 1: Write provider examples**

`presets/providers/deepseek.env.example`:

```bash
# DeepSeek — native Anthropic-compatible endpoint.
# Copy to deepseek.env and set your key (https://platform.deepseek.com/api_keys).
export ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
export ANTHROPIC_AUTH_TOKEN=sk-REPLACE_ME
```

`presets/providers/zai.env.example`:

```bash
# z.ai (GLM) — native Anthropic-compatible endpoint.
# Copy to zai.env and set your key (https://z.ai/manage-apikey/apikey-list).
export ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic
export ANTHROPIC_AUTH_TOKEN=REPLACE_ME
```

`presets/providers/openrouter.env.example`:

```bash
# OpenRouter — Anthropic Messages skin; supports server-side @preset/ slugs.
# Copy to openrouter.env and set your key (https://openrouter.ai/keys).
export ANTHROPIC_BASE_URL=https://openrouter.ai/api
export ANTHROPIC_AUTH_TOKEN=sk-or-REPLACE_ME
```

`presets/providers/freellmapi.env.example`:

```bash
# freellmapi — self-hosted free-tier aggregator (Task 5).
# Copy to freellmapi.env; key comes from its Keys page after install.
# Port: confirm against freellmapi/src/README after cloning; adjust if not 3000.
export ANTHROPIC_BASE_URL=http://localhost:3000
export ANTHROPIC_AUTH_TOKEN=REPLACE_ME
```

`presets/providers/anthropic-api.env.example`:

```bash
# Anthropic Console API key — API-billed frontier models (burn preset).
# Copy to anthropic-api.env and set your key (https://console.anthropic.com).
# NOTE: no ANTHROPIC_BASE_URL here — native endpoint, API-key billing.
export ANTHROPIC_API_KEY=sk-ant-REPLACE_ME
```

- [ ] **Step 2: Write the five presets**

`presets/quality.env`:

```bash
# quality — native Max session. Stock Claude Code, zero overrides.
# Equivalent to running plain `claude`; exists so `llm quality` is valid.
export LLM_PRESET=quality
```

`presets/balanced.env`:

```bash
# balanced — fleet implementation default. DeepSeek V4-Pro; V4-Flash for
# haiku-slot/chore/subagent work inside the session.
export LLM_PRESET=balanced
[[ -f "$PRESETS_DIR/providers/deepseek.env" ]] && source "$PRESETS_DIR/providers/deepseek.env"
export ANTHROPIC_MODEL=deepseek-v4-pro
export ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek-v4-pro
export ANTHROPIC_DEFAULT_SONNET_MODEL=deepseek-v4-pro
export ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash
export ANTHROPIC_SMALL_FAST_MODEL=deepseek-v4-flash
export CLAUDE_CODE_SUBAGENT_MODEL=deepseek-v4-flash
export API_TIMEOUT_MS=600000
```

`presets/glm.env`:

```bash
# glm — hardest implementation tasks. GLM-5.2 via z.ai.
export LLM_PRESET=glm
[[ -f "$PRESETS_DIR/providers/zai.env" ]] && source "$PRESETS_DIR/providers/zai.env"
export ANTHROPIC_MODEL=glm-5.2
export ANTHROPIC_DEFAULT_OPUS_MODEL=glm-5.2
export ANTHROPIC_DEFAULT_SONNET_MODEL=glm-5.2
export ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-4.7-flash
export ANTHROPIC_SMALL_FAST_MODEL=glm-4.7-flash
export CLAUDE_CODE_SUBAGENT_MODEL=glm-4.7-flash
export API_TIMEOUT_MS=600000
```

`presets/free.env`:

```bash
# free — $0 tier via self-hosted freellmapi (18 providers, auto-failover).
# 'auto' lets freellmapi pick; pin models on its Keys page if wanted.
export LLM_PRESET=free
[[ -f "$PRESETS_DIR/providers/freellmapi.env" ]] && source "$PRESETS_DIR/providers/freellmapi.env"
export ANTHROPIC_MODEL=auto
export ANTHROPIC_DEFAULT_OPUS_MODEL=auto
export ANTHROPIC_DEFAULT_SONNET_MODEL=auto
export ANTHROPIC_DEFAULT_HAIKU_MODEL=auto
export ANTHROPIC_SMALL_FAST_MODEL=auto
export CLAUDE_CODE_SUBAGENT_MODEL=auto
export API_TIMEOUT_MS=600000
```

`presets/burn.env`:

```bash
# burn — uncapped API-billed Opus for limit-reset days. Costs real money.
export LLM_PRESET=burn
[[ -f "$PRESETS_DIR/providers/anthropic-api.env" ]] && source "$PRESETS_DIR/providers/anthropic-api.env"
export ANTHROPIC_MODEL=claude-opus-4-8
export ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-8
export ANTHROPIC_DEFAULT_SONNET_MODEL=claude-opus-4-8
export ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-haiku-4-5-20251001
export API_TIMEOUT_MS=600000
```

- [ ] **Step 3: Verify with the launcher**

```bash
llm --list
```

Expected output at this step — no `providers/*.env` exist yet, so the guarded `source` lines are skipped and every URL column reads native:

```
balanced   deepseek-v4-pro          api.anthropic.com (Max)
burn       claude-opus-4-8          api.anthropic.com (Max)
free       auto                     api.anthropic.com (Max)
glm        glm-5.2                  api.anthropic.com (Max)
quality    native                   api.anthropic.com (Max)
```

After Tasks 4/5/9 create the real provider files, the URL column fills in (`https://api.deepseek.com/anthropic`, `http://localhost:3000`, `https://api.z.ai/api/anthropic`). The `check_auth` guard means these presets refuse to *launch* until then — only `--list`/`quality` work key-less.

Also run: `llm --dry-run quality` → expect banner `▶ executor: claude (native) @ api.anthropic.com (Max subscription) (preset: quality)` and empty override lines.

- [ ] **Step 4: Confirm no secrets staged, then commit**

```bash
git status --porcelain | grep 'providers/.*\.env$' && echo "STOP: real env staged" || echo "clean"
git add presets README.md .gitignore
git commit -m "feat: five named presets + provider env examples"
```

Expected: `clean` (only `.env.example` files under providers/ are tracked).

---

### Task 4: DeepSeek live smoke test — REQUIRES HUMAN (API key)

**Files:**
- Create: `presets/providers/deepseek.env` (local only, gitignored)

**Interfaces:**
- Consumes: `llm` launcher + `balanced` preset (Tasks 2–3).
- Produces: verified working cheap executor path; evidence for the fleet default.

- [ ] **Step 1: Ask the human for a DeepSeek API key**

Pause. Ask: "Need a DeepSeek API key (platform.deepseek.com → API keys, top up ~$5). Paste it or put it in presets/providers/deepseek.env yourself." Then:

```bash
cp presets/providers/deepseek.env.example presets/providers/deepseek.env
# edit: replace sk-REPLACE_ME with the real key
```

- [ ] **Step 2: Dry-run sanity**

Run: `llm --dry-run balanced`
Expected: banner shows `deepseek-v4-pro @ https://api.deepseek.com/anthropic (preset: balanced)`, token masked (`sk-…(masked)` style), `API_TIMEOUT_MS=600000`.

- [ ] **Step 3: Live one-shot**

Run: `llm balanced -p "Reply with exactly: EXECUTOR-OK deepseek-v4-pro"`
Expected: stderr banner, stdout contains `EXECUTOR-OK deepseek-v4-pro`. If auth error, key is wrong; if model-not-found, check ID is `deepseek-v4-pro` (post-2026-07-24 naming).

- [ ] **Step 4: Verify git cleanliness and commit nothing**

Run: `git status --porcelain`
Expected: empty (the real env file is ignored). No commit for this task.

---

### Task 5: freellmapi self-host — REQUIRES HUMAN (provider signups vary)

**Files:**
- Create: `freellmapi/src/` (upstream clone, gitignored), `presets/providers/freellmapi.env` (local only), `freellmapi/NOTES.md` (committed)

**Interfaces:**
- Consumes: Docker, `free` preset (Task 3).
- Produces: local `/v1/messages` endpoint powering `llm free`.

- [ ] **Step 1: Clone and start**

```bash
git clone https://github.com/tashfeenahmed/freellmapi freellmapi/src
cd freellmapi/src
# Follow its README quick-start. Typical path:
docker compose up -d
cd ../..
```

The upstream README is authoritative for port and first-run setup; if its compose file or port differs from 3000, record the real values in `freellmapi/NOTES.md` and in `presets/providers/freellmapi.env`.

- [ ] **Step 2: Configure key + verify Anthropic endpoint**

Open its web UI (Keys page), create an API key, put it in `presets/providers/freellmapi.env` (copy from the example). Then:

```bash
source presets/providers/freellmapi.env
curl -s -X POST "$ANTHROPIC_BASE_URL/v1/messages" \
  -H "x-api-key: $ANTHROPIC_AUTH_TOKEN" \
  -H "anthropic-version: 2023-06-01" -H "content-type: application/json" \
  -d '{"model":"auto","max_tokens":32,"messages":[{"role":"user","content":"Say FREELLM-OK"}]}' | head -c 400
```

Expected: JSON response containing `FREELLM-OK` (any free model may answer; slowness is normal).

- [ ] **Step 3: End-to-end through the launcher**

Run: `llm free -p "Reply with exactly: EXECUTOR-OK free-tier"`
Expected: banner `▶ executor: auto @ http://localhost:3000 (preset: free)`, stdout contains `EXECUTOR-OK free-tier`.

- [ ] **Step 4: Write NOTES.md and commit**

`freellmapi/NOTES.md`:

```markdown
# freellmapi self-host notes

- Source: https://github.com/tashfeenahmed/freellmapi (clone lives in ./src, gitignored)
- Started: 2026-07-XX, `docker compose up -d` in ./src
- Port: <record actual>   Endpoint: http://localhost:<port>  (Anthropic format: POST /v1/messages)
- Key: created on its Keys page → presets/providers/freellmapi.env (gitignored)
- Model families opus/sonnet/haiku map to 'auto' or pinned models via the Keys page.
- Free installs lag catalog updates ~30 days; $19/yr Premium keeps it current — decide later.
- Restart after reboot: `cd freellmapi/src && docker compose up -d`
```

Fill the `<record actual>` values from Step 1–2 observations, then:

```bash
git add freellmapi/NOTES.md
git commit -m "docs: freellmapi self-host runbook"
```

---

### Task 6: Executor brief template with Executed-By trailer

**Files:**
- Create: `templates/task-brief.md`

**Interfaces:**
- Consumes: nothing (pure template).
- Produces: the brief format orchestrators paste into `llm <preset> -p "$(cat brief)"`. Later tasks (7, 8) reference it verbatim.

- [ ] **Step 1: Write the template**

```markdown
# Task: <one-line title>

## Context
- Repo: <absolute path to worktree>
- Plan: <path to plan/advisor-plan and task number>
- You are an implementation executor. Implement ONLY this task. Do not touch
  files outside the listed scope. Do not refactor unrelated code.

## Scope
- Files to create/modify: <exact paths>
- Interfaces you must match (names, signatures, types): <from the plan>

## Done criteria (machine-checkable)
- <exact command>: <expected output>
- All tests pass: <exact test command>

## STOP conditions — abort and report instead of guessing
- A file you must modify does not exist or differs materially from the plan's description.
- Done-criteria command fails twice after your best fix.
- You need a credential, migration, or dependency not listed here.

## Commit protocol
- Small commits as you complete each step.
- EVERY commit message must end with this trailer (fill from your session env
  $ANTHROPIC_MODEL and $LLM_PRESET):

    Executed-By: <model-id> (<preset>)

## Report
End your final message with:
- STATUS: done | blocked
- COMMITS: <hashes + one-liners>
- EVIDENCE: verbatim output of each done-criteria command
- DEVIATIONS: anything you did differently from the brief, or "none"
```

- [ ] **Step 2: Verify template renders and commit**

Run: `grep -c 'Executed-By' templates/task-brief.md`
Expected: `2` (protocol line + trailer example).

```bash
git add templates/task-brief.md
git commit -m "feat: executor task-brief template with Executed-By trailer + STOP conditions"
```

---

### Task 7: syndcast integration (Execution tier)

**Files:**
- Modify: `/home/kento/Repositories/syndcast/CLAUDE.md` (append a new section; do not edit existing tables)

**Interfaces:**
- Consumes: `llm` on PATH (Task 2), `balanced`/`glm` presets (Task 3), brief template (Task 6).
- Produces: the convention every syndcast SDD/orchestrator session follows to spawn cheap executors.

- [ ] **Step 1: Append the Execution-tier section to syndcast CLAUDE.md**

Open `/home/kento/Repositories/syndcast/CLAUDE.md`, find the agents-and-effort tiering section, and append this section immediately after it (verbatim):

```markdown
## Execution tier (cheap executors via llm-lab)

Implementation tasks from SDD/advisor-plans run on cheap API models, not on
the Max session. Judgment (brainstorm/spec/plan/verify/merge) stays native.

- Spawn per task, inside the task's worktree:
  `llm balanced -p "$(cat <brief-file>)" --permission-mode acceptEdits`
  Use `llm glm` instead for tasks tagged hard (architecture-heavy, cross-cutting).
- Briefs follow `~/Repositories/llm-lab/templates/task-brief.md` (STOP
  conditions + machine-checkable done criteria + Executed-By commit trailer).
- The orchestrator NEVER sets ANTHROPIC_BASE_URL in its own session — Max
  traffic must stay native. Provider switching happens only in spawned
  children via the `llm` launcher.
- Verification of executor output happens in the Max session before merge:
  plan-contract reconcile + full tests + adversarial review for
  auth/billing/migrations. A task whose verification fails is re-run
  (same or stronger preset); worktrees are disposable.
- Attribution: `git log --format='%(trailers:key=Executed-By,valueonly)'`
  shows which model wrote what.
```

- [ ] **Step 2: Verify and commit (in syndcast repo)**

```bash
grep -n 'Execution tier (cheap executors' /home/kento/Repositories/syndcast/CLAUDE.md
cd /home/kento/Repositories/syndcast
git add CLAUDE.md
git commit -m "docs: execution tier — SDD implementation tasks spawn llm-lab cheap executors"
```

Expected: grep prints one match with a line number; commit succeeds on syndcast's current branch (check `git branch --show-current` first; if on main and repo convention forbids direct commits, create branch `chore/execution-tier` and commit there, then tell the human).

---

### Task 8: Bake-off harness

**Files:**
- Create: `bakeoff/run.sh`, `bakeoff/RESULTS-TEMPLATE.md`

**Interfaces:**
- Consumes: `llm` launcher, presets, a brief file (Task 6 format), syndcast repo with worktree support.
- Produces: `bakeoff/run.sh <brief-file> <preset>...` → one worktree + log per preset + a summary file. Human (or Max session) fills RESULTS-TEMPLATE per run.

- [ ] **Step 1: Write the harness**

`bakeoff/run.sh`:

```bash
#!/usr/bin/env bash
# Bake-off: run the same task brief through several presets, one worktree each.
# Usage: bakeoff/run.sh <brief-file> <preset> [preset...]
# Env:   BAKEOFF_REPO (default ~/Repositories/syndcast)
set -euo pipefail

[[ $# -ge 2 ]] || { echo "usage: $0 <brief-file> <preset> [preset...]" >&2; exit 1; }
BRIEF_FILE=$(realpath "$1"); shift
[[ -f "$BRIEF_FILE" ]] || { echo "no such brief: $BRIEF_FILE" >&2; exit 1; }

REPO="${BAKEOFF_REPO:-$HOME/Repositories/syndcast}"
LAB="${LLM_LAB_HOME:-$HOME/Repositories/llm-lab}"
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
```

- [ ] **Step 2: Write the results template**

`bakeoff/RESULTS-TEMPLATE.md`:

```markdown
# Bake-off verdict: <brief name> — <date>

| Preset | Model | Wall time | Cost (provider dashboard) | Tests pass? | Verify verdict (Max review) | Notes |
|---|---|---|---|---|---|---|
| balanced | deepseek-v4-pro | | | | | |
| glm | glm-5.2 | | | | | |
| free | (auto) | | | | | |
| quality | max sonnet/opus | | | | | |

## Verification method
Same Max session reviewed each worktree diff against the brief's done
criteria + ran the test suite. Adversarial pass for sensitive surfaces.

## Decision
- Fleet default stays/changes to: <preset>
- Demotions/promotions: <model → tier, evidence>
```

- [ ] **Step 3: Smoke-test the harness plumbing (no API spend)**

```bash
chmod +x bakeoff/run.sh
echo "Reply with exactly: BAKEOFF-PLUMBING-OK and do nothing else. Do not create commits." > bakeoff/plumb-brief.md
BAKEOFF_REPO=$HOME/Repositories/syndcast bakeoff/run.sh bakeoff/plumb-brief.md balanced
```

Expected: one worktree created, `results/<stamp>-balanced.log` contains `BAKEOFF-PLUMBING-OK`, summary file written. (`balanced` costs a fraction of a cent; use `free` instead once Task 5 is live.) Then clean up:

```bash
wt=$(git -C ~/Repositories/syndcast worktree list | awk '/bakeoff-balanced/{print $1}')
[[ -n "$wt" ]] && git -C ~/Repositories/syndcast worktree remove --force "$wt"
rm bakeoff/plumb-brief.md
```

- [ ] **Step 4: Commit**

```bash
git add bakeoff/run.sh bakeoff/RESULTS-TEMPLATE.md
git commit -m "feat: bake-off harness — same brief, N presets, worktree + attribution each"
```

---

### Task 9: OpenRouter server-side presets — REQUIRES HUMAN (web UI)

**Files:**
- Create: `presets/openrouter-exec.env`, `presets/providers/openrouter.env` (local only)

**Interfaces:**
- Consumes: OpenRouter account + key; `llm` launcher.
- Produces: `llm openrouter-exec` — execution preset whose model/fallback chain is edited on openrouter.ai without touching local files.

- [ ] **Step 1: Ask the human to create the server-side presets**

Pause. Ask the human to log into openrouter.ai → Presets and create:
- `llm-lab-execution`: model `deepseek/deepseek-v4-pro` (or current best value), fallbacks `z-ai/glm-5.2`, `moonshotai/kimi-k2.7`; provider routing `price` sort.
- `llm-lab-chores`: model a strong `:free` variant, fallback `deepseek/deepseek-v4-flash`.

And to paste an API key for `presets/providers/openrouter.env` (copy from the example).

- [ ] **Step 2: Write the local preset**

`presets/openrouter-exec.env`:

```bash
# openrouter-exec — execution via OpenRouter server-side preset.
# Change models/fallbacks at https://openrouter.ai/settings/presets — no local edits.
export LLM_PRESET=openrouter-exec
[[ -f "$PRESETS_DIR/providers/openrouter.env" ]] && source "$PRESETS_DIR/providers/openrouter.env"
export ANTHROPIC_MODEL=@preset/llm-lab-execution
export ANTHROPIC_DEFAULT_OPUS_MODEL=@preset/llm-lab-execution
export ANTHROPIC_DEFAULT_SONNET_MODEL=@preset/llm-lab-execution
export ANTHROPIC_DEFAULT_HAIKU_MODEL=@preset/llm-lab-chores
export ANTHROPIC_SMALL_FAST_MODEL=@preset/llm-lab-chores
export CLAUDE_CODE_SUBAGENT_MODEL=@preset/llm-lab-chores
export API_TIMEOUT_MS=600000
```

- [ ] **Step 3: Live one-shot**

Run: `llm openrouter-exec -p "Reply with exactly: EXECUTOR-OK openrouter-preset"`
Expected: banner `@preset/llm-lab-execution @ https://openrouter.ai/api`, stdout contains `EXECUTOR-OK openrouter-preset`. If 404 on preset slug, the server-side preset name doesn't match — fix on the website, not locally.

- [ ] **Step 4: Commit**

```bash
git add presets/openrouter-exec.env
git commit -m "feat: openrouter-exec preset backed by server-side @preset slugs"
```

---

### Task 10: Statusline executor segment (optional)

**Files:**
- Create: `bin/llm-statusline`
- Modify: `~/.claude/settings.json` — ONLY if a statusline is already configured; otherwise just document.

**Interfaces:**
- Consumes: Claude Code statusline stdin JSON (`.model.display_name`) + session env `LLM_PRESET`.
- Produces: one-line segment `⚡ <preset>:<model>` for embedding in the user's statusline command.

- [ ] **Step 1: Write the segment script**

```bash
#!/usr/bin/env bash
# llm-statusline — emit "⚡ <preset>:<model>" for the Claude Code statusline.
# Reads statusline JSON on stdin; falls back to env when fields are absent.
set -euo pipefail
input=$(cat)
model=$(printf '%s' "$input" | grep -o '"display_name"[^,}]*' | head -1 | sed 's/.*:\s*"\{0,1\}\([^"]*\)"\{0,1\}/\1/')
preset="${LLM_PRESET:-max}"
echo "⚡ ${preset}:${model:-${ANTHROPIC_MODEL:-fable}}"
```

- [ ] **Step 2: Test with fixture input**

```bash
chmod +x bin/llm-statusline
echo '{"model":{"id":"deepseek-v4-pro","display_name":"deepseek-v4-pro"}}' | LLM_PRESET=balanced bin/llm-statusline
```

Expected: `⚡ balanced:deepseek-v4-pro`

- [ ] **Step 3: Wire or document**

Check `grep -n statusLine ~/.claude/settings.json`. If a statusline command exists, append ` | ` + this script's output to it only with the human's OK (their statusline is customized — ask first). If none, add to README under a "Statusline" heading:

```markdown
## Statusline

Show the live executor in your statusline: pipe `bin/llm-statusline` into your
existing statusLine command, or set it directly in ~/.claude/settings.json:
  "statusLine": {"type": "command", "command": "~/Repositories/llm-armory/bin/llm-statusline"}
```

- [ ] **Step 4: Commit**

```bash
git add bin/llm-statusline README.md
git commit -m "feat: optional statusline segment showing preset + executor model"
```

---

## Execution order and human gates

1 → 2 → 3 (pure local, no keys) → **4 (human: DeepSeek key)** → 6 → 7 → 8 → **5 (human: freellmapi setup)** → **9 (human: OpenRouter UI)** → 10 (optional).

Task 5 can slide later without blocking anything except the `free` preset; Task 8's plumbing test falls back to `balanced`.

## After this plan

Week-1 bake-off (spec §Week 1): brief from advisor-plan 032 via `bakeoff/run.sh <brief> balanced glm quality` (+`free` once live), verdict into `bakeoff/RESULTS-TEMPLATE.md` copy, fleet default confirmed by evidence. Then first fleet run on parallel-safe advisor-plans.
