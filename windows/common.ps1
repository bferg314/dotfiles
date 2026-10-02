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

# Path to winget.exe, or $null when it genuinely is not installed.
#
# Get-Command alone is not enough. winget ships as an App Execution Alias in
# %LOCALAPPDATA%\Microsoft\WindowsApps, and that directory is on the *user's*
# PATH -- so an elevated shell, or one launched with a stale environment, can
# report winget missing on a machine that plainly has it. Fall back to the alias
# and then to the MSIX package's own install location before believing it.
$script:WingetPath = $null
# How it was found, for Doctor -- "winget unavailable" with no further detail
# has cost enough time already.
$script:WingetSource = 'not looked for yet'

function Get-WingetPath {
    if ($script:WingetPath) { return $script:WingetPath }

    $found = (Get-Command winget -ErrorAction SilentlyContinue).Source
    if ($found) {
        $script:WingetSource = 'on PATH'
    }

    if (-not $found -and $env:LOCALAPPDATA) {
        $alias = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
        if (Test-Path -LiteralPath $alias) {
            $found = $alias
            $script:WingetSource = 'App Execution Alias (not on this shell PATH)'
        }
    }

    if (-not $found -and $env:ProgramFiles) {
        # The MSIX payload itself. Deliberately NOT Get-AppxPackage: Appx is a
        # Windows PowerShell module, so under PowerShell 7 it throws rather than
        # answering -- the same trap as the DISM cmdlets, and useless here since
        # PowerShell 7 is exactly the shell that needs this fallback.
        $pattern = Join-Path $env:ProgramFiles 'WindowsApps\Microsoft.DesktopAppInstaller_*_*__8wekyb3d8bbwe\winget.exe'
        $candidate = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending | Select-Object -First 1
        if ($candidate) {
            $found = $candidate.FullName
            $script:WingetSource = 'WindowsApps package payload'
        }
    }

    if (-not $found) { $script:WingetSource = 'not found' }

    $script:WingetPath = $found
    return $script:WingetPath
}

function Get-WingetSource {
    Get-WingetPath | Out-Null
    return $script:WingetSource
}

function Test-Winget { return [bool](Get-WingetPath) }

function Assert-Winget {
    $winget = Get-WingetPath
    if (-not $winget) {
        Invoke-Die @"
winget not found.
    winget ships with Windows 10 1809+ and Windows 11 as part of "App Installer".
    Install it from the Microsoft Store, or from:
    https://github.com/microsoft/winget-cli/releases
"@
    }
    $version = (& $winget --version) 2>$null
    Write-Info "winget $version"
    Write-Host ""
}

