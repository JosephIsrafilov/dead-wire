$ErrorActionPreference = "Stop"
$projectDir = (Resolve-Path (Join-Path $PSScriptRoot ".."))

function Resolve-Godot {
    if ($env:GODOT_BIN) {
        $explicit = Resolve-Path -LiteralPath $env:GODOT_BIN -ErrorAction SilentlyContinue
        if ($explicit) { return $explicit.Path }
        throw "GODOT_BIN does not point to an executable: $env:GODOT_BIN"
    }

    foreach ($name in @("godot4.exe", "godot.exe", "godot4", "godot")) {
        $command = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { return $command.Source }
    }

    $candidates = @(
        (Join-Path $env:USERPROFILE "Desktop\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"),
        (Join-Path $env:USERPROFILE "Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe")
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    throw "Godot binary not found. Set GODOT_BIN to the console executable path."
}

$godotBin = Resolve-Godot
$passedSuites = 0
$failedSuites = 0
$totalAssertions = 0
$failedNames = @()

$suites = Get-ChildItem (Join-Path $projectDir "tests") -Recurse -Filter "*_test.gd" |
    Sort-Object FullName
foreach ($suite in $suites) {
    $relative = $suite.FullName.Substring($projectDir.Path.Length + 1).Replace("\", "/")
    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = (& $godotBin --headless --editor --path $projectDir.Path --script "res://$relative" 2>&1 | Out-String)
    } finally {
        $ErrorActionPreference = $oldErrorActionPreference
    }
    $exitCode = $LASTEXITCODE
    $assertions = ([regex]::Matches($output, "PASS:")).Count
    if ($exitCode -eq 0 -and $output -notmatch "FAIL") {
        $passedSuites++
        $totalAssertions += $assertions
        "OK   {0,-58} {1,4} assertions" -f $relative, $assertions
    } else {
        $failedSuites++
        $failedNames += $relative
        "FAIL {0,-58} exit {1}" -f $relative, $exitCode
        ($output -split "`r?`n" | Where-Object { $_ -match "fail|error" } | Select-Object -First 8) |
            ForEach-Object { "       $_" }
    }
}

"-------------------------------------------------------------------------"
"suites passed: $passedSuites   failed: $failedSuites   assertions: $totalAssertions"
if ($failedSuites -ne 0) {
    "failed suites: $($failedNames -join ' ')"
    exit 1
}
