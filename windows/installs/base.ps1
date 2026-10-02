# Base installation script for Windows
# Installs core development tools and utilities using winget
# Requires Administrator privileges
#
# The counterpart to linux/installs/base.sh and mac/installs/base.sh. What
# winget installs is listed in windows/packages.psd1; this script installs
# those, then handles what does not come from winget (the font, the PSFzf
# module, mise's runtimes, a few settings).

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\common.ps1"

$REPO_ROOT = (Resolve-Path "$PSScriptRoot\..\..").Path

Assert-Admin
Write-Header "Base Tools Installation"
Assert-Winget
Reset-PackageFailures

# ─── Packages (windows/packages.psd1) ─────────────────────────────────────────

$manifest = Import-PowerShellDataFile -Path (Join-Path $REPO_ROOT 'windows\packages.psd1')

$group = $null
foreach ($pkg in $manifest.Packages) {
    if ($pkg.Group -ne $group) {
        if ($group) { Write-Host "" }
        $group = $pkg.Group
    }
    $extra = if ($pkg.ExtraArgs) { [string[]]$pkg.ExtraArgs } else { @() }
    Install-Package -Id $pkg.Id -Name $pkg.Name -ExtraArgs $extra | Out-Null
}
Write-Host ""

# winget's PATH changes do not reach the running process, so git may not be
# callable yet on a first run. Pick it up from its known install location.
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    $gitBin = "$env:ProgramFiles\Git\cmd"
    if (Test-Path -LiteralPath $gitBin) { $env:Path = "$env:Path;$gitBin" }
}

# ─── Git identity ─────────────────────────────────────────────────────────────

if (Get-Command git -ErrorAction SilentlyContinue) {
    # Matches the interactive identity prompt in linux/installs/base.sh, and is
    # skipped entirely when both values are already set.
    $gitName = git config --global user.name
    $gitEmail = git config --global user.email

    if ([string]::IsNullOrWhiteSpace($gitName)) {
        $name = Read-Host "Enter your Git name"
        if (-not [string]::IsNullOrWhiteSpace($name)) { git config --global user.name "$name" }
    }
    if ([string]::IsNullOrWhiteSpace($gitEmail)) {
        $email = Read-Host "Enter your Git email"
        if (-not [string]::IsNullOrWhiteSpace($email)) { git config --global user.email "$email" }
    }

    Write-Info "Git identity: $(git config --global user.name) <$(git config --global user.email)>"

    # delta was installed above; now that it exists, make it git's pager.
    Add-GitDeltaInclude -RepoRoot $REPO_ROOT
} else {
    Write-Warn "git is not on PATH yet - open a new shell to configure your identity."
}
Write-Host ""

# ─── Terminal font ────────────────────────────────────────────────────────────
#
# Not available through winget - see Install-NerdFont in common.ps1. The
# starship prompt, eza's icons and vim-airline all assume it. No terminal
# emulator is installed: Windows Terminal ships with Windows 11, and just needs
# its font set to FiraCode Nerd Font Mono by hand.

if (-not (Install-NerdFont -Archive 'FiraCode' `
                           -FilePattern 'FiraCodeNerdFontMono-*.ttf' `
                           -Name 'FiraCode Nerd Font Mono')) {
    $global:DotfilesFailedPackages += 'FiraCode Nerd Font Mono'
}
Write-Host ""

# ─── PSFzf ────────────────────────────────────────────────────────────────────
#
# The PowerShell module behind the fzf key bindings in posh.d/tools.ps1
# (Ctrl-R, Ctrl-T, Alt-C). Windows PowerShell 5.1 and PowerShell 7 keep
# separate module folders, so it is installed for each edition present.

function Install-PSFzfModule {
    param([Parameter(Mandatory)][string]$Exe)
    $script = @'
$ErrorActionPreference = 'Stop'
if (Get-Module -ListAvailable PSFzf) { 'PRESENT'; return }
if ($PSVersionTable.PSEdition -eq 'Desktop') {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
}
Install-Module PSFzf -Scope CurrentUser -Force -AllowClobber
'INSTALLED'
'@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
    $previous = $ErrorActionPreference
    $previousModulePath = $env:PSModulePath
    $ErrorActionPreference = 'Continue'
    try {
        # A child inherits this process's PSModulePath, and PowerShell 7's
        # entries break Windows PowerShell 5.1 (and vice versa): the child
        # finds the other edition's PowerShellGet and Utility modules first.
        # With the variable unset, each edition builds its own default.
        Remove-Item Env:PSModulePath -ErrorAction SilentlyContinue
        $result = & $Exe -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1 | Select-Object -Last 1
    } finally {
        $env:PSModulePath = $previousModulePath
        $ErrorActionPreference = $previous
    }
    return "$result"
}

