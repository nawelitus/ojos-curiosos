# Runs every headless test in tools/test_*.gd and fails if any of them fails.
# Usage (from the repo root):  powershell -File tools\run_tests.ps1
# Set GODOT_BIN to override the Godot console executable.

$ErrorActionPreference = 'Stop'

$godot = $env:GODOT_BIN
if (-not $godot) {
    $godot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path $godot)) {
    Write-Host "Godot executable not found: $godot"
    exit 2
}

$repo = Split-Path -Parent $PSScriptRoot
$tests = Get-ChildItem -Path $PSScriptRoot -Filter 'test_*.gd' | Sort-Object Name
$failed = @()

foreach ($test in $tests) {
    Write-Host "=== $($test.Name) ==="
    # --quit-after is mandatory: a script error in a -s script never quits by itself.
    # The network tests need several real seconds, hence the generous frame budget.
    $output = & $godot --headless --path $repo --quit-after 3000 -s "tools/$($test.Name)" | Out-String
    Write-Host $output.TrimEnd()
    # The exit code alone is not enough: a hung script ended by --quit-after exits with 0.
    if ($LASTEXITCODE -ne 0 -or $output -notmatch 'ALL TESTS PASSED' -or $output -match 'SCRIPT ERROR') {
        $failed += $test.Name
    }
}

Write-Host ''
if ($failed.Count -gt 0) {
    Write-Host "FAILED: $($failed -join ', ')"
    exit 1
}
Write-Host "OK: $($tests.Count) test file(s) passed"
exit 0
