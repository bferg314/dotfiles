# Dotfiles setup script for Windows
# Requires PowerShell 5.1 or higher
#
# The counterpart to linux/setup.sh -- same menu shape, same guarantees:
# everything is idempotent and the update option will not discard your work
# without asking.

# $PSScriptRoot is set correctly even when this file is dot-sourced, unlike
# $MyInvocation.MyCommand.Path, which is empty in that case and used to bake an
# empty repo path into the user's profile.
$SCRIPT_DIR = $PSScriptRoot
$REPO_ROOT = Split-Path $SCRIPT_DIR -Parent

. "$SCRIPT_DIR\common.ps1"
. "$SCRIPT_DIR\menu.ps1"

$PROFILE_BEGIN = '# >>> dotfiles posh.d >>>'
$PROFILE_END = '# <<< dotfiles posh.d <<<'

# ─── PowerShell profiles ──────────────────────────────────────────────────────

# linux/setup.sh writes its sourcing block to both ~/.bashrc and ~/.zshrc. The
# Windows equivalent is Windows PowerShell 5.1 and PowerShell 7, which read
# from separate directories.
#
# These are the AllHosts profiles (profile.ps1), so the config also loads in
# the VS Code terminal and the ISE, not just the console host.
function Get-ProfilePaths {
    # GetFolderPath rather than "$HOME\Documents": Documents is frequently
    # redirected to OneDrive, and the hardcoded path silently misses it.
    $documents = [Environment]::GetFolderPath('MyDocuments')
    return @(
        (Join-Path $documents 'WindowsPowerShell\profile.ps1'),  # PowerShell 5.1
        (Join-Path $documents 'PowerShell\profile.ps1')          # PowerShell 7+
    )
}

# The pre-rewrite script appended an unmarked block to the host-specific
# profile ($PROFILE). Leaving it there would double-source posh.d, so strip it.
function Remove-LegacyProfileBlock {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return }
    $content = Get-Content -LiteralPath $Path -Raw
    if ($null -eq $content -or $content -notmatch 'Source all files from dotfiles posh\.d directory') { return }

    $legacy = '(?ms)^\s*#\s*Source all files from dotfiles posh\.d directory.*?^\}\s*$'
    if ($content -match $legacy) {
        $content = $content -replace $legacy, ''
        Set-Content -LiteralPath $Path -Value $content.TrimEnd() -Encoding UTF8
        Write-Ok "Removed legacy posh.d block from $(Split-Path $Path -Leaf)"
    } else {
        Write-Warn "Found an old posh.d block in $Path that could not be removed automatically."
        Write-Warn "  Delete it by hand or posh.d will be sourced twice."
    }
}

function Set-PoshProfile {
    param([Parameter(Mandatory)][string]$Path)

    # Backtick-escaped $ so these are written literally into the profile
    # rather than expanded here.
    $block = @"
$PROFILE_BEGIN
# Managed by dotfiles windows/setup.ps1 - changes inside this block are overwritten.
`$poshDPath = "$REPO_ROOT\windows\posh.d"
if (Test-Path -Path `$poshDPath) {
    # Sorted so zprompt.ps1 stays last, as its name intends.
    Get-ChildItem -Path `$poshDPath -File -Filter *.ps1 | Sort-Object Name | ForEach-Object {
        . `$_.FullName
    }
}
$PROFILE_END
"@

    $dir = Split-Path $Path -Parent
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $content = ''
    if (Test-Path -LiteralPath $Path) {
        $content = Get-Content -LiteralPath $Path -Raw
        if ($null -eq $content) { $content = '' }
    }

    $region = "(?ms)$([regex]::Escape($PROFILE_BEGIN)).*?$([regex]::Escape($PROFILE_END))"

    if ($content -match $region) {
        # Replaced rather than skipped: the old script's "already present" check
        # meant a stale repo path baked into the block could never be corrected
        # by re-running setup.
        $updated = [regex]::Replace($content, $region, { $block })
        if ($updated -eq $content) {
            Write-Ok "$(Split-Path $Path -Leaf) already up to date"
        } else {
            Set-Content -LiteralPath $Path -Value $updated -Encoding UTF8
            Write-Ok "Updated posh.d block in $Path"
        }
    } else {
        Add-Content -LiteralPath $Path -Value "`r`n$block" -Encoding UTF8
        Write-Ok "Added posh.d block to $Path"
    }
}

function Set-AllPoshProfiles {
    # Both host-specific profiles may carry the pre-rewrite block.
    foreach ($legacy in @($PROFILE.CurrentUserCurrentHost, $PROFILE.CurrentUserAllHosts)) {
        Remove-LegacyProfileBlock -Path $legacy
    }
    foreach ($path in Get-ProfilePaths) {
        Set-PoshProfile -Path $path
    }
}

