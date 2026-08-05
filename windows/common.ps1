# Shared helpers for the windows setup and install scripts.
# Dot-source this file, do not execute it:
#     . "$PSScriptRoot\common.ps1"
#
# The counterpart to linux/installs/common.sh. Helper names are kept parallel
# to that file (step/ok/warn/info/die) so the two platforms read the same way.

# ─── Console encoding ─────────────────────────────────────────────────────────
#
# The console defaults to a legacy OEM codepage (IBM437 here), which mangles the
# ✓ and box-drawing characters below into single garbage bytes. This affects
# only this process. Guarded because there is no console when output is
# redirected.
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
    # Not a console; leave the encoding alone.
}

# ─── Colors ───────────────────────────────────────────────────────────────────
#
# These deliberately avoid the names Write-Error and Write-Warning. The old
# scripts defined functions with those names, which shadowed the built-in
# cmdlets -- so Write-Error silently stopped raising errors and just printed
# text. Every name below was checked against Get-Command first.

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " $Text" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step { param([string]$Text) Write-Host $Text -ForegroundColor Yellow }
function Write-Ok   { param([string]$Text) Write-Host "✓ $Text" -ForegroundColor Green }
function Write-Warn { param([string]$Text) Write-Host "  ! $Text" -ForegroundColor Yellow }
function Write-Info { param([string]$Text) Write-Host "  → $Text" -ForegroundColor Blue }
function Write-Fail { param([string]$Text) Write-Host "✗ $Text" -ForegroundColor Red }

# The `die` equivalent: print and exit non-zero.
function Invoke-Die {
    param([string]$Text)
    Write-Fail $Text
    exit 1
}

# ─── Privileges ───────────────────────────────────────────────────────────────

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$identity).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Hard requirement, for the install scripts.
function Assert-Admin {
    if (-not (Test-Admin)) {
        Write-Host ""
        Write-Fail "This script requires Administrator privileges."
        Write-Warn "Please run PowerShell as Administrator and try again."
        Write-Host ""
        exit 1
    }
}

# Windows only allows unprivileged symlink creation when Developer Mode is on.
# Checking this up front lets New-DotfileLink explain itself once rather than
# failing mysteriously on every link.
function Test-DeveloperMode {
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
    $value = Get-ItemProperty -Path $key -Name AllowDevelopmentWithoutDevLicense -ErrorAction SilentlyContinue
    return ($null -ne $value -and $value.AllowDevelopmentWithoutDevLicense -eq 1)
}

function Test-CanSymlink { return ((Test-Admin) -or (Test-DeveloperMode)) }

# ─── Package manager ──────────────────────────────────────────────────────────
#
# The Linux side abstracts over pacman/dnf/apt because it has to. Windows has
# one target: winget, which ships with Windows 10 1809+ and Windows 11.

function Assert-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Invoke-Die @"
winget not found.
    winget ships with Windows 10 1809+ and Windows 11 as part of "App Installer".
    Install it from the Microsoft Store, or from:
    https://github.com/microsoft/winget-cli/releases
"@
    }
    $version = (winget --version) 2>$null
    Write-Info "winget $version"
    Write-Host ""
}

# Failures are collected rather than fatal: on Linux `set -e` aborts the run,
# but a single unavailable package should not stop the other twenty from
# installing. Show-PackageFailures prints the tally at the end.
$global:DotfilesFailedPackages = @()

function Reset-PackageFailures { $global:DotfilesFailedPackages = @() }

function Show-PackageFailures {
    if ($global:DotfilesFailedPackages.Count -eq 0) {
        return $true
    }
    Write-Host ""
    Write-Fail "$($global:DotfilesFailedPackages.Count) package(s) failed to install:"
    foreach ($p in $global:DotfilesFailedPackages) { Write-Warn $p }
    Write-Host ""
    return $false
}

function Test-PackageInstalled {
    param([Parameter(Mandatory)][string]$Id)

    # Native stderr can surface as a terminating error under
    # $ErrorActionPreference = 'Stop', so drop the preference for the call.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        winget list --id $Id --exact --accept-source-agreements 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    } finally {
        $ErrorActionPreference = $previous
    }
}