Write-Step "Installing the PSFzf PowerShell module..."
$editions = @(
    @{ Name = 'Windows PowerShell 5.1'; Exe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" }
    @{ Name = 'PowerShell 7';           Exe = (Get-Command pwsh -ErrorAction SilentlyContinue).Source }
)
foreach ($edition in $editions) {
    if (-not $edition.Exe -or -not (Test-Path -LiteralPath $edition.Exe)) { continue }
    switch -Wildcard (Install-PSFzfModule -Exe $edition.Exe) {
        'PRESENT'   { Write-Ok "PSFzf already installed ($($edition.Name))" }
        'INSTALLED' { Write-Ok "PSFzf installed ($($edition.Name))" }
        default {
            Write-Fail "PSFzf failed for $($edition.Name): $_"
            $global:DotfilesFailedPackages += "PSFzf ($($edition.Name))"
        }
    }
}
Write-Host ""

# ─── mise runtimes ────────────────────────────────────────────────────────────
#
# node, python, go, uv and ruff, pinned in shared/mise/config.toml. Replaces
# the winget Python, Node.js LTS and Go packages earlier versions installed.

if (-not (Install-MiseTools)) {
    $global:DotfilesFailedPackages += 'mise tools'
}
Write-Host ""

# ─── Go tools (gup) ───────────────────────────────────────────────────────────
#
# Go programs that only ship as source (folgit, ...), installed with
# `gup import` from shared/gup/gup.json into %USERPROFILE%\go\bin. Needs
# mise's go and gup, so it comes after the section above.

if (-not (Install-GoTools -RepoRoot $REPO_ROOT)) {
    $global:DotfilesFailedPackages += 'Go tools (gup)'
}
Write-Host ""

# Packages mise now provides, still installed from before. Never removed
# automatically: something else on the machine may depend on them.
$superseded = @($manifest.Superseded | Where-Object { Test-PackageInstalled -Id $_.Id })
if ($superseded.Count -gt 0) {
    Write-Warn "Installed by an older version of this repo, and now provided by mise:"
    foreach ($pkg in $superseded) {
        Write-Info "$($pkg.Name) -> $($pkg.By).  Remove with: winget uninstall --id $($pkg.Id)"
    }
    Write-Host ""
}

# ─── yazi's `file` command ────────────────────────────────────────────────────
#
# Windows ships no `file` command, which yazi shells out to for MIME
# detection -- without it, previews fall back to guessing by extension. Git
# for Windows bundles one at usr\bin\file.exe; YAZI_FILE_ONE is the environment
# variable yazi's own docs say to point at it. git.exe resolves to
# <GitRoot>\cmd or <GitRoot>\bin depending on how it was found, so file.exe is
# one level further up either way.
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) {
    $gitRoot = Split-Path (Split-Path $gitCmd.Source -Parent) -Parent
    $fileExe = Join-Path $gitRoot 'usr\bin\file.exe'
    if (Test-Path -LiteralPath $fileExe) {
        [Environment]::SetEnvironmentVariable('YAZI_FILE_ONE', $fileExe, 'User')
        $env:YAZI_FILE_ONE = $fileExe
        Write-Ok "YAZI_FILE_ONE set to $fileExe"
    } else {
        Write-Warn "No usr\bin\file.exe under $gitRoot; yazi's MIME-based previews may be limited"
    }
} else {
    Write-Warn "git not found on PATH; could not set YAZI_FILE_ONE for yazi's MIME detection"
}
Write-Host ""

Write-Header "Base Tools Installation Complete"

$ok = Show-PackageFailures

Write-Warn "Some installs need a restart to finish - Docker Desktop and VS Build Tools in particular."
Write-Info "Open a new terminal to pick up mise's shims, zoxide, fzf key bindings and PATH changes."
Write-Info "Authenticate the GitHub CLI when you are ready: gh auth login"
Write-Info "Check what mise manages: mise ls    Rust: rustup show"
Write-Info "Set your terminal font to 'FiraCode Nerd Font Mono' so prompt glyphs render."
Write-Host ""

if (-not $ok) { exit 1 }
