#!/usr/bin/env bash
# Lint production scripts, with the gdtoolkit grammar cache pinned inside the
# project.
#
# Why this exists
# ---------------
# gdtoolkit builds its Lark parser once and pickles it under
# %LOCALAPPDATA%\gdtoolkit\<version> (or ~/.cache on Linux). When that path is
# not writable — a sandboxed agent shell, a locked-down CI box, a roaming
# profile — os.makedirs raises FileExistsError and the linter prints
#
#     Cannot open file '<every file>': Cannot create a file when that file
#     already exists
#
# once per file, then "Failure: 67 problems found". Those are NOT style
# problems, and reading them as such sends the next agent off rewriting clean
# code. GDTOOLKIT_CACHE_DIR is honoured by the parser, so point it at a
# directory the run can definitely write.
#
#   bash tools/lint.sh              # lint scripts/
#   bash tools/lint.sh scripts/ui   # lint one subtree
set -uo pipefail
cd "$(dirname "$0")/.."

CACHE_DIR="${GDTOOLKIT_CACHE_DIR:-.cache/gdtoolkit}"
export GDTOOLKIT_CACHE_DIR="$(cd "$(dirname "$CACHE_DIR")" 2>/dev/null && pwd || pwd)/$(basename "$CACHE_DIR")"
# gdlint is a native Windows binary, so it does not understand an MSYS path
# (/c/Users/...). Handed one, it cannot open its grammar cache and reports
# "Cannot open file '<every file>': Access is denied" once per file. Convert the
# cache path to the native spelling; on Linux and macOS this is a no-op.
if command -v cygpath >/dev/null 2>&1; then
  GDTOOLKIT_CACHE_DIR="$(cygpath -m "$GDTOOLKIT_CACHE_DIR" 2>/dev/null || echo "$GDTOOLKIT_CACHE_DIR")"
  export GDTOOLKIT_CACHE_DIR
fi
mkdir -p "$GDTOOLKIT_CACHE_DIR"

GDLINT=".venv-tools/Scripts/gdlint.exe"
[ -x "$GDLINT" ] || GDLINT=".venv-tools/bin/gdlint"
if [ ! -x "$GDLINT" ]; then
  echo "gdlint not found in .venv-tools; see AGENTS.md (Python tools go in .venv-tools)." >&2
  exit 2
fi

"$GDLINT" "${@:-scripts/}"