# ─── Menu actions ─────────────────────────────────────────────────────────────

# Every version of windows\wezterm\.wezterm.lua this repo ever shipped, hashed
# with CR stripped (see Get-NormalisedFileHash). Used to recognise a config
# that came from here when the link back to the repo can no longer be seen.
$WEZTERM_CONFIG_HASHES = @(
    '310f135890ccb902ee3aa98210172b3d831337dfb3c71d9c7cbeeeb10fffd628'  # 9df876b, initial config
    '819f458b83d353b8f93337b50bed20986e670e664f1c2f0652de25b67a47b9ba'  # ed07861, windows parity
    'a44db385f890e81ddfcf921966a9a182bab3b275b10a4bd8567e4fc5f5313a87'  # dd34575, FiraCode Nerd Font Mono 16
    '792792a99db2681754c933ef43211dc7005009557b9aec7270a7ed514a79d324'  # ecfa486, font size 15
)

# wezterm was dropped from the repo, but a machine set up before that still has
# a ~\.wezterm.lua left over from it. Only configs that came from here are
# removed - one you wrote or edited yourself is left alone.
function Remove-LegacyWeztermLink {
    $path = "$HOME\.wezterm.lua"

    # Get-Item rather than Test-Path: a symlink whose target no longer exists -
    # exactly the case this cleans up - resolves to $false under Test-Path.
    $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return }
    if ($item.PSIsContainer) { return }

    $ours = $false

    if ($item.LinkType -in @('SymbolicLink', 'HardLink')) {
        $points = @($item.Target) | ForEach-Object { "$_" }
        if ($points | Where-Object { $_ -like "*\windows\wezterm\*" }) { $ours = $true }
    }

    # New-DotfileLink only makes a symlink when Developer Mode is on or the
    # shell is elevated; otherwise it falls back to a hard link, then to a plain
    # copy. Neither fallback can be traced back to the repo once the source is
    # gone - a copy never could, and a hard link reports an empty LinkType and
    # Target the moment its last sibling is deleted, which is precisely what
    # dropping wezterm did. Match the content instead so those are cleaned up
    # too, while anything you changed no longer hashes and so survives.
    if (-not $ours) {
        $ours = (Get-NormalisedFileHash $path) -in $WEZTERM_CONFIG_HASHES
    }

    if (-not $ours) { return }

    Remove-Item -LiteralPath $path -Force
    Write-Ok "Removed stale ~\.wezterm.lua (wezterm is no longer part of this repo)"
}

function Set-DotfileLinks {
    Write-Header "Creating Dotfile Links"

    if (-not (Test-CanSymlink)) {
        Write-Warn "Not elevated and Developer Mode is off - real symlinks are unavailable."
        Write-Warn "  Falling back to hard links or copies. See windows/README.md."
        Write-Host ""
    }

    # Out-Null on each: these return a status boolean that would otherwise
    # print a stray "True" between the progress lines.
    New-DotfileLink -Source "$SCRIPT_DIR\vim\.vimrc"         -Target "$HOME\_vimrc" | Out-Null
    New-DotfileLink -Source "$REPO_ROOT\starship\tokyo.toml" -Target "$HOME\.config\starship.toml" | Out-Null

    # Not ~\.config\zellij, the path the linux and mac scripts use. On Windows
    # zellij resolves its config through ProjectDirs::from("", "", "Zellij"),
    # which is %APPDATA%\Zellij\config -- the ~\.config convention is not part
    # of the lookup there.
    New-DotfileLink -Source "$SCRIPT_DIR\zellij\config.kdl" `
                    -Target "$env:APPDATA\Zellij\config\config.kdl" | Out-Null

    $startup = [Environment]::GetFolderPath('Startup')
    New-DotfileLink -Source "$SCRIPT_DIR\ahk\WindowsShortcuts.ahk" `
                    -Target (Join-Path $startup 'WindowsShortcuts.ahk') | Out-Null

    Remove-LegacyWeztermLink

    Write-Host ""
    Set-AllPoshProfiles

    Write-Host ""
    Write-Ok "Setup complete! Links created and PowerShell configured."
    Write-Info "Open a new shell, or run: . `$PROFILE"
    Write-Info "Then 'dotsetup' reopens this menu from anywhere."
}

