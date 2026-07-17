#!/usr/bin/env bash
# Run all armory test suites. Nonzero exit if any fail.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
fail=0
bash tests/test_llm.sh || fail=1
bash tests/test_ui_phase1.sh || fail=1
bash tests/test_fleet.sh || fail=1
exit "$fail"