# The pkg_install equivalent. Idempotent: the winget list pre-check stands in
# for the `command -v` guards used throughout the linux installers.
function Install-Package {
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$Name = $Id,
        [string[]]$ExtraArgs = @()
    )

    Write-Step "Installing $Name..."

    if (Test-PackageInstalled -Id $Id) {
        Write-Ok "$Name already installed"
        return $true
    }

    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        # Out-Host, not bare output: winget's progress would otherwise land in
        # this function's output stream and be returned alongside the boolean,
        # making every caller's `if (Install-Package ...)` truthy.
        winget install --id $Id --exact --silent --disable-interactivity `
            --accept-package-agreements --accept-source-agreements @ExtraArgs | Out-Host
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }

    # winget returns HRESULTs, which land in $LASTEXITCODE as negative int32.
    # Mask back to unsigned so they can be compared against the documented
    # hex codes rather than hand-computed negative decimals.
    $unsigned = $code -band 0xFFFFFFFFL

    switch ($unsigned) {
        0          { Write-Ok "$Name installed"; return $true }
        0x8A150061 { Write-Ok "$Name already installed"; return $true }  # PACKAGE_ALREADY_INSTALLED
        0x8A15002B { Write-Ok "$Name already up to date"; return $true } # UPDATE_NOT_APPLICABLE
        0x8A150101 { Write-Ok "$Name installed"; Write-Warn "reboot required to finish"; return $true }
        0x8A150102 { Write-Ok "$Name installed"; Write-Warn "reboot required"; return $true }
        default {
            Write-Fail "$Name failed (winget exit 0x$('{0:X8}' -f $unsigned))"
            $global:DotfilesFailedPackages += $Name
            return $false
        }
    }
}

# ─── Linking ──────────────────────────────────────────────────────────────────

# The `ln -s -f` equivalent, with the fallbacks Windows forces on us.
#
# Symlinks need Administrator or Developer Mode. Where neither is available we
# fall back to a hard link (works unelevated, but only for files on the same
# volume) and finally to a plain copy, which is called out loudly because a
# copy stops tracking the repo.
function New-DotfileLink {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Target
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        Write-Warn "Source missing, skipping: $Source"
        return $false
    }
    $Source = (Resolve-Path -LiteralPath $Source).Path

    $targetDir = Split-Path $Target -Parent
    if ($targetDir -and -not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $name = Split-Path $Target -Leaf

    if (Test-Path -LiteralPath $Target) {
        $existing = Get-Item -LiteralPath $Target -Force

        if ($existing.LinkType -in @('SymbolicLink', 'HardLink')) {
            # .Target is a collection; for a hard link it lists the siblings.
            $points = @($existing.Target) | ForEach-Object {
                try { [System.IO.Path]::GetFullPath($_) } catch { $_ }
            }
            if ($points -contains $Source) {
                Write-Ok "$name already linked"
                return $true
            }
            Remove-Item -LiteralPath $Target -Force
        } else {
            # A real file the user may care about. Back it up before replacing,
            # matching the pattern in linux/installs/server.sh.
            $backup = "$Target.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Move-Item -LiteralPath $Target -Destination $backup -Force
            Write-Warn "Backed up existing $name to $(Split-Path $backup -Leaf)"
        }
    }

    if (Test-CanSymlink) {
        try {
            New-Item -ItemType SymbolicLink -Path $Target -Value $Source -Force -ErrorAction Stop | Out-Null
            Write-Ok "$name -> $Source"
            return $true
        } catch {
            Write-Warn "Symlink failed for ${name}: $($_.Exception.Message)"
        }
    }

    $sameVolume = [System.IO.Path]::GetPathRoot($Source) -eq [System.IO.Path]::GetPathRoot($Target)
    if ($sameVolume) {
        try {
            New-Item -ItemType HardLink -Path $Target -Value $Source -Force -ErrorAction Stop | Out-Null
            Write-Ok "$name -> $Source (hard link)"
            return $true
        } catch {
            Write-Warn "Hard link failed for ${name}: $($_.Exception.Message)"
        }
    }

    Copy-Item -LiteralPath $Source -Destination $Target -Force
    Write-Warn "$name COPIED, not linked - it will not track repo updates."
    Write-Warn "  Enable Developer Mode or re-run as Administrator to get a real link."
    return $true
}

# ─── Misc ─────────────────────────────────────────────────────────────────────

# Latest release tag for a GitHub repo, e.g. Get-GitHubLatestTag zellij-org/zellij
function Get-GitHubLatestTag {
    param([Parameter(Mandatory)][string]$Repo)
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -UseBasicParsing
        return $release.tag_name
    } catch {
        return $null
    }
}

# Download a file, creating the destination directory if needed.
function Get-FileFromWeb {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$OutFile
    )
    $dir = Split-Path $OutFile -Parent
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    # Some hosts still negotiate down to TLS 1.0 under Windows PowerShell 5.1.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
}