function Install-VimPlug {
    Write-Header "Installing vim-plug"

    $url = 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
    $targets = @(
        "$HOME\vimfiles\autoload\plug.vim",
        "$env:LOCALAPPDATA\nvim-data\site\autoload\plug.vim"
    )

    foreach ($target in $targets) {
        try {
            Get-FileFromWeb -Uri $url -OutFile $target
            Write-Ok $target
        } catch {
            Write-Fail "Failed to download plug.vim to ${target}: $($_.Exception.Message)"
        }
    }

    Write-Host ""
    Write-Info "Open vim and run ':PlugInstall' to install your plugins."
}

# The "Install zsh" analogue: set up the better shell and point the config at it.
function Install-PowerShell7 {
    Write-Header "Installing PowerShell 7"

    Assert-Winget
    Reset-PackageFailures

    if (Install-Package -Id 'Microsoft.PowerShell' -Name 'PowerShell 7') {
        Write-Host ""
        Write-Step "Configuring the PowerShell 7 profile..."
        Set-AllPoshProfiles
        Write-Host ""
        Write-Info "Point your terminal at pwsh.exe to make it the default shell."
    }

    Show-PackageFailures | Out-Null
}

function Invoke-InstallScript {
    param([Parameter(Mandatory)][string]$Name)

    $script = Join-Path $SCRIPT_DIR "installs\$Name.ps1"
    if (-not (Test-Path -LiteralPath $script)) {
        Write-Fail "Install script not found: $script"
        return
    }

    & $script
    # The old script ignored this entirely, so a failed installer looked
    # identical to a successful one.
    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
        Write-Fail "$Name.ps1 exited with code $LASTEXITCODE"
    }
}

function Update-Dotfiles {
    Write-Header "Updating Dotfiles Repository"

    $branch = git -C $REPO_ROOT rev-parse --abbrev-ref HEAD
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "$REPO_ROOT is not a git repository"
        return
    }

    git -C $REPO_ROOT fetch origin

    # Fast-forward first. Only fall back to a destructive reset if the user
    # explicitly asks for it -- reset --hard + clean -ffd silently discards
    # local edits and untracked files. The old version did this unconditionally.
    git -C $REPO_ROOT pull --ff-only origin $branch
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Updated to latest origin/$branch"
        return
    }

    Write-Host ""
    Write-Host "Fast-forward failed - you have local commits or changes." -ForegroundColor Yellow
    git -C $REPO_ROOT status --short
    Write-Host ""
    Write-Host "A hard reset will PERMANENTLY DISCARD everything listed above." -ForegroundColor Red
    $confirm = Read-Host "Discard all local changes and match origin/$branch? (type 'yes' to confirm)"

    if ($confirm -eq 'yes') {
        git -C $REPO_ROOT reset --hard "origin/$branch"
        git -C $REPO_ROOT clean -ffd
        Write-Ok "Reset to origin/$branch"
    } else {
        Write-Info "Aborted. Repository left untouched."
    }
}

# ─── Status probes ────────────────────────────────────────────────────────────
#
# Each returns a New-MenuStatus for the menu's right-hand column. They must be
# cheap: they all run on every redraw.

# Names of the given commands that are not on PATH.
function Get-MissingCommands {
    param([string[]]$Names)
    return @($Names | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) })
}

# `winget list` once per menu session rather than `winget list --id X` per
# package: the per-package form shells out each time and would add seconds to
# every redraw. Cleared after a run so newly installed apps show up.
$script:WingetListCache = $null

function Get-WingetListText {
    if ($null -ne $script:WingetListCache) { return $script:WingetListCache }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        $script:WingetListCache = ''
        return $script:WingetListCache
    }
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $script:WingetListCache =
            (winget list --accept-source-agreements --disable-interactivity 2>&1 | Out-String)
    } catch {
        $script:WingetListCache = ''
    } finally {
        $ErrorActionPreference = $previous
    }
    return $script:WingetListCache
}

# Called by the menu engine after a run, so newly installed apps show up.
function Reset-MenuProbeCache { $script:WingetListCache = $null }

# Winget ids from the given list that do not appear in `winget list`.
function Get-MissingPackages {
    param([hashtable]$Packages)
    $text = Get-WingetListText
    if (-not $text) { return $null }   # cannot tell
    return @($Packages.Keys | Where-Object { $text -notlike "*$_*" } | ForEach-Object { $Packages[$_] })
}

