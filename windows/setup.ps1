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

# wezterm was dropped from the repo, but a machine set up before that still has
# ~\.wezterm.lua pointing at the deleted file. Only links into this repo are
# removed - a hand-written config of your own is left alone.
function Remove-LegacyWeztermLink {
    $path = "$HOME\.wezterm.lua"

    # Get-Item rather than Test-Path: a symlink whose target no longer exists -
    # exactly the case this cleans up - resolves to $false under Test-Path.
    $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return }
    if ($item.LinkType -notin @('SymbolicLink', 'HardLink')) { return }

    $points = @($item.Target) | ForEach-Object { "$_" }
    if (-not ($points | Where-Object { $_ -like "*\windows\wezterm\*" })) { return }

    Remove-Item -LiteralPath $path -Force
    Write-Ok "Removed stale ~\.wezterm.lua link (wezterm is no longer part of this repo)"
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

# ─── Main menu ────────────────────────────────────────────────────────────────

function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║     Dotfiles Setup & Installation      ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) Create Links"
    Write-Host "  2) Install vim-plug"
    Write-Host "  3) Install PowerShell 7"
    Write-Host "  4) Install Base Tools"
    Write-Host "  5) Install Desktop Apps"
    Write-Host "  6) Install Server Tools (OpenSSH)"
    Write-Host "  7) Update"
    Write-Host "  8) Quit"
    Write-Host ""
}

while ($true) {
    Show-Menu
    $choice = Read-Host "Enter your choice (1-8)"
    Write-Host ""

    # Checked before the switch: `break` inside a switch exits the switch, not
    # the enclosing loop.
    if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq '8') { break }

    switch ($choice) {
        '1' { Set-DotfileLinks }
        '2' { Install-VimPlug }
        '3' { Install-PowerShell7 }
        '4' { Invoke-InstallScript -Name 'base' }
        '5' { Invoke-InstallScript -Name 'desktop' }
        '6' { Invoke-InstallScript -Name 'server' }
        '7' { Update-Dotfiles }
        default { Write-Warn "Invalid option" }
    }

    Write-Host ""
    Read-Host "Press Enter to continue" | Out-Null
}

Write-Host ""
Write-Host "Goodbye!" -ForegroundColor Cyan
Write-Host ""
