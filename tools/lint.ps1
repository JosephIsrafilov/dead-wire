# Lint production scripts on Windows, with the gdtoolkit grammar cache pinned
# inside the project.
#
# Why this exists: gdtoolkit pickles its Lark parser under
# %LOCALAPPDATA%\gdtoolkit\<version>. When that path is not writable the
# linter reports "Cannot open file ... Cannot create a file when that file
# already exists" once per file and then "Failure: 67 problems found". Those
# are not style problems. GDTOOLKIT_CACHE_DIR is honoured by the parser, so
# point it somewhere this run can write.
#
#   pwsh -File tools/lint.ps1
#   pwsh -File tools/lint.ps1 scripts/ui
param([string[]]$Paths = @("scripts/"))
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not $env:GDTOOLKIT_CACHE_DIR) {
  $env:GDTOOLKIT_CACHE_DIR = Join-Path $root ".cache/gdtoolkit"
}
New-Item -ItemType Directory -Force -Path $env:GDTOOLKIT_CACHE_DIR | Out-Null

$gdlint = Join-Path $root ".venv-tools/Scripts/gdlint.exe"
if (-not (Test-Path $gdlint)) {
  Write-Error "gdlint not found in .venv-tools; see AGENTS.md (Python tools go in .venv-tools)."
  exit 2
}
& $gdlint @Paths
exit $LASTEXITCODE
