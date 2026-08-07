$ErrorActionPreference = "Stop"

# Keep every Antigravity terminal command inside the canonical WATM project.
Set-Location -LiteralPath $PSScriptRoot

Write-Host "Starting local Firebase emulators (Auth + Firestore + Functions)." -ForegroundColor Cyan
Write-Host "Test accounts and circles created here stay on this machine only" -ForegroundColor Cyan
Write-Host "-- production data is never touched. Emulator UI: http://localhost:4000" -ForegroundColor Cyan
Write-Host ""

# Pre-emptively allow Java (which hosts the Auth/Firestore emulators) through
# Windows Firewall. Without this, the browser sometimes gets
# ERR_CONNECTION_REFUSED on 127.0.0.1:9099 / :8080 because Windows silently
# blocked the first inbound connection attempt and never showed a prompt (or
# the prompt was missed). This is a no-op if the rule already exists, and is
# skipped with a warning if this terminal isn't running as Administrator.
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    try {
        $javaPath = (Get-Command java -ErrorAction Stop).Source
        if (-not (Get-NetFirewallRule -DisplayName "WATM Java Emulators" -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -DisplayName "WATM Java Emulators" -Direction Inbound -Program $javaPath -Action Allow -Profile Any | Out-Null
            Write-Host "Added a firewall rule for Java so the emulators can accept connections." -ForegroundColor Green
        }
    } catch {
        Write-Host "Could not add a firewall rule automatically (java not found yet?). Continuing anyway." -ForegroundColor Yellow
    }
} else {
    Write-Host "Tip: re-run this script as Administrator once to let it auto-configure the firewall." -ForegroundColor Yellow
    Write-Host "If localhost:9099 / :8080 refuse connections later, that firewall prompt is why." -ForegroundColor Yellow
}
Write-Host ""

Write-Host "Keep this terminal open. In another terminal, run:" -ForegroundColor Yellow
Write-Host "  .\start-dev.ps1 -Emulator" -ForegroundColor Yellow
Write-Host ""

if (-not (Test-Path ".\.emulator-data")) {
    firebase emulators:start --export-on-exit=".\.emulator-data"
} else {
    firebase emulators:start --import=".\.emulator-data" --export-on-exit=".\.emulator-data"
}