# Rebuild this session's PATH from the machine and user values.
#
# An installer writes the new entry to the registry, not to the environment of
# an already running shell -- so without this, `Get-Command gum` still fails
# right after gum was installed, and the menu's status column reports the thing
# it just installed as missing.
function Update-SessionPath {
    $entries = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)

    foreach ($scope in @($env:Path,
                         [Environment]::GetEnvironmentVariable('Path', 'Machine'),
                         [Environment]::GetEnvironmentVariable('Path', 'User'))) {
        foreach ($entry in ($scope -split ';')) {
            if ($entry -and $seen.Add($entry.TrimEnd('\'))) { $entries.Add($entry) }
        }
    }

    $env:Path = $entries -join ';'
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
        $winget = Get-WingetPath
        if (-not $winget) { return $false }
        & $winget list --id $Id --exact --accept-source-agreements 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    } finally {
        $ErrorActionPreference = $previous
    }
}

# Start-Process takes one command line, not an argv array -- PowerShell joins
# -ArgumentList with spaces and quotes nothing -- so anything containing
# whitespace has to be quoted here. Follows the CommandLineToArgvW rules the
# other side will parse with: backslashes are only special before a quote or at
# the end of a quoted run, where they must be doubled.
function ConvertTo-NativeArg {
    param([string]$Value)
    if ($Value -notmatch '[\s"]') { return $Value }
    return '"' + (($Value -replace '(\\+)(?="|$)', '$1$1') -replace '"', '\"') + '"'
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
        Update-SessionPath
        Write-Ok "$Name already installed"
        return $true
    }

    # Start-Process rather than a pipeline. winget animates its spinner and
    # progress bar by rewinding with a bare carriage return, but PowerShell's
    # native-command reader treats a lone CR as a line terminator - so through
    # a pipe every frame of the animation lands on its own line and scrolls a
    # column of / - \ | down the screen. Handing winget the console directly
    # lets it redraw in place, and keeps its output out of this function's
    # output stream, where it would be returned alongside the boolean and make
    # every caller's `if (Install-Package ...)` truthy.
    $argv = @('install', '--id', $Id, '--exact', '--silent', '--disable-interactivity',
              '--accept-package-agreements', '--accept-source-agreements') + $ExtraArgs
    $proc = Start-Process -FilePath (Get-WingetPath) -NoNewWindow -Wait -PassThru `
        -ArgumentList (($argv | ForEach-Object { ConvertTo-NativeArg $_ }) -join ' ')
    $code = $proc.ExitCode

    # winget returns HRESULTs, which arrive as negative int32. Mask back to
    # unsigned so they can be compared against the documented hex codes rather
    # than hand-computed negative decimals.
    $unsigned = $code -band 0xFFFFFFFFL

    switch ($unsigned) {
        0          { Update-SessionPath; Write-Ok "$Name installed"; return $true }
        0x8A150061 { Update-SessionPath; Write-Ok "$Name already installed"; return $true }  # PACKAGE_ALREADY_INSTALLED
        0x8A15002B { Update-SessionPath; Write-Ok "$Name already up to date"; return $true } # UPDATE_NOT_APPLICABLE
        0x8A150101 { Write-Ok "$Name installed"; Write-Warn "reboot required to finish"; return $true }
        0x8A150102 { Write-Ok "$Name installed"; Write-Warn "reboot required"; return $true }
        default {
            Write-Fail "$Name failed (winget exit 0x$('{0:X8}' -f $unsigned))"
            $global:DotfilesFailedPackages += $Name
            return $false
        }
    }
}

# ─── Windows capabilities (optional features) ─────────────────────────────────

# Install a Windows capability by name pattern, e.g. 'OpenSSH.Server*'.
# Echoes one of: Installed, AlreadyInstalled, NotAvailable, or "Failed: <why>".
#
# The DISM cmdlets behind Get-/Add-WindowsCapability are backed by COM
# interfaces registered only for Windows PowerShell, so under PowerShell 7 they
# do not merely misbehave -- Get-WindowsCapability throws "Class not
# registered" before doing anything. That matters here more than most places:
# this repo installs PowerShell 7, points the terminal at it, and now makes it
# the SSH shell, so pwsh is the *likeliest* shell for these scripts to run
# under. The work is handed to powershell.exe 5.1 in that case.
#
# The child reports through a RESULT: marker rather than by exit code or last
# line of output, so stray DISM progress or warnings cannot be mistaken for the
# answer.
function Install-WindowsCapabilityByPattern {
    param([Parameter(Mandatory)][string]$Pattern)

    $work = {
        param($Pattern)
        $ErrorActionPreference = 'Stop'
        try {
            $cap = Get-WindowsCapability -Online -Name $Pattern | Select-Object -First 1
            if (-not $cap) { "RESULT:NotAvailable"; return }
            if ($cap.State -eq 'Installed') { "RESULT:AlreadyInstalled"; return }
            Add-WindowsCapability -Online -Name $cap.Name | Out-Null
            "RESULT:Installed"
        } catch {
            "RESULT:Failed: $($_.Exception.Message)"
        }
    }

    $output = $null
    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        # Already in Windows PowerShell: run it here rather than paying for a
        # second process, and keep the pre-PowerShell-7 behaviour untouched.
        $output = & $work $Pattern
    } else {
        $ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        if (-not (Test-Path -LiteralPath $ps)) {
            return "Failed: PowerShell 7 cannot service Windows capabilities, and Windows PowerShell 5.1 was not found at $ps"
        }
        # -EncodedCommand so the scriptblock crosses the process boundary
        # without any quoting to get wrong.
        $command = "& { $($work.ToString()) } '$($Pattern -replace "'", "''")'"
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        $output = & $ps -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1
    }

    $line = @($output) | Where-Object { "$_" -like 'RESULT:*' } | Select-Object -First 1
    if (-not $line) { return "Failed: no result from the capability install ($output)" }
    return ("$line" -replace '^RESULT:', '')
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

# SHA256 of a file's content with every CR stripped, so a CRLF working copy
# hashes the same as the LF bytes stored in git. core.autocrlf rewrites line
# endings on checkout, so hashing the file as-is would not match a reference
# taken from the repository. Returns $null if the file cannot be read.
function Get-NormalisedFileHash {
    param([Parameter(Mandatory)][string]$Path)

    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
    } catch {
        return $null
    }

    $lf = [byte[]]@($bytes | Where-Object { $_ -ne 13 })

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($lf)) -replace '-', '').ToLower()
    } finally {
        $sha.Dispose()
    }
}

# A GitHub token, if one can be found without prompting: $env:GH_TOKEN or
# $env:GITHUB_TOKEN, else the gh CLI's own login. Unauthenticated API calls are
# limited to 60 an hour per IP; authenticated ones get 5,000. The counterpart
# to github_token in lib/download.sh.
function Get-GitHubToken {
    if ($env:GH_TOKEN) { return $env:GH_TOKEN }
    if ($env:GITHUB_TOKEN) { return $env:GITHUB_TOKEN }
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $token = gh auth token 2>$null
            if ($LASTEXITCODE -eq 0 -and $token) { return "$token".Trim() }
        } finally {
            $ErrorActionPreference = $previous
        }
    }
    return $null
}

# Latest release tag for a GitHub repo, e.g. Get-GitHubLatestTag zellij-org/zellij
function Get-GitHubLatestTag {
    param([Parameter(Mandatory)][string]$Repo)
    $headers = @{ Accept = 'application/vnd.github+json' }
    $token = Get-GitHubToken
    if ($token) { $headers['Authorization'] = "Bearer $token" }
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" `
                                     -Headers $headers -UseBasicParsing
        return $release.tag_name
    } catch {
        return $null
    }
}

