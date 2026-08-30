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

# ─── 2. Make PowerShell 7 the default SSH shell ───────────────────────────────
#
# Not prompted. Without this key sshd hands you cmd.exe, which is nobody's
# intent on a machine set up from these dotfiles -- none of the posh.d config
# loads there.
#
# pwsh is resolved on disk as well as on PATH: this runs elevated, and the
# elevated PATH does not always carry the per-user entries a pwsh install adds.
Write-Step "Setting the default SSH shell..."

$shell = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $shell) {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'PowerShell\7\pwsh.exe')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
    $shell = $candidates | Select-Object -First 1
}

if ($shell) {
    Write-Ok "Using PowerShell 7: $shell"
} else {
    $shell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    Write-Warn "PowerShell 7 not found; falling back to Windows PowerShell 5.1."
    Write-Warn "  Run the 'Shell (PowerShell 7)' task, then re-run this one."
}

# The key lives under HKLM:\SOFTWARE\OpenSSH, which does not exist until the
# capability has been installed at least once.
if (-not (Test-Path -LiteralPath 'HKLM:\SOFTWARE\OpenSSH')) {
    New-Item -Path 'HKLM:\SOFTWARE\OpenSSH' -Force | Out-Null
}
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell `
    -Value $shell -PropertyType String -Force | Out-Null
Write-Ok "Default SSH shell set to $shell"
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
    # Skipped rather than fatal. Assert-Winget dies, and dying here would throw
    # away a working SSH server over an optional extra -- which is also why the
    # menu no longer flags this task as needing winget at all.
    if (Test-Winget) {
        Reset-PackageFailures
        Install-Package -Id 'Microsoft.Sysinternals.Suite' -Name 'Sysinternals Suite' | Out-Null
        Install-Package -Id 'WinDirStat.WinDirStat'        -Name 'WinDirStat'         | Out-Null
        Show-PackageFailures | Out-Null
    } else {
        Write-Warn "winget not available; skipping the monitoring tools."
        Write-Warn "  The SSH server above is installed and running regardless."
    }
}
Write-Host ""

Write-Header "Server Tools Installation Complete"

Write-Info "SSH server status:"
Get-Service sshd | Format-Table -AutoSize Status, Name, DisplayName
