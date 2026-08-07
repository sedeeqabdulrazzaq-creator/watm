param(
    [switch]$Reset
)

$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

if ($Reset -and (Test-Path ".\.emulator-data")) {
    Write-Host "Clearing saved test data (-Reset)..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force ".\.emulator-data"
}

# --- Firewall (best-effort, needs Administrator; safe to skip otherwise) ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    try {
        $javaPath = (Get-Command java -ErrorAction Stop).Source
        if (-not (Get-NetFirewallRule -DisplayName "WATM Java Emulators" -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName "WATM Java Emulators" -Direction Inbound -Program $javaPath -Action Allow -Profile Any | Out-Null
            Write-Host "Firewall rule added for Java." -ForegroundColor Green
        }
    } catch { }
} else {
    Write-Host "Not running as Administrator - skipping firewall auto-fix (usually fine)." -ForegroundColor DarkGray
}

# --- Start emulators as a background job in THIS window ---
Write-Host ""
Write-Host "Starting Firebase emulators in the background..." -ForegroundColor Cyan
$emulatorJob = Start-Job -ScriptBlock {
    param($dir)
    Set-Location -LiteralPath $dir
    if (Test-Path ".\.emulator-data") {
        firebase emulators:start --import=".\.emulator-data" --export-on-exit=".\.emulator-data" 2>&1
    } else {
        firebase emulators:start --export-on-exit=".\.emulator-data" 2>&1
    }
} -ArgumentList $PSScriptRoot

# --- Wait until Auth (9099) and Firestore (8080) are actually accepting connections ---
Write-Host "Waiting for emulators to be ready (this can take 20-40s the first time)..." -ForegroundColor Cyan
$maxWaitSeconds = 90
$elapsed = 0
$ready = $false
while ($elapsed -lt $maxWaitSeconds) {
    if ($emulatorJob.State -eq 'Failed') {
        Write-Host ""
        Write-Host "The emulator job failed to start. Full output:" -ForegroundColor Red
        Receive-Job $emulatorJob
        exit 1
    }
    $authUp = Test-NetConnection -ComputerName "127.0.0.1" -Port 9099 -InformationLevel Quiet -WarningAction SilentlyContinue
    $firestoreUp = Test-NetConnection -ComputerName "127.0.0.1" -Port 8080 -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($authUp -and $firestoreUp) {
        $ready = $true
        break
    }
    Start-Sleep -Seconds 2
    $elapsed += 2
    Write-Host "." -NoNewline
}
Write-Host ""

if (-not $ready) {
    Write-Host "Emulators did not become ready within $maxWaitSeconds seconds." -ForegroundColor Red
    Write-Host "--- Emulator log so far ---" -ForegroundColor Yellow
    Receive-Job $emulatorJob
    Write-Host "---------------------------" -ForegroundColor Yellow
    Write-Host "Leaving the emulator job running. Press Ctrl+C to stop everything." -ForegroundColor Yellow
} else {
    Write-Host "Emulators are ready! Auth: 9099, Firestore: 8080, UI: http://127.0.0.1:4000" -ForegroundColor Green
    Write-Host ""
    Write-Host "Getting Flutter dependencies..." -ForegroundColor Cyan
    flutter pub get

    Write-Host "Launching the app connected to the emulators..." -ForegroundColor Green
    flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true
}

# --- Cleanup when flutter run exits or on Ctrl+C ---
Write-Host ""
Write-Host "Stopping emulators..." -ForegroundColor Cyan
Stop-Job $emulatorJob -ErrorAction SilentlyContinue | Out-Null
Receive-Job $emulatorJob -ErrorAction SilentlyContinue | Out-Null
Remove-Job $emulatorJob -Force -ErrorAction SilentlyContinue | Out-Null
