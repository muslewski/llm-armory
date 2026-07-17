#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
GREEN_DEMO="${GREEN_DEMO:-$HOME/.local/lib/green-demo.sh}"
[ -r "$GREEN_DEMO" ] || { echo "green-demo.sh not found — run green-ui-kit/install.sh" >&2; exit 1; }
. "$GREEN_DEMO"
demo_sandbox "$PWD"          # exports HOME + 4 XDG vars into mktemp root, overlays fixtures/home
for tape in scenes/*.tape; do demo_record "$tape"; done
