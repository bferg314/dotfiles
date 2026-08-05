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
Install-Package -Id 'Python.Python.3.13'  -Name 'Python 3.13'    | Out-Null
Install-Package -Id 'OpenJS.NodeJS.LTS'   -Name 'Node.js LTS'    | Out-Null
Install-Package -Id 'Docker.DockerDesktop' -Name 'Docker Desktop' | Out-Null
Write-Host ""

# ─── Prompt and terminal ──────────────────────────────────────────────────────
#
# windows/posh.d/zprompt.ps1 initialises starship on every shell start, so
# without this the prompt errors on a fresh machine. The Nerd Font supplies the
# glyphs that the starship, wezterm and vim-airline configs all assume.

Install-Package -Id 'Starship.Starship'             -Name 'starship'                | Out-Null
Install-Package -Id 'DEVCOM.JetBrainsMonoNerdFont'  -Name 'JetBrainsMono Nerd Font' | Out-Null
Install-Package -Id 'wez.wezterm'                   -Name 'WezTerm'                 | Out-Null
Install-Package -Id 'AutoHotkey.AutoHotkey'         -Name 'AutoHotkey'              | Out-Null
Write-Host ""

# No zellij: it has no native Windows support, so there is deliberately no
# counterpart to the zellij section of linux/installs/base.sh.

# ─── Build tools ──────────────────────────────────────────────────────────────
#
# The build-essential equivalent. The C++ workload has to be requested through
# --override, since the base package installs the shell only.

Install-Package -Id 'Microsoft.VisualStudio.2022.BuildTools' -Name 'VS Build Tools' -ExtraArgs @(
    '--override',
    '--quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
) | Out-Null
Write-Host ""

# ─── Additional utilities ─────────────────────────────────────────────────────
# curl is omitted: curl.exe ships with Windows 10 1803+.

Install-Package -Id '7zip.7zip'            -Name '7-Zip' | Out-Null
Install-Package -Id 'jqlang.jq'            -Name 'jq'    | Out-Null
Install-Package -Id 'JernejSimoncic.Wget'  -Name 'wget'  | Out-Null
Write-Host ""

Write-Header "Base Tools Installation Complete"

$ok = Show-PackageFailures

Write-Warn "Some installs need a restart to finish - Docker Desktop and VS Build Tools in particular."
Write-Info "Authenticate the GitHub CLI when you are ready: gh auth login"
Write-Info "Set your terminal font to 'JetBrainsMono Nerd Font' so prompt glyphs render."
Write-Host ""

if (-not $ok) { exit 1 }
