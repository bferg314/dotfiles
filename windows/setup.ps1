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

# ─── Shared configs ───────────────────────────────────────────────────────────

# Neovim's config dir on Windows: %LOCALAPPDATA%\nvim, not ~\.config\nvim.
$NVIM_CONFIG_DIR = Join-Path $env:LOCALAPPDATA 'nvim'

# On Windows zellij resolves its config through ProjectDirs::from("", "",
# "Zellij"), which is %APPDATA%\Zellij\config -- the ~\.config convention the
# Linux and macOS scripts use is not part of the lookup there.
$ZELLIJ_CONFIG = Join-Path $env:APPDATA 'Zellij\config\config.kdl'
$ZELLIJ_MARKER = '// Generated by dotfiles windows/setup.ps1 from shared/zellij/config.kdl - edit that file, not this one.'

# git's global ignore file. Copied, not linked -- see Write-GitIgnore.
$GIT_IGNORE = Join-Path $HOME '.config\git\ignore'
$GIT_IGNORE_MARKER = '# Copied by dotfiles windows/setup.ps1 from shared/git/ignore - edit that file, then re-run Link dotfiles.'

# Everything under shared/ that is linked as-is: the same files Linux and macOS
# link (lib/shared.sh, dot_link_shared), at their Windows locations. The zellij
# config and the git ignore file are written as copies instead; see below.
function Get-SharedLinks {
    $shared = Join-Path $REPO_ROOT 'shared'
    return @(
        @{ Source = "$shared\vim\.vimrc";          Target = "$HOME\_vimrc" }
        @{ Source = "$shared\starship\tokyo.toml"; Target = "$HOME\.config\starship.toml" }
        @{ Source = "$shared\mise\config.toml";    Target = "$HOME\.config\mise\config.toml" }
    )
}

# ─── Generated copies ─────────────────────────────────────────────────────────
#
# A file that is written from the repo rather than linked to it. The first line
# is a marker naming its source, which is how a later run tells its own copy
# (rewritten in place) from a file you wrote yourself (backed up first).

# Write <Content> to <Path> unless it is already there. A link left at <Path>
# by an older version of this script is replaced; a file without <Marker> on
# its first line is yours, and is backed up before being replaced.
function Write-GeneratedFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Marker,
        [Parameter(Mandatory)][string]$Label
    )
    $Content = $Content -replace "`r`n", "`n"
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue

    if ($item) {
        if ($item.LinkType) {
            Remove-Item -LiteralPath $Path -Force
        } else {
            $existing = [System.IO.File]::ReadAllText($Path) -replace "`r`n", "`n"
            if ($existing -eq $Content) {
                Write-Ok "$Label already up to date"
                return
            }
            if (-not $existing.StartsWith($Marker)) {
                $backup = "$Path.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Move-Item -LiteralPath $Path -Destination $backup -Force
                Write-Warn "Backed up existing $Label to $(Split-Path $backup -Leaf)"
            }
        }
    }

    $null = New-Item -ItemType Directory -Force -Path (Split-Path $Path)
    # No BOM: neither zellij's KDL parser nor git's ignore parser expects one.
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding $false))
    Write-Ok "$Label written from the repo"
}

# True when <Path> is a real file holding exactly <Content>. A link -- what an
# older version of this script left -- counts as not current, so the menu asks
# for Link dotfiles to run again and replace it.
function Test-GeneratedFileCurrent {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Content)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item -or $item.LinkType) { return $false }
    $existing = [System.IO.File]::ReadAllText($Path) -replace "`r`n", "`n"
    return ($existing -eq ($Content -replace "`r`n", "`n"))
}

# What the generated zellij config should contain: the shared file, plus the
# default_shell line Windows needs. Without it zellij falls back to cmd.exe
# even when launched from PowerShell (zellij-org/zellij#4897). pwsh is resolved
# from PATH, which the PowerShell 7 install puts it on.
function Get-ZellijConfigContent {
    $shared = Get-Content -LiteralPath "$REPO_ROOT\shared\zellij\config.kdl" -Raw
    return "$ZELLIJ_MARKER`n`n$($shared.TrimEnd())`n`n// Windows only: start PowerShell 7 rather than cmd.exe.`ndefault_shell `"pwsh`"`n"
}