# ─── Checksums ────────────────────────────────────────────────────────────────

# The checksum for <Name> from a `sha256sum`-style listing at <Uri> -- the
# checksums.txt / SHA-256.txt files most projects publish next to their
# release assets. $null when the listing or the entry is missing.
function Get-ChecksumFromList {
    param([Parameter(Mandatory)][string]$Uri, [Parameter(Mandatory)][string]$Name)
    try {
        $listing = (Invoke-WebRequest -Uri $Uri -UseBasicParsing).Content
    } catch {
        return $null
    }
    if ($listing -is [byte[]]) { $listing = [System.Text.Encoding]::UTF8.GetString($listing) }
    return (ConvertFrom-ChecksumList -Text $listing -Name $Name)
}

# The parsing half of Get-ChecksumFromList. `<hash>  <name>` per line; a `*`
# before the name marks binary mode in sha256sum output and is ignored.
function ConvertFrom-ChecksumList {
    param([AllowEmptyString()][string]$Text, [Parameter(Mandatory)][string]$Name)
    foreach ($line in ($Text -split "`n")) {
        $parts = $line.Trim() -split '\s+', 2
        if ($parts.Count -eq 2 -and $parts[1].TrimStart('*') -eq $Name) { return $parts[0].ToLower() }
    }
    return $null
}

