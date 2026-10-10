# Builds the signed Android App Bundle for Google Play.
#
#   powershell -File tools\build_release.ps1
#
# Signing credentials come from %USERPROFILE%\.signing\ojos-curiosos\load-signing-env.ps1
# (outside the repo, never printed). JDK 17 is set only inside this process, so the
# user's JAVA_HOME is left alone. The first run needs internet for Gradle.
#
# Remember: version/code in export_presets.cfg must be higher on every upload to Play.

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$godot = $env:GODOT_BIN
if (-not $godot) {
    $godot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe'
}
$signing = Join-Path $env:USERPROFILE '.signing\ojos-curiosos\load-signing-env.ps1'
$output = Join-Path $repo 'build\ojos-curiosos-release.aab'

foreach ($required in @($godot, $signing, (Join-Path $repo 'android\build\build.gradle'))) {
    if (-not (Test-Path $required)) { Write-Host "Missing: $required"; exit 2 }
}

. $signing
$env:JAVA_HOME = 'C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot'
New-Item -ItemType Directory -Force (Join-Path $repo 'build') | Out-Null
if (Test-Path $output) { Remove-Item -LiteralPath $output -Force }

# Godot may print DONE and then hang; the process is stopped once the bundle exists.
$log = Join-Path $repo 'build\release.log'
$process = Start-Process -FilePath $godot -ArgumentList @('--headless', '--path', "`"$repo`"", '--export-release', '"Android Release"', "`"$output`"") `
    -RedirectStandardOutput $log -RedirectStandardError "$log.err" -PassThru -WindowStyle Hidden

$deadline = (Get-Date).AddMinutes(15)
while (-not $process.HasExited -and (Get-Date) -lt $deadline) {
    if ((Test-Path $output) -and ((Get-Item $output).Length -gt 1MB)) {
        Start-Sleep -Seconds 15  # let Godot finish signing and writing
        break
    }
    Start-Sleep -Seconds 5
}
if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }

# Free the Gradle daemon that Godot started.
& (Join-Path $repo 'android\build\gradlew.bat') --stop 2>$null | Out-Null

$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $null
if (-not (Test-Path $output)) { Write-Host "The bundle was not created. See $log"; exit 1 }
Write-Host ("Built {0} ({1} MB)" -f $output, [math]::Round((Get-Item $output).Length / 1MB, 1))
exit 0
