param(
    [switch]$Emulator
)

$ErrorActionPreference = "Stop"

# Keep every Antigravity terminal command inside the canonical WATM project.
Set-Location -LiteralPath $PSScriptRoot

if (-not (Test-Path ".\web")) {
    Write-Host "Creating Flutter platform files once..." -ForegroundColor Cyan
    flutter create . --project-name watm_app --platforms=android,ios,web
}

Write-Host "Getting dependencies..." -ForegroundColor Cyan
flutter pub get

if ($Emulator) {
    Write-Host "Starting WATM in Chrome against LOCAL EMULATORS." -ForegroundColor Green
    Write-Host "Run .\start-emulators.ps1 in another terminal first if you haven't." -ForegroundColor Yellow
    flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true
} else {
    Write-Host "Starting WATM in Chrome against PRODUCTION Firebase." -ForegroundColor Green
    Write-Host "For local testing that never touches real data, use: .\start-dev.ps1 -Emulator" -ForegroundColor Yellow
    flutter run -d chrome
}