# True when <Path> hashes to <Expected>. A missing <Expected> -- a checksum that
# could not be fetched -- is a failure, not a pass. The counterpart to
# verify_sha256 in lib/download.sh.
function Test-FileSha256 {
    param([Parameter(Mandatory)][string]$Path, [string]$Expected)
    $leaf = Split-Path $Path -Leaf
    if (-not $Expected) {
        Write-Fail "No published checksum found for $leaf; refusing to install it"
        return $false
    }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $Expected.ToLower()) {
        Write-Fail "Checksum mismatch for $leaf"
        Write-Warn "expected $Expected"
        Write-Warn "got      $actual"
        return $false
    }
    Write-Info "sha256 verified: $leaf"
    return $true
}

# ─── Git ──────────────────────────────────────────────────────────────────────

# Forward slashes: git config treats a backslash as an escape character, and
# git for Windows reads C:/Users/... paths fine.
function ConvertTo-GitPath { param([string]$Path) return ($Path -replace '\\', '/') }

function Test-GitInclude {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $false }
    $want = ConvertTo-GitPath $Path
    $have = @(git config --global --get-all include.path 2>$null)
    return [bool]($have | Where-Object { (ConvertTo-GitPath $_) -eq $want })
}

# Add `[include] path = <Path>` to ~/.gitconfig, once. The counterpart to
# dot_git_include in lib/shared.sh: ~/.gitconfig keeps your identity and
# anything machine-specific.
#
# The include goes at the TOP of the file, not the end. git applies config in
# file order and the last value wins, so an include appended at the end (what
# `git config --add include.path` does) would override every setting you had
# already made in ~/.gitconfig. At the top, everything of yours comes after it
# and wins.
function Add-GitInclude {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Warn "git not installed; skipping the $(Split-Path $Path -Leaf) include"
        return
    }
    if (Test-GitInclude -Path $Path) {
        Write-Ok "~/.gitconfig already includes $(Split-Path $Path -Leaf)"
        return
    }

    $config = if ($env:GIT_CONFIG_GLOBAL) { $env:GIT_CONFIG_GLOBAL } else { Join-Path $HOME '.gitconfig' }
    $existing = if (Test-Path -LiteralPath $config) { [System.IO.File]::ReadAllText($config) } else { '' }
    # git skips a BOM, but nothing else here writes one, so neither does this.
    [System.IO.File]::WriteAllText($config, "[include]`n`tpath = $(ConvertTo-GitPath $Path)`n$existing",
                                   (New-Object System.Text.UTF8Encoding $false))
    Write-Ok "~/.gitconfig now includes $(Split-Path $Path -Leaf) (your own settings still win)"
}

# delta's pager settings only once delta exists: git fails outright when
# core.pager is not on PATH.
function Add-GitDeltaInclude {
    param([Parameter(Mandatory)][string]$RepoRoot)
    if (Get-Command delta -ErrorAction SilentlyContinue) {
        Add-GitInclude -Path (Join-Path $RepoRoot 'shared\git\delta.gitconfig')
    } else {
        Write-Info "delta not installed yet; its git pager settings are added by Base tools"
    }
}

# ─── mise ─────────────────────────────────────────────────────────────────────

function Get-MiseShimsPath { return (Join-Path $env:LOCALAPPDATA 'mise\shims') }

# Put <Entry> on the user PATH (persistently) and this session's PATH, once.
# -Prepend puts it ahead of everything else, for entries that must win.
function Add-UserPathEntry {
    param([Parameter(Mandatory)][string]$Entry, [switch]$Prepend)
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (($userPath -split ';') -notcontains $Entry) {
        $updated = if ($Prepend) { "$Entry;$userPath" } elseif ($userPath) { "$userPath;$Entry" } else { $Entry }
        [Environment]::SetEnvironmentVariable('Path', $updated.TrimEnd(';'), 'User')
        Write-Ok "Added $Entry to the user PATH"
    }
    if (($env:Path -split ';') -notcontains $Entry) {
        $env:Path = if ($Prepend) { "$Entry;$env:Path" } else { "$env:Path;$Entry" }
    }
}