# Written as a copy because zellij has no include mechanism to add the
# Windows-only default_shell to the shared file. Re-run Link dotfiles after
# editing shared/zellij/config.kdl.
function Write-ZellijConfig {
    Write-GeneratedFile -Path $ZELLIJ_CONFIG -Content (Get-ZellijConfigContent) `
                        -Marker $ZELLIJ_MARKER -Label 'config.kdl (zellij)'
}

function Test-ZellijConfigCurrent {
    return (Test-GeneratedFileCurrent -Path $ZELLIJ_CONFIG -Content (Get-ZellijConfigContent))
}

function Get-GitIgnoreContent {
    $shared = Get-Content -LiteralPath "$REPO_ROOT\shared\git\ignore" -Raw
    return "$GIT_IGNORE_MARKER`n`n$($shared.TrimEnd())`n"
}

# Written as a copy, not a symlink, because git for Windows treats a global
# ignore file that is a *dangling* symlink as fatal -- "cannot use ... as an
# exclude file" -- for every git command in every repository. The link
# dangles whenever this checkout is on a commit without shared/git/ignore
# (switching to an older branch of this repo), and with git itself broken
# there is no way back short of overriding core.excludesFile by hand. A
# missing plain file is harmless, and a copy can never dangle. Linux and
# macOS keep the symlink: their git skips a dangling one silently.
# Re-run Link dotfiles after editing shared/git/ignore.
function Write-GitIgnore {
    Write-GeneratedFile -Path $GIT_IGNORE -Content (Get-GitIgnoreContent) `
                        -Marker $GIT_IGNORE_MARKER -Label 'ignore (git)'
}

function Test-GitIgnoreCurrent {
    return (Test-GeneratedFileCurrent -Path $GIT_IGNORE -Content (Get-GitIgnoreContent))
}

# True when <Target> is a link (or the hard-link / copy fallback) to <Source>.
function Test-DotfileLinked {
    param([Parameter(Mandatory)][string]$Source, [Parameter(Mandatory)][string]$Target)
    $item = Get-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $false }
    if ($item.LinkType -eq 'SymbolicLink') {
        $points = @($item.Target) | ForEach-Object { try { [System.IO.Path]::GetFullPath($_) } catch { $_ } }
        return ($points -contains [System.IO.Path]::GetFullPath($Source))
    }
    # Hard link or copy: same content is as good as linked for a status hint.
    return ((Get-NormalisedFileHash $Target) -eq (Get-NormalisedFileHash $Source))
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
    foreach ($link in Get-SharedLinks) {
        New-DotfileLink -Source $link.Source -Target $link.Target | Out-Null
    }

    # Neovim reads the same vimrc through init.vim. An init.lua of your own
    # takes precedence and Neovim refuses to start with both, so leave it be.
    if (Test-Path -LiteralPath (Join-Path $NVIM_CONFIG_DIR 'init.lua')) {
        Write-Info "$NVIM_CONFIG_DIR\init.lua exists; leaving your Neovim config alone"
    } else {
        New-DotfileLink -Source "$REPO_ROOT\shared\nvim\init.vim" `
                        -Target (Join-Path $NVIM_CONFIG_DIR 'init.vim') | Out-Null
    }

    Write-ZellijConfig
    Write-GitIgnore

    $startup = [Environment]::GetFolderPath('Startup')
    New-DotfileLink -Source "$SCRIPT_DIR\ahk\WindowsShortcuts.ahk" `
                    -Target (Join-Path $startup 'WindowsShortcuts.ahk') | Out-Null

    Remove-LegacyWeztermLink

    Write-Host ""
    Add-GitInclude -Path "$REPO_ROOT\shared\git\gitconfig"
    Add-GitDeltaInclude -RepoRoot $REPO_ROOT

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

# Lists your GitHub repos, skips anything already checked out under ~\code,
# and lets you pick which of the rest to clone there.
function Invoke-CloneRepos {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Warn "GitHub CLI (gh) not found - run 'Base tools' first"
        return
    }
    if (-not (Get-Command gum -ErrorAction SilentlyContinue)) {
        Write-Warn "gum not found - run 'Base tools' first"
        return
    }
    gh auth status *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "gh is not logged in - run 'gh auth login' first"
        return
    }

    $codeDir = Join-Path $HOME 'code'
    New-Item -ItemType Directory -Path $codeDir -Force | Out-Null

    Write-Step "Fetching your GitHub repositories..."
    $allRepos = gh repo list --limit 1000 --json name --jq '.[].name'
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Could not list repositories"
        return
    }

    $uncloned = @($allRepos | Where-Object { $_ -and -not (Test-Path (Join-Path $codeDir $_)) })

    if ($uncloned.Count -eq 0) {
        Write-Ok "All repositories are already cloned in $codeDir"
        return
    }

    # Passed as arguments rather than piped in, so gum is not left taking
    # options from stdin and keystrokes from the console at once.
    $selected = & gum choose --no-limit --height 15 --header "space toggles - enter clones - esc cancels" @uncloned
    if (-not $selected) {
        Write-Info "Nothing selected."
        return
    }

    $failures = 0
    foreach ($repo in @($selected)) {
        if (-not $repo) { continue }
        Write-Step "Cloning $repo..."
        gh repo clone $repo (Join-Path $codeDir $repo)
        if ($LASTEXITCODE -ne 0) { $failures++ }
    }

    if ($failures -eq 0) {
        Write-Ok "Cloned into $codeDir"
    } else {
        Write-Warn "$failures repo(s) failed to clone"
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

# Installed-program display names, read from the Uninstall keys once per menu
# session.
#
# Deliberately not `winget list`. That made a *status hint* depend on winget
# being resolvable, so a shell that could not find winget reported "?" -- no
# information at all -- about apps that were plainly installed. The registry
# answers without winget, without shelling out, and without parsing localised
# table output. winget is still what installs things; it is just no longer
# needed to look at them.
$script:InstalledNamesCache = $null

function Get-InstalledDisplayNames {
    if ($null -ne $script:InstalledNamesCache) { return $script:InstalledNamesCache }

    # Per-machine 64-bit, per-machine 32-bit, and per-user: Spotify and Discord
    # install per-user, Steam and Firefox per-machine, VS Code either way.
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )

    $names = New-Object System.Collections.Generic.List[string]
    foreach ($root in $roots) {
        foreach ($key in (Get-ChildItem -Path $root -ErrorAction SilentlyContinue)) {
            $name = (Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue).DisplayName
            if ($name) { $names.Add($name) }
        }
    }

    $script:InstalledNamesCache = $names.ToArray()
    return $script:InstalledNamesCache
}

# Called by the menu engine after a run, so newly installed apps show up.
function Reset-MenuProbeCache { $script:InstalledNamesCache = $null }

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
    $unlinked = @(Get-SharedLinks | Where-Object { -not (Test-DotfileLinked -Source $_.Source -Target $_.Target) } |
                  ForEach-Object { Split-Path $_.Target -Leaf })
    if (-not (Test-ZellijConfigCurrent)) { $unlinked += 'zellij config.kdl' }
    if (-not (Test-GitIgnoreCurrent)) { $unlinked += 'git ignore' }
    if (-not (Test-GitInclude -Path "$REPO_ROOT\shared\git\gitconfig")) { $unlinked += 'gitconfig include' }
    if ($unlinked.Count -gt 0) {
        return New-MenuStatus -State todo -Detail "not linked: $($unlinked -join ', ')"
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
    $missing = @(Get-MissingCommands @('git', 'gh', 'mise', 'rustup', 'zellij', 'starship', 'gum', 'yazi', 'eza', 'delta'))

    # mise's own tools (node, python, uv...) are asked of mise rather than
    # looked for on PATH: a shell opened before Base tools ran has no shims on
    # its PATH yet, and would report all of them missing.
    $mise = Get-Command mise -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($mise) {
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $missing += @(& $mise.Source ls --missing --no-header 2>$null |
                          ForEach-Object { ("$_".Trim() -split '\s+')[0] } | Where-Object { $_ })
        } finally {
            $ErrorActionPreference = $previous
        }
    }

    # The `go install` tools from shared/gup/gup.json, looked for in ~\go\bin.
    $missing += @(Get-MissingGoTools -RepoRoot $REPO_ROOT)

    if ($missing.Count -gt 0) {
        return New-MenuStatus -State todo -Detail "missing: $($missing -join ', ')"
    }
    return New-MenuStatus -State done -Detail 'installed'
}

function Get-DesktopStatus {
    # Matched on the display name the installer registers, which is not the
    # winget id.
    $apps = [ordered]@{
        'Steam'     = 'Steam*'
        'Firefox'   = 'Mozilla Firefox*'
        'VS Code'   = 'Microsoft Visual Studio Code*'
        'Obsidian'  = 'Obsidian*'
        'Spotify'   = 'Spotify*'
        'Discord'   = 'Discord*'
        'Bitwarden' = 'Bitwarden*'
    }

    $installed = Get-InstalledDisplayNames
    $missing = @()
    foreach ($app in $apps.Keys) {
        $pattern = $apps[$app]
        $hit = $false
        foreach ($name in $installed) {
            if ($name -like $pattern) { $hit = $true; break }
        }
        if (-not $hit) { $missing += $app }
    }

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
    if (Test-Winget) {
        Write-Info "winget:   $(& (Get-WingetPath) --version) - $(Get-WingetSource)"
        Write-Info "          $(Get-WingetPath)"
    } else {
        Write-Warn "winget:   not found (PATH, App Execution Alias, WindowsApps payload all checked)"
    }
    Write-Info "gum:      $(if (Get-Command gum -ErrorAction SilentlyContinue) { (gum --version) } else { 'not installed (menu uses the numbered fallback)' })"
    Write-Host ""

    Write-Host "Git identity"
    $name = git config --global user.name 2>$null
    $email = git config --global user.email 2>$null
    Write-Info "name:     $(if ($name) { $name } else { '(unset)' })"
    Write-Info "email:    $(if ($email) { $email } else { '(unset)' })"
    Write-Host ""

    Write-Host "Toolchain"
    $mise = Get-Command mise -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($mise) {
        Write-Info "mise:     $((& $mise.Source --version 2>$null) -split ' ' | Select-Object -First 1) ($($mise.Source))"
        & $mise.Source ls --current 2>$null | ForEach-Object {
            $cols = "$_".Trim() -split '\s+'
            Write-Info ("{0,-9} {1}" -f "$($cols[0]):", $cols[1])
        }
        $shims = Get-MiseShimsPath
        if (($env:Path -split ';') -contains $shims) {
            Write-Ok "mise shims on PATH ($shims)"
        } else {
            Write-Warn "mise shims not on PATH - open a new shell, or run Base tools"
        }
    } else {
        Write-Warn "mise:     not installed - run Base tools"
    }
    $goMissing = @(Get-MissingGoTools -RepoRoot $REPO_ROOT)
    if ($goMissing.Count -gt 0) {
        Write-Warn "go tools: missing $($goMissing -join ', ') - run Base tools"
    } else {
        Write-Ok "go tools: $((Get-GoToolNames -RepoRoot $REPO_ROOT) -join ', ') in $(Get-GoBinPath) (gup update keeps them current)"
    }
    if (Test-GitInclude -Path "$REPO_ROOT\shared\git\gitconfig") {
        Write-Ok "git:      shared/git/gitconfig included"
    } else {
        Write-Warn "git:      shared/git/gitconfig not included - run Link dotfiles"
    }
    if (Test-GitInclude -Path "$REPO_ROOT\shared\git\delta.gitconfig") { Write-Ok "git:      delta is the pager" }
    Write-Host ""

    Write-Host "Old toolchain leftovers"
    if (Test-Winget) {
        $manifest = Import-PowerShellDataFile -Path (Join-Path $REPO_ROOT 'windows\packages.psd1')
        $leftover = @($manifest.Superseded | Where-Object { Test-PackageInstalled -Id $_.Id })
        if ($leftover.Count -eq 0) {
            Write-Ok "None of the packages mise replaced are still installed"
        }
        foreach ($pkg in $leftover) {
            Write-Warn "$($pkg.Name) is still installed; $($pkg.By) provides it now. Remove: winget uninstall --id $($pkg.Id)"
        }
    } else {
        Write-Warn "winget not found; cannot check for leftover packages"
    }
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
    -Handler { Invoke-InstallScript -Name 'server' } -Probe { Get-ServerStatus } -Flags @('net', 'admin', 'optin')
Add-MenuTask -Id 'tailscale' -Label 'Tailscale (VPN)'     -Group install   -Order 55 `
    -Handler { Invoke-InstallScript -Name 'tailscale' } -Probe { Get-TailscaleStatus } -Flags @('net', 'winget', 'admin', 'optin')

Add-MenuTask -Id 'update'  -Label 'Update from git'      -Group maintain  -Order 70 `
    -Handler { Update-Dotfiles } -Probe { Get-UpdateStatus } -Flags @('net')
Add-MenuTask -Id 'doctor'  -Label 'Doctor (full report)' -Group maintain  -Order 80 `
    -Handler { Show-Doctor }
Add-MenuTask -Id 'repos'   -Label 'Clone GitHub repos'   -Group maintain  -Order 90 `
    -Handler { Invoke-CloneRepos } -Flags @('net')

# ─── Go ───────────────────────────────────────────────────────────────────────

Invoke-Menu
