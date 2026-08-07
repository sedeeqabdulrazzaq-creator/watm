$ErrorActionPreference = "Stop"

# Always run from the folder that contains this script, even when the script
# was started by its full path from another PowerShell location.
Set-Location -LiteralPath $PSScriptRoot

Write-Host "Preparing WATM Flutter MVP..." -ForegroundColor Cyan
Write-Host "Project folder: $PSScriptRoot" -ForegroundColor DarkGray

if (-not (Test-Path ".\pubspec.yaml")) {
    throw "pubspec.yaml was not found. Run this script from the WATM project."
}

flutter pub get
flutter analyze

flutter test --concurrency=1
if ($LASTEXITCODE -ne 0) {
    throw "Automated tests failed. Fix them before launching WATM."
}

Write-Host "Launching WATM in Chrome..." -ForegroundColor Green
flutter run -d chrome
