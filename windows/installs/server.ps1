# Server installation script for Windows
# Installs and configures the OpenSSH server
# Requires Administrator privileges
#
# The counterpart to linux/installs/server.sh, including its refusal to lock
# you out of SSH and its revert-on-bad-config behaviour.

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\common.ps1"

Assert-Admin
Write-Header "Server Tools Installation"

$SSHD_CONFIG = "$env:ProgramData\ssh\sshd_config"
# Windows keeps admin keys in a single machine-wide file rather than in each
# admin's ~/.ssh, and the shipped sshd_config has a `Match Group administrators`
# block pointing at it.
$ADMIN_KEYS = "$env:ProgramData\ssh\administrators_authorized_keys"
$USER_KEYS = "$HOME\.ssh\authorized_keys"

# ─── 1. Install and start the OpenSSH server ──────────────────────────────────

Write-Step "Installing OpenSSH Server..."

# Queried by wildcard: the capability name carries a version suffix
# (OpenSSH.Server~~~~0.0.1.0) that has changed across Windows releases.
$capability = Get-WindowsCapability -Online -Name 'OpenSSH.Server*' |
    Select-Object -First 1

if (-not $capability) {
    Invoke-Die "OpenSSH Server capability not available on this system."
}

if ($capability.State -eq 'Installed') {
    Write-Ok "OpenSSH Server already installed"
} else {
    Add-WindowsCapability -Online -Name $capability.Name | Out-Null
    Write-Ok "OpenSSH Server installed"
}

Set-Service -Name sshd -StartupType Automatic
if ((Get-Service sshd).Status -ne 'Running') {
    Start-Service sshd
}
Write-Ok "sshd enabled and running"

# The capability install normally creates this, but not on every Windows build.
if (-not (Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' `
        -DisplayName 'OpenSSH Server (sshd)' `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
    Write-Ok "Firewall rule created for TCP/22"
} else {
    Write-Ok "Firewall rule for TCP/22 already present"
}
Write-Host ""

# ─── 2. Optional: make PowerShell the default SSH shell ───────────────────────

$reply = Read-Host "Use PowerShell as the default shell for SSH sessions? (y/n)"
if ($reply -match '^[Yy]') {
    $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $pwsh) { $pwsh = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" }

    New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell `
        -Value $pwsh -PropertyType String -Force | Out-Null
    Write-Ok "Default SSH shell set to $pwsh"
}
Write-Host ""

# ─── 3. Optional: key-only authentication ─────────────────────────────────────

$reply = Read-Host "Configure SSH for key-only authentication? (recommended for servers) (y/n)"
if ($reply -match '^[Yy]') {

    # Refuse to lock the machine out: without an authorized key, disabling
    # password auth means nobody can log in over SSH at all.
    $hasKeys = @($ADMIN_KEYS, $USER_KEYS) | Where-Object {
        (Test-Path -LiteralPath $_) -and (Get-Item -LiteralPath $_).Length -gt 0
    }

    $proceed = $true
    if (-not $hasKeys) {
        Write-Warn "No keys found in either:"
        Write-Warn "  $ADMIN_KEYS"
        Write-Warn "  $USER_KEYS"
        Write-Warn "Disabling password authentication now would lock you out of SSH."
        $force = Read-Host "Continue anyway? (y/n)"
        if ($force -notmatch '^[Yy]') {
            Write-Info "Aborted SSH hardening. Add your public key first, then re-run."
            $proceed = $false
        }
    }

    if ($proceed) {
        $backup = "$SSHD_CONFIG.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item -LiteralPath $SSHD_CONFIG -Destination $backup -Force

        # Windows' sshd_config has no Include of an sshd_config.d directory, so
        # unlike the linux script this always edits the main file. Each pattern
        # matches the directive whether commented, set to yes, or set to no.
        $lines = Get-Content -LiteralPath $SSHD_CONFIG
        $settings = [ordered]@{
            'PasswordAuthentication'          = 'no'
            'PubkeyAuthentication'            = 'yes'
            'ChallengeResponseAuthentication' = 'no'
        }

        foreach ($key in $settings.Keys) {
            $value = $settings[$key]
            $pattern = "^[#\s]*$key\s+.*$"
            if ($lines -match $pattern) {
                $lines = $lines -replace $pattern, "$key $value"
            } else {
                $lines += "$key $value"
            }
        }

        Set-Content -LiteralPath $SSHD_CONFIG -Value $lines -Encoding ASCII
        Write-Info "Updated $SSHD_CONFIG (backup: $(Split-Path $backup -Leaf))"

        # sshd ignores administrators_authorized_keys unless only Administrators
        # and SYSTEM can write to it. This is the single most common reason for
        # "key auth silently does not work" on Windows.
        if (Test-Path -LiteralPath $ADMIN_KEYS) {
            icacls.exe $ADMIN_KEYS /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null
            Write-Ok "Reset ACL on administrators_authorized_keys"
        }

        # Validate before restarting, so a bad config cannot take sshd down.
        $sshd = "$env:SystemRoot\System32\OpenSSH\sshd.exe"
        & $sshd -t
        if ($LASTEXITCODE -eq 0) {
            Restart-Service sshd
            Write-Ok "SSH configured for key-only authentication"
            Write-Warn "NOTE: Keep this session open and verify you can log in from"
            Write-Warn "      another terminal before disconnecting!"
        } else {
            Copy-Item -LiteralPath $backup -Destination $SSHD_CONFIG -Force
            Invoke-Die "sshd config test failed; changes reverted and sshd left running"
        }
    }
}
Write-Host ""

# ─── 4. Optional: monitoring utilities ────────────────────────────────────────
# The htop / ncdu / net-tools equivalents.

$reply = Read-Host "Install additional monitoring tools? (Sysinternals Suite, WinDirStat) (y/n)"
if ($reply -match '^[Yy]') {
    Assert-Winget
    Reset-PackageFailures
    Install-Package -Id 'Microsoft.Sysinternals.Suite' -Name 'Sysinternals Suite' | Out-Null
    Install-Package -Id 'WinDirStat.WinDirStat'        -Name 'WinDirStat'         | Out-Null
    Show-PackageFailures | Out-Null
}
Write-Host ""

Write-Header "Server Tools Installation Complete"

Write-Info "SSH server status:"
Get-Service sshd | Format-Table -AutoSize Status, Name, DisplayName
