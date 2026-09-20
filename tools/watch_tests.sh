#!/usr/bin/env bash
# Watch .gd files; on save run gdlint + the focused test suite for that path.
# Usage: tools/watch_tests.sh [suite-filter]   (requires: fswatch, .venv-tools)
set -euo pipefail
cd "$(dirname "$0")/.."

FILTER="${1:-}"
SUITES_DIR="tests"
IGNORE='(\.venv-tools|\.godot|\.git|addons|node_modules)'

last_run=0
run_checks() {
  local file="$1"
  now=$(date +%s)
  # debounce: at most one run per second
  (( now - last_run < 1 )) && return 0
  last_run=$now
  echo "── $(basename "$file") changed"

  if [[ "$file" == scripts/* ]]; then
    .venv-tools/bin/gdlint "$file" && echo "  lint OK" || echo "  lint FAILED (see above)"
  fi

  # map changed file -> focused suite(s)
  local suites=()
  if [[ -n "$FILTER" ]]; then
    while IFS= read -r s; do suites+=("$s"); done < <(find "$SUITES_DIR" -name "*${FILTER}*_test.gd")
  elif [[ "$file" == scripts/* || "$file" == tests/* || "$file" == scenes/* ]]; then
    # derive suite name from the changed script: writer_rig.gd -> writer_rig_space_test.gd etc.
    local stem
    stem=$(basename "$file" .gd)
    while IFS= read -r s; do suites+=("$s"); done < <(find "$SUITES_DIR" -name "*${stem}*_test.gd")
    # scene change -> integration suites that reference it
    if [[ "$file" == scenes/* && ${#suites[@]} -eq 0 ]]; then
      while IFS= read -r s; do suites+=("$s"); done < <(grep -rl "$(basename "$file")" "$SUITES_DIR" --include="*_test.gd" 2>/dev/null || true)
    fi
  fi

  if [[ ${#suites[@]} -eq 0 ]]; then
    echo "  (no focused suite found — run full: bash tools/run_all_tests.sh)"
    return 0
  fi
  for suite in "${suites[@]}"; do
    echo "  ▶ $suite"
    if godot --headless --audio-driver Dummy --path . --script "$suite" > /tmp/watch_suite.log 2>&1; then
      echo "    PASS ($(grep -c 'PASS:' /tmp/watch_suite.log) assertions)"
    else
      echo "    FAIL:"
      grep -E "FAIL|ERROR" /tmp/watch_suite.log | head -5
    fi
  done
}

command -v fswatch >/dev/null || { echo "fswatch not found: brew install fswatch"; exit 1; }
echo "watching .gd/.tscn (filter='${FILTER:-auto}') ... Ctrl-C to stop"
fswatch -0 -r --exclude "$IGNORE" -e ".*" -i "\\.gd$" -i "\\.tscn$" . | while read -r -d "" file; do
  run_checks "$file"
done
