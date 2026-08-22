# Base installation script for Windows
# Installs core development tools and utilities using winget
# Requires Administrator privileges
#
# The counterpart to linux/installs/base.sh.

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\common.ps1"

Assert-Admin
Write-Header "Base Tools Installation"
Assert-Winget
Reset-PackageFailures

# ─── Git ──────────────────────────────────────────────────────────────────────

Install-Package -Id 'Git.Git' -Name 'Git' | Out-Null

# winget's PATH changes do not reach the running process, so git may not be
# callable yet on a first run. Pick it up from its known install location.
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    $gitBin = "$env:ProgramFiles\Git\cmd"
    if (Test-Path -LiteralPath $gitBin) { $env:Path = "$env:Path;$gitBin" }
}

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
} else {
    Write-Warn "git is not on PATH yet - open a new shell to configure your identity."
}
Write-Host ""

# ─── Core tooling ─────────────────────────────────────────────────────────────

Install-Package -Id 'GitHub.cli'          -Name 'GitHub CLI'     | Out-Null
Install-Package -Id 'vim.vim'             -Name 'Vim'            | Out-Null
Install-Package -Id 'Python.Python.3.14'  -Name 'Python 3.14'    | Out-Null
Install-Package -Id 'OpenJS.NodeJS.LTS'   -Name 'Node.js LTS'    | Out-Null
Install-Package -Id 'Docker.DockerDesktop' -Name 'Docker Desktop' | Out-Null

# A GUI over winget/scoop/chocolatey/pip/npm, for the packages that are easier
# to browse for than to remember the id of.
#
# Published as MartiCliment.UniGetUI (and WingetUI before that) until the
# project moved to Devolutions - the old ids now resolve only to the
# pre-release channel, so pin the current one.
Install-Package -Id 'Devolutions.UniGetUI' -Name 'UniGetUI' | Out-Null
Write-Host ""

# ─── Prompt and terminal ──────────────────────────────────────────────────────
#
# windows/posh.d/zprompt.ps1 initialises starship on every shell start, so
# without this the prompt errors on a fresh machine. The Nerd Font supplies the
# glyphs that the starship and vim-airline configs both assume.
#
# No terminal emulator is installed here: this repo tracks no emulator config,
# so whichever one you use (Windows Terminal ships with Windows 11) just needs
# its font set to FiraCode Nerd Font Mono by hand.

Install-Package -Id 'Starship.Starship'     -Name 'starship'   | Out-Null
Install-Package -Id 'AutoHotkey.AutoHotkey' -Name 'AutoHotkey' | Out-Null

# Not available through winget - see Install-NerdFont in common.ps1.
if (-not (Install-NerdFont -Archive 'FiraCode' `
                           -FilePattern 'FiraCodeNerdFontMono-*.ttf' `
                           -Name 'FiraCode Nerd Font Mono')) {
    $global:DotfilesFailedPackages += 'FiraCode Nerd Font Mono'
}
Write-Host ""

# ─── Terminal multiplexer ─────────────────────────────────────────────────────
#
# The counterpart to the zellij section of linux/installs/base.sh. Upstream now
# ships an official x86_64-pc-windows-msvc MSI, which winget packages, so unlike
# the Linux side this needs no manual GitHub release fetch.

Install-Package -Id 'Zellij.Zellij' -Name 'zellij' | Out-Null
Write-Host ""

# ─── Build tools ──────────────────────────────────────────────────────────────
#
# The build-essential equivalent. The C++ workload has to be requested through
# --override, since the base package installs the shell only.

Install-Package -Id 'Microsoft.VisualStudio.2022.BuildTools' -Name 'VS Build Tools' -ExtraArgs @(
    '--override',
    '--quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
) | Out-Null
Write-Host ""

# ─── Rust ─────────────────────────────────────────────────────────────────────
#
# rustup rather than a packaged rustc, so toolchains are managed the same way on
# every platform. Installed after the build tools above on purpose: the default
# x86_64-pc-windows-msvc toolchain needs the MSVC linker, and rustup only warns
# about a missing one rather than failing.

Install-Package -Id 'Rustlang.Rustup' -Name 'rustup' | Out-Null
Write-Host ""

# ─── Additional utilities ─────────────────────────────────────────────────────
# curl is omitted: curl.exe ships with Windows 10 1803+.

Install-Package -Id '7zip.7zip'            -Name '7-Zip' | Out-Null
Install-Package -Id 'JernejSimoncic.Wget'  -Name 'wget'  | Out-Null
Write-Host ""

Write-Header "Base Tools Installation Complete"

$ok = Show-PackageFailures

Write-Warn "Some installs need a restart to finish - Docker Desktop and VS Build Tools in particular."
Write-Info "Authenticate the GitHub CLI when you are ready: gh auth login"
Write-Info "cargo and rustc land on PATH in a new shell: rustup show"
Write-Info "Set your terminal font to 'FiraCode Nerd Font Mono' so prompt glyphs render."
Write-Host ""

if (-not $ok) { exit 1 }