# ─── Go tools (gup) ───────────────────────────────────────────────────────────

# Where `go install` puts binaries. mise is configured not to set GOBIN
# (go.set_gobin = false in shared/mise/config.toml), so this is Go's own
# default unless you have set GOBIN or GOPATH yourself. The counterpart to
# go_bin_dir in lib/shared.sh.
function Get-GoBinPath {
    if ($env:GOBIN) { return $env:GOBIN }
    $gopath = if ($env:GOPATH) { ($env:GOPATH -split ';')[0] } else { Join-Path $HOME 'go' }
    return (Join-Path $gopath 'bin')
}

# Binary names listed in shared/gup/gup.json.
function Get-GoToolNames {
    param([Parameter(Mandatory)][string]$RepoRoot)
    $manifest = Join-Path $RepoRoot 'shared\gup\gup.json'
    if (-not (Test-Path -LiteralPath $manifest)) { return @() }
    return @((Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json).packages | ForEach-Object { $_.name })
}

# Names from gup.json that are not in the Go bin dir yet.
function Get-MissingGoTools {
    param([Parameter(Mandatory)][string]$RepoRoot)
    $bin = Get-GoBinPath
    return @(Get-GoToolNames -RepoRoot $RepoRoot |
             Where-Object { -not (Test-Path -LiteralPath (Join-Path $bin "$_.exe")) })
}

