# Tailscale installation script for Windows
# Installs the Tailscale client. Does not log in -- `tailscale up` is left to
# you, so this stays non-interactive.
#
# Run from windows\setup.ps1, or directly.

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\common.ps1"

Write-Header "Tailscale Installation"

Assert-Winget
Reset-PackageFailures

Install-Package -Id 'Tailscale.Tailscale' -Name 'Tailscale' | Out-Null

Write-Host ""
Write-Header "Tailscale Installation Complete"

# The installer adds tailscale.exe to PATH, but not to the PATH of this already
# running shell, so look it up on disk too before reporting it missing.
$tailscale = (Get-Command tailscale -ErrorAction SilentlyContinue).Source
if (-not $tailscale -and $env:ProgramFiles) {
    $fallback = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
    if (Test-Path -LiteralPath $fallback) { $tailscale = $fallback }
}

$ip = $null
if ($tailscale) {
    # `tailscale ip -4` only answers once the service is up and logged in, so
    # it doubles as the check for whether anything else is needed.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $ip = (& $tailscale ip -4 2>$null | Select-Object -First 1) } catch { }
    $ErrorActionPreference = $previous
}

if ($ip) {
    Write-Ok "This machine is on the tailnet as $ip"
} else {
    Write-Host "Not connected yet. Log in to join your tailnet:" -ForegroundColor Yellow
    Write-Host "  tailscale up"
    Write-Host ""
    Write-Info "That prints a URL to open in a browser. Open a new shell first if"
    Write-Info "'tailscale' is not yet on PATH."
}
Write-Host ""

Show-PackageFailures | Out-Null
