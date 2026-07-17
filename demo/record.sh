#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
GREEN_DEMO="${GREEN_DEMO:-$HOME/.local/lib/green-demo.sh}"
[ -r "$GREEN_DEMO" ] || { echo "green-demo.sh not found — run green-ui-kit/install.sh" >&2; exit 1; }
. "$GREEN_DEMO"
demo_sandbox "$PWD"          # exports HOME + 4 XDG vars into mktemp root, overlays fixtures/home

# Isolate from parent armory session env (LLM_ARMORY_HOME / LLM_GROK / …).
# Without this, VHS inherits the live checkout path and real SKIP badges.
export LLM_ARMORY_HOME="$HOME/Repositories/llm-armory"
export LLM_LAB_HOME="$LLM_ARMORY_HOME"
export ARMORY_HOME="$LLM_ARMORY_HOME"
export PATH="$HOME/.local/bin:${PATH:-}"
# Kit lives outside the sandbox; hide-block also sets this for belt-and-suspenders.
export GREEN_UI="${GREEN_UI:-/home/kento/.local/lib/green-ui.sh}"
export PS1='\$ '
# Drop parent loadout classification so list/doctor/dry-run classify cleanly.
unset LLM_GROK GROK_EFFORT GROK_MODEL LLM_PRESET LLM_SYSTEM_APPEND \
      LLM_REQUIRES_CREDENTIAL LLM_EXECUTOR_HOOKS 2>/dev/null || true

for tape in scenes/*.tape; do demo_record "$tape"; done