# Install (or update to latest) every tool in shared/gup/gup.json with
# `gup import`, and put the Go bin dir on PATH. Through `mise exec` so mise's
# go and gup are found even in a session whose PATH predates the shims.
function Install-GoTools {
    param([Parameter(Mandatory)][string]$RepoRoot)
    $mise = Get-Command mise -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $mise) {
        Write-Fail "mise not found on PATH; skipping the Go tools"
        return $false
    }

    Add-UserPathEntry -Entry (Get-GoBinPath)

    Write-Step "Installing Go tools from shared/gup/gup.json (folgit, ...)..."
    $manifest = Join-Path $RepoRoot 'shared\gup\gup.json'
    # Start-Process, as in Install-MiseTools: output to the console, not into
    # this function's return value. The path is quoted for Start-Process's
    # single command line.
    $proc = Start-Process -FilePath $mise.Source -NoNewWindow -Wait -PassThru `
        -ArgumentList "exec -- gup import --file $(ConvertTo-NativeArg $manifest)"
    if ($proc.ExitCode -ne 0) {
        Write-Fail "Some Go tools failed to install; re-run 'gup import --file shared\gup\gup.json'"
        return $false
    }
    Write-Ok "Go tools installed to $(Get-GoBinPath)"
    return $true
}

# Install everything in ~/.config/mise/config.toml, and put mise's shims on the
# user PATH ahead of anything else there, so node/python/go resolve to mise's
# copies in every program -- not only in shells that load posh.d.
function Install-MiseTools {
    $mise = Get-Command mise -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $mise) {
        Write-Fail "mise not found on PATH; open a new shell and run Base tools again"
        return $false
    }

    $config = Join-Path $HOME '.config\mise\config.toml'
    if (-not (Test-Path -LiteralPath $config)) {
        Write-Warn "$config is not linked yet - run Link dotfiles, then Base tools again"
        return $false
    }

    Add-UserPathEntry -Entry (Get-MiseShimsPath) -Prepend

    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        # The config was written by this repo, so it is trusted -- without this
        # mise asks interactively the first time it sees the file.
        & $mise.Source trust --quiet $config *> $null

        Write-Step "Installing mise tools (node, python, go, uv, ruff)..."
        # Start-Process for the same reasons as in Install-Package: mise's
        # progress display redraws in place, and its output stays out of this
        # function's return value.
        $proc = Start-Process -FilePath $mise.Source -ArgumentList 'install --yes' -NoNewWindow -Wait -PassThru
        if ($proc.ExitCode -ne 0) {
            Write-Fail "Some mise tools failed to install; re-run 'mise install' to retry"
            return $false
        }
        & $mise.Source upgrade --yes *> $null
        & $mise.Source reshim *> $null
        Write-Ok "mise tools installed"
        & $mise.Source ls --current | ForEach-Object { Write-Host "    $_" }
        return $true
    } finally {
        $ErrorActionPreference = $previous
    }
}

# ─── Fonts ────────────────────────────────────────────────────────────────────

# Install a Nerd Font from the upstream GitHub release.
#
# winget carries exactly one Nerd Font (DEVCOM.JetBrainsMonoNerdFont), so
# anything else has to come from ryanoasis/nerd-fonts directly. This is the
# same "not in the package repos, fetch the release" approach that
# linux/installs/base.sh uses for zellij.
#
# Installs per-user (LOCALAPPDATA + HKCU), which needs no elevation.
function Install-NerdFont {
    param(
        # Release asset base name, e.g. FiraCode -> FiraCode.zip
        [Parameter(Mandatory)][string]$Archive,
        # Only files matching this are installed, so the Mono variant does not
        # drag in the proportional and non-Mono families alongside it.
        [Parameter(Mandatory)][string]$FilePattern,
        [Parameter(Mandatory)][string]$Name
    )

    Write-Step "Installing $Name..."

    $fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    $registry = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'

    if ((Test-Path -LiteralPath $fontDir) -and
        (Get-ChildItem -LiteralPath $fontDir -Filter $FilePattern -ErrorAction SilentlyContinue)) {
        Write-Ok "$Name already installed"
        return $true
    }

    $tag = Get-GitHubLatestTag -Repo 'ryanoasis/nerd-fonts'
    if (-not $tag) {
        Write-Fail "Could not determine the latest nerd-fonts release (GitHub API rate limit?)"
        return $false
    }
    Write-Info "nerd-fonts $tag"

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "nerdfont-$([System.IO.Path]::GetRandomFileName())"
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null

    try {
        $zip = Join-Path $tmp "$Archive.zip"
        $release = "https://github.com/ryanoasis/nerd-fonts/releases/download/$tag"
        Get-FileFromWeb -Uri "$release/$Archive.zip" -OutFile $zip
        if (-not (Test-FileSha256 -Path $zip -Expected (Get-ChecksumFromList -Uri "$release/SHA-256.txt" -Name "$Archive.zip"))) {
            return $false
        }

        $extract = Join-Path $tmp 'extract'
        # Expand-Archive rather than a COM shell call: no UI, and it is present
        # in PowerShell 5.1 without any module install.
        Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force

        $fonts = Get-ChildItem -LiteralPath $extract -Filter $FilePattern
        if (-not $fonts) {
            Write-Fail "No files matching $FilePattern in $Archive.zip"
            return $false
        }

        if (-not (Test-Path -LiteralPath $fontDir)) {
            New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
        }
        if (-not (Test-Path -LiteralPath $registry)) {
            New-Item -Path $registry -Force | Out-Null
        }

        foreach ($font in $fonts) {
            $dest = Join-Path $fontDir $font.Name
            Copy-Item -LiteralPath $font.FullName -Destination $dest -Force

            # A per-user font is only visible to applications once it is
            # registered, and the value must hold the full path (machine-wide
            # entries under HKLM use the bare filename instead).
            $face = [System.IO.Path]::GetFileNameWithoutExtension($font.Name)
            New-ItemProperty -Path $registry -Name "$face (TrueType)" `
                             -Value $dest -PropertyType String -Force | Out-Null
        }

        Write-Ok "$Name installed ($($fonts.Count) faces)"
        return $true
    } catch {
        Write-Fail "$Name failed: $($_.Exception.Message)"
        return $false
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
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