function Get-LinksStatus {
    $missing = @()
    foreach ($path in Get-ProfilePaths) {
        if (-not (Test-Path -LiteralPath $path)) {
            $missing += Split-Path (Split-Path $path -Parent) -Leaf
            continue
        }
        $content = Get-Content -LiteralPath $path -Raw
        if ($null -eq $content -or $content -notmatch [regex]::Escape($PROFILE_BEGIN)) {
            $missing += Split-Path (Split-Path $path -Parent) -Leaf
        }
    }
    if ($missing.Count -gt 0) {
        return New-MenuStatus -State todo -Detail "posh.d not sourced by: $($missing -join ', ')"
    }
    if (-not (Test-Path -LiteralPath "$HOME\_vimrc")) {
        return New-MenuStatus -State todo -Detail 'profiles configured, ~\_vimrc missing'
    }
    return New-MenuStatus -State done -Detail 'linked'
}

function Get-VimPlugStatus {
    if (Test-Path -LiteralPath "$HOME\vimfiles\autoload\plug.vim") {
        return New-MenuStatus -State done -Detail 'installed'
    }
    return New-MenuStatus -State todo -Detail 'not installed'
}

function Get-PowerShell7Status {
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        return New-MenuStatus -State done -Detail "pwsh $((pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>$null))"
    }
    return New-MenuStatus -State todo -Detail 'not installed'
}

function Get-BaseStatus {
    $missing = Get-MissingCommands @('git', 'gh', 'node', 'rustup', 'zellij', 'starship')
    if ($missing.Count -gt 0) {
        return New-MenuStatus -State todo -Detail "missing: $($missing -join ', ')"
    }
    return New-MenuStatus -State done -Detail 'installed'
}

function Get-DesktopStatus {
    $missing = Get-MissingPackages @{
        'Valve.Steam'                = 'Steam'
        'Mozilla.Firefox'            = 'Firefox'
        'Microsoft.VisualStudioCode' = 'VS Code'
        'Obsidian.Obsidian'          = 'Obsidian'
        'Spotify.Spotify'            = 'Spotify'
        'Discord.Discord'            = 'Discord'
        'Bitwarden.Bitwarden'        = 'Bitwarden'
    }
    if ($null -eq $missing) { return New-MenuStatus -State unknown -Detail 'winget unavailable' }
    if ($missing.Count -gt 0) {
        return New-MenuStatus -State todo -Detail "missing: $($missing -join ', ')"
    }
    return New-MenuStatus -State done -Detail 'installed'
}

function Get-ServerStatus {
    $svc = Get-Service -Name sshd -ErrorAction SilentlyContinue
    if (-not $svc) { return New-MenuStatus -State todo -Detail 'OpenSSH server not installed' }
    if ($svc.Status -eq 'Running') { return New-MenuStatus -State done -Detail 'sshd running' }
    return New-MenuStatus -State todo -Detail "sshd $($svc.Status)"
}

function Get-TailscaleStatus {
    # Checked on disk as well as on PATH: the installer adds tailscale.exe to
    # PATH, but not to the PATH of an already running shell, so a fresh install
    # would otherwise still read as missing until you open a new one.
    $tailscale = (Get-Command tailscale -ErrorAction SilentlyContinue).Source
    if (-not $tailscale -and $env:ProgramFiles) {
        $fallback = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
        if (Test-Path -LiteralPath $fallback) { $tailscale = $fallback }
    }
    if (-not $tailscale) { return New-MenuStatus -State todo -Detail 'not installed' }

    # `tailscale ip -4` only answers once the service is up and logged in, so
    # one call covers both "not running" and "not logged in" -- Doctor is where
    # the full `tailscale status` belongs. Deliberately not Get-WingetListText:
    # a winget entry says installed, not connected.
    $ip = $null
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $ip = (& $tailscale ip -4 2>$null | Select-Object -First 1) } catch { }
    $ErrorActionPreference = $previous

    if ($ip) { return New-MenuStatus -State done -Detail "up ($ip)" }
    return New-MenuStatus -State todo -Detail 'installed, not connected'
}

function Get-UpdateStatus {
    $branch = git -C $REPO_ROOT rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -ne 0) { return New-MenuStatus -State unknown -Detail 'not a git repository' }
    # Exit status alone is not enough: an empty answer here would render as
    # "<blank> commit(s) behind origin/" rather than saying it cannot tell.
    if (-not $branch) { return New-MenuStatus -State unknown -Detail 'could not determine the current branch' }
    $behind = git -C $REPO_ROOT rev-list --count "HEAD..origin/$branch" 2>$null
    if ($LASTEXITCODE -ne 0) { return New-MenuStatus -State unknown -Detail "no origin/$branch to compare against" }
    if (-not $behind) { return New-MenuStatus -State unknown -Detail "could not compare against origin/$branch" }
    if ($behind -eq '0') { return New-MenuStatus -State done -Detail "up to date with origin/$branch" }
    return New-MenuStatus -State todo -Detail "$behind commit(s) behind origin/$branch"
}

# ─── Doctor ───────────────────────────────────────────────────────────────────

function Show-Doctor {
    Write-Host "Environment"
    Write-Info "os:       $(Get-MenuPlatformLine)"
    Write-Info "repo:     $REPO_ROOT"
    Write-Info "symlinks: $(if (Test-Admin) { 'yes (elevated)' } elseif (Test-DeveloperMode) { 'yes (Developer Mode)' } else { 'no - hard links or copies will be used' })"
    Write-Info "winget:   $(if (Get-Command winget -ErrorAction SilentlyContinue) { (winget --version) } else { 'not installed' })"
    Write-Info "gum:      $(if (Get-Command gum -ErrorAction SilentlyContinue) { (gum --version) } else { 'not installed (menu uses the numbered fallback)' })"
    Write-Host ""

    Write-Host "Git identity"
    $name = git config --global user.name 2>$null
    $email = git config --global user.email 2>$null
    Write-Info "name:     $(if ($name) { $name } else { '(unset)' })"
    Write-Info "email:    $(if ($email) { $email } else { '(unset)' })"
    Write-Host ""

    Write-Host "PowerShell profiles"
    foreach ($path in Get-ProfilePaths) {
        if (Test-Path -LiteralPath $path) {
            Write-Ok $path
        } else {
            Write-Warn "$path (missing)"
        }
    }
    Write-Host ""

    Write-Host "Tasks"
    Update-MenuStatus
    foreach ($task in $script:MenuTasks) {
        if ($task.State -eq 'none') { continue }
        if ($task.State -eq 'done') {
            Write-Ok "$($task.Label): $($task.Detail)"
        } else {
            Write-Warn "$($task.Label): $($task.Detail)"
        }
    }
    Write-Host ""

    Show-PackageFailures | Out-Null
}

# ─── Task table ───────────────────────────────────────────────────────────────
#
# Same ids, groups and run order as linux/tasks.sh and mac/tasks.sh, so the
# three menus read the same. The differences are rows, not forked code: Windows
# has a `shell` task for PowerShell 7 where Linux has none, and no mDNS row.

Add-MenuTask -Id 'workstation' -Label 'Workstation preset'  -Group presets   -Order 1 `
    -Expand @('links', 'shell', 'vimplug', 'base', 'desktop')
Add-MenuTask -Id 'serverpre'   -Label 'Server preset'       -Group presets   -Order 2 `
    -Expand @('links', 'shell', 'base', 'server')

Add-MenuTask -Id 'links'   -Label 'Link dotfiles'        -Group configure -Order 10 `
    -Handler { Set-DotfileLinks } -Probe { Get-LinksStatus }
Add-MenuTask -Id 'shell'   -Label 'Shell (PowerShell 7)' -Group configure -Order 15 `
    -Handler { Install-PowerShell7 } -Probe { Get-PowerShell7Status } -Flags @('net', 'winget')
Add-MenuTask -Id 'vimplug' -Label 'Editor plugins'       -Group configure -Order 20 `
    -Handler { Install-VimPlug } -Probe { Get-VimPlugStatus } -Flags @('net')

Add-MenuTask -Id 'base'    -Label 'Base tools'           -Group install   -Order 30 `
    -Handler { Invoke-InstallScript -Name 'base' } -Probe { Get-BaseStatus } -Flags @('net', 'winget', 'admin')
Add-MenuTask -Id 'desktop' -Label 'Desktop apps'         -Group install   -Order 40 `
    -Handler { Invoke-InstallScript -Name 'desktop' } -Probe { Get-DesktopStatus } -Flags @('net', 'winget', 'admin', 'optin')
Add-MenuTask -Id 'server'  -Label 'Server tools (SSH)'   -Group install   -Order 50 `
    -Handler { Invoke-InstallScript -Name 'server' } -Probe { Get-ServerStatus } -Flags @('net', 'winget', 'admin', 'optin')
Add-MenuTask -Id 'tailscale' -Label 'Tailscale (VPN)'     -Group install   -Order 55 `
    -Handler { Invoke-InstallScript -Name 'tailscale' } -Probe { Get-TailscaleStatus } -Flags @('net', 'winget', 'admin', 'optin')

Add-MenuTask -Id 'update'  -Label 'Update from git'      -Group maintain  -Order 70 `
    -Handler { Update-Dotfiles } -Probe { Get-UpdateStatus } -Flags @('net')
Add-MenuTask -Id 'doctor'  -Label 'Doctor (full report)' -Group maintain  -Order 80 `
    -Handler { Show-Doctor }

# ─── Go ───────────────────────────────────────────────────────────────────────

Invoke-Menu
