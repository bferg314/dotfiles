# bootstrap.ps1 - Day-zero machine setup
# Installs git, vim & UniGetUI, clones dotfiles, configures git identity,
# generates an SSH key for GitHub, and sets up authorized_keys.
#
# Usage:
#   irm https://raw.githubusercontent.com/USER/dotfiles/master/bootstrap.ps1 | iex
#
# The counterpart to bootstrap.sh. Deliberately self-contained: it runs before
# the repo exists, so it cannot dot-source windows/common.ps1 the way the rest
# of the Windows scripts do.
#
# The source is pure ASCII, and the box-drawing and status glyphs are built
# from [char] codes at runtime. A literal-glyph file would have to choose
# between two broken delivery paths: with a UTF-8 BOM, `irm | iex` fails
# because iex treats the leading BOM as part of the first token; without one,
# Windows PowerShell 5.1 reads the UTF-8 bytes as CP1252 and turns them into
# smart quotes, which are string delimiters, so the file will not even parse.

#Requires -Version 5.1

$DOTFILES_DIR = "$HOME\dotfiles"

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$IS_ADMIN = ([Security.Principal.WindowsPrincipal]$identity).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

# The console defaults to a legacy OEM codepage, which mangles the glyphs
# below. Affects this process only; guarded because there is no console when
# output is redirected.
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
    # Not a console; leave the encoding alone.
}

$GLYPH = @{
    Ok    = [char]0x2713  # check mark
    Fail  = [char]0x2717  # ballot X
    Arrow = [char]0x2192  # rightwards arrow
    Warn  = [char]0x26A0  # warning sign
}

$BOX = @{
    TopLeft     = [char]0x2554
    TopRight    = [char]0x2557
    BottomLeft  = [char]0x255A
    BottomRight = [char]0x255D
    Horizontal  = [char]0x2550
    Vertical    = [char]0x2551
    Rule        = [char]0x2500
}

# --- Helpers -----------------------------------------------------------------

function Write-Box {
    param(
        [Parameter(Mandatory)][string[]]$Lines,
        [int]$Width = 44,
        [string]$Color = 'Cyan',
        [switch]$Center
    )

    $edge = [string]$BOX.Horizontal * $Width
    Write-Host "$($BOX.TopLeft)$edge$($BOX.TopRight)" -ForegroundColor $Color

    foreach ($line in $Lines) {
        $pad = [math]::Max(0, $Width - $line.Length)
        $left = if ($Center) { [math]::Floor($pad / 2) } else { 2 }
        $right = [math]::Max(0, $pad - $left)
        Write-Host "$($BOX.Vertical)$(' ' * $left)$line$(' ' * $right)$($BOX.Vertical)" -ForegroundColor $Color
    }

    Write-Host "$($BOX.BottomLeft)$edge$($BOX.BottomRight)" -ForegroundColor $Color
}

function Write-Header {
    Write-Host ""
    Write-Box -Lines 'Dotfiles Bootstrap Setup' -Center
    Write-Host ""
    if (-not $IS_ADMIN) {
        Write-Host "  $($GLYPH.Warn) Not running as Administrator" -ForegroundColor Yellow
        Write-Host ""
    }
}

function Write-Step { param([string]$Number, [string]$Text) Write-Host "[Step $Number] $Text" -ForegroundColor Blue }
function Write-Ok   { param([string]$Text) Write-Host "  $($GLYPH.Ok) $Text" -ForegroundColor Green }
function Write-Warn { param([string]$Text) Write-Host "  ! $Text" -ForegroundColor Yellow }
function Write-Info { param([string]$Text) Write-Host "  $($GLYPH.Arrow) $Text" -ForegroundColor Blue }
function Write-Fail { param([string]$Text) Write-Host "  $($GLYPH.Fail) $Text" -ForegroundColor Red }

function Write-Separator {
    Write-Host ""
    Write-Host ([string]$BOX.Rule * 44) -ForegroundColor Cyan
    Write-Host ""
}

# winget's PATH changes never reach the running process. Merge in both registry
# scopes so freshly installed tools are callable without opening a new shell.
#
# Merged rather than overwritten: the process PATH can hold entries that were
# never in the registry, and replacing it wholesale would drop them.
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

# A trimmed copy of Install-Package from windows/common.ps1 - see the note at
# the top of this file for why it is duplicated rather than shared.
function Install-Package {
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$Name = $Id
    )

    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        winget list --id $Id --exact --accept-source-agreements 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "$Name already installed"
            return $true
        }

        Write-Info "Installing $Name..."
        # Out-Host, not bare output: winget's progress would otherwise be
        # returned alongside the boolean and make every caller truthy.
        winget install --id $Id --exact --silent --disable-interactivity `
            --accept-package-agreements --accept-source-agreements | Out-Host
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }

    # winget returns HRESULTs, which land in $LASTEXITCODE as negative int32.
    # Mask back to unsigned so they can be compared against the documented
    # hex codes rather than hand-computed negative decimals.
    $unsigned = $code -band 0xFFFFFFFFL

    switch ($unsigned) {
        0          { Write-Ok "$Name installed"; Update-SessionPath; return $true }
        0x8A150061 { Write-Ok "$Name already installed"; return $true }
        0x8A15002B { Write-Ok "$Name already up to date"; return $true }
        default {
            Write-Fail "$Name failed (winget exit 0x$('{0:X8}' -f $unsigned))"
            return $false
        }
    }
}

# --- Preview what will happen ------------------------------------------------

function Confirm-Plan {
    Write-Host "  This script will:"
    Write-Host ""
    Write-Host "  1. Check for winget"
    Write-Host "  2. Install git, vim, UniGetUI and the OpenSSH client"
    if ($IS_ADMIN) {
        Write-Host "  3. Install and start the OpenSSH server"
        Write-Host "  4. Clone your dotfiles repository"
        Write-Host "  5. Configure git global identity"
        Write-Host "  6. Generate an SSH key for GitHub"
        Write-Host "  7. Set up authorized_keys for remote login"
        Write-Host "  8. Optionally run full dotfiles setup"
    } else {
        Write-Host "  3. Clone your dotfiles repository"
        Write-Host "  4. Configure git global identity"
        Write-Host "  5. Generate an SSH key for GitHub"
        Write-Host "  6. Set up authorized_keys for remote login"
        Write-Host "  7. Optionally run full dotfiles setup"
        Write-Host ""
        Write-Warn "The OpenSSH server needs Administrator - re-run elevated for that step."
    }

    Write-Host ""
    $confirm = Read-Host "  Continue? [Y/n]"
    if ($confirm -match '^[Nn]') {
        Write-Host ""
        Write-Warn "Aborted."
        return $false
    }
    Write-Separator
    return $true
}

# --- Step 1: Check the package manager ---------------------------------------

function Test-Winget {
    Write-Step "1" "Checking for winget"

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Fail "winget not found."
        Write-Warn "winget ships with Windows 10 1809+ and Windows 11 as part of `"App Installer`"."
        Write-Warn "Install it from the Microsoft Store, or from:"
        Write-Warn "  https://github.com/microsoft/winget-cli/releases"
        return $false
    }

    Write-Ok "winget $((winget --version) 2>$null)"
    Write-Separator
    return $true
}

# --- Step 2: Install git and vim ---------------------------------------------

function Install-Prerequisite {
    Write-Step "2" "Installing git, vim and UniGetUI"

    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Ok "git already installed ($(git --version))"
    } else {
        Install-Package -Id 'Git.Git' -Name 'git' | Out-Null
        # winget's PATH update can lag behind the install even after a refresh.
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            $gitBin = "$env:ProgramFiles\Git\cmd"
            if (Test-Path -LiteralPath $gitBin) { $env:Path = "$env:Path;$gitBin" }
        }
    }

    if (Get-Command vim -ErrorAction SilentlyContinue) {
        Write-Ok "vim already installed"
    } else {
        Install-Package -Id 'vim.vim' -Name 'vim' | Out-Null
    }

    # A GUI over winget/scoop/chocolatey/pip/npm. No Get-Command guard: it ships
    # no CLI entry point, so the winget check inside Install-Package is what
    # makes this idempotent.
    #
    # Published as MartiCliment.UniGetUI (and WingetUI before that) until the
    # project moved to Devolutions - the old ids now resolve only to the
    # pre-release channel, so pin the current one.
    Install-Package -Id 'Devolutions.UniGetUI' -Name 'UniGetUI' | Out-Null

    # ssh-keygen and ssh live here. Present by default on Windows 10 1809+, but
    # not on every image, and installing the capability needs elevation.
    if (Get-Command ssh-keygen -ErrorAction SilentlyContinue) {
        Write-Ok "OpenSSH client already installed"
    } elseif ($IS_ADMIN) {
        Write-Info "Installing the OpenSSH client..."
        $capability = Get-WindowsCapability -Online -Name 'OpenSSH.Client*' | Select-Object -First 1
        if ($capability) {
            Add-WindowsCapability -Online -Name $capability.Name | Out-Null
            Update-SessionPath
            Write-Ok "OpenSSH client installed"
        } else {
            Write-Warn "OpenSSH client capability not available on this system"
        }
    } else {
        Write-Warn "ssh-keygen not found - re-run elevated to install the OpenSSH client"
    }

    Write-Separator
}

# --- Step 2b: Install the OpenSSH server (Administrator only) ----------------
#
# The counterpart to the openssh-server half of install_extra_prerequisites.
# There is no sudo equivalent to install, and no "create a regular user" step:
# on Windows you are already a normal user, and elevation is per-process.

function Install-SshServer {
    if (-not $IS_ADMIN) { return }

    Write-Step "2b" "Installing the OpenSSH server"

    # Queried by wildcard: the capability name carries a version suffix that has
    # changed across Windows releases.
    $capability = Get-WindowsCapability -Online -Name 'OpenSSH.Server*' | Select-Object -First 1

    if (-not $capability) {
        Write-Warn "OpenSSH Server capability not available on this system"
        Write-Separator
        return
    }

    if ($capability.State -eq 'Installed') {
        Write-Ok "OpenSSH Server already installed"
    } else {
        Add-WindowsCapability -Online -Name $capability.Name | Out-Null
        Write-Ok "OpenSSH Server installed"
    }

    Set-Service -Name sshd -StartupType Automatic
    if ((Get-Service sshd).Status -ne 'Running') { Start-Service sshd }
    Write-Ok "sshd enabled and running"

    # The capability install normally creates this, but not on every build.
    if (-not (Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' `
            -DisplayName 'OpenSSH Server (sshd)' `
            -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
        Write-Ok "Firewall rule created for TCP/22"
    } else {
        Write-Ok "Firewall rule for TCP/22 already present"
    }

    Write-Separator
}

# --- Step 3: Clone dotfiles repo ---------------------------------------------

function Get-DotfilesRepo {
    param([string]$Number)

    Write-Step $Number "Cloning dotfiles repository"

    Write-Host ""
    $ghUser = Read-Host "  GitHub username"
    if ([string]::IsNullOrWhiteSpace($ghUser)) {
        Write-Warn "No username entered, skipping clone"
        Write-Separator
        return
    }

    $repoName = Read-Host "  Repo name [dotfiles]"
    if ([string]::IsNullOrWhiteSpace($repoName)) { $repoName = 'dotfiles' }

    $repoUrl = "https://github.com/$ghUser/$repoName.git"
    Write-Info "Repo: $repoUrl"
    Write-Host ""

    if (Test-Path -LiteralPath "$DOTFILES_DIR\.git") {
        $existing = git -C $DOTFILES_DIR remote get-url origin 2>$null
        if ($existing -like "*$ghUser/$repoName*") {
            Write-Ok "Dotfiles already cloned at $DOTFILES_DIR"
            Write-Info "Pulling latest changes..."
            git -C $DOTFILES_DIR pull --ff-only
            if ($LASTEXITCODE -ne 0) { Write-Warn "Pull failed (local changes?), continuing" }
        } else {
            Write-Warn "Directory $DOTFILES_DIR exists but points to a different remote:"
            Write-Warn "  Found:    $existing"
            Write-Warn "  Expected: $repoUrl"
            Write-Warn "Skipping clone. Remove $DOTFILES_DIR manually for a fresh clone."
        }
    } elseif (Test-Path -LiteralPath $DOTFILES_DIR) {
        Write-Warn "Directory $DOTFILES_DIR exists but is not a git repository."
        Write-Warn "Skipping clone. Remove it manually if you want to clone here."
    } else {
        Write-Info "Cloning into $DOTFILES_DIR..."
        git clone $repoUrl $DOTFILES_DIR
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Dotfiles cloned to $DOTFILES_DIR"
        } else {
            Write-Fail "Clone failed"
        }
    }

    Write-Separator
}

# --- Step 4: Configure git global identity -----------------------------------

function Set-GitIdentity {
    param([string]$Number)

    Write-Step $Number "Configuring git global identity"

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Warn "git is not on PATH yet - open a new shell and re-run to set your identity"
        Write-Separator
        return
    }

    if (-not [string]::IsNullOrWhiteSpace((git config --global user.name))) {
        Write-Ok "Git name already set: $(git config --global user.name)"
    } else {
        $gitName = Read-Host "  Enter your Git name"
        if (-not [string]::IsNullOrWhiteSpace($gitName)) {
            git config --global user.name "$gitName"
            Write-Ok "Git name set to: $gitName"
        } else {
            Write-Warn "No name entered, skipping git user.name"
        }
    }

    if (-not [string]::IsNullOrWhiteSpace((git config --global user.email))) {
        Write-Ok "Git email already set: $(git config --global user.email)"
    } else {
        $gitEmail = Read-Host "  Enter your Git email"
        if (-not [string]::IsNullOrWhiteSpace($gitEmail)) {
            git config --global user.email "$gitEmail"
            Write-Ok "Git email set to: $gitEmail"
        } else {
            Write-Warn "No email entered, skipping git user.email"
        }
    }

    Write-Separator
}

# --- Step 5: Generate ed25519 SSH key for GitHub -----------------------------

function New-SshKey {
    param([string]$Number)

    Write-Step $Number "Generating SSH key for GitHub"

    if (-not (Get-Command ssh-keygen -ErrorAction SilentlyContinue)) {
        Write-Warn "ssh-keygen not found - skipping key generation"
        Write-Warn "Install the OpenSSH client (elevated) and re-run this step."
        Write-Separator
        return
    }

    $keyPath = "$HOME\.ssh\id_ed25519"
    $pubPath = "$keyPath.pub"

    if (-not (Test-Path -LiteralPath "$HOME\.ssh")) {
        New-Item -ItemType Directory -Path "$HOME\.ssh" -Force | Out-Null
        Write-Info "Created ~\.ssh"
    }

    if (Test-Path -LiteralPath $keyPath) {
        Write-Ok "SSH key already exists at $keyPath"
    } else {
        Write-Host ""
        $usePassphrase = Read-Host "  Protect SSH key with a passphrase? (recommended) [Y/n]"
        Write-Host ""
        $comment = "$env:USERNAME@$env:COMPUTERNAME"
        if ($usePassphrase -match '^[Nn]') {
            # An empty argument reaches a native exe differently per host:
            # Windows PowerShell 5.1 drops '' entirely, so -N would swallow the
            # -C that follows, while PowerShell 7 passes '""' through as a
            # two-character passphrase.
            $empty = if ($PSVersionTable.PSVersion.Major -ge 6) { '' } else { '""' }
            ssh-keygen -t ed25519 -f $keyPath -N $empty -C $comment
        } else {
            ssh-keygen -t ed25519 -f $keyPath -C $comment
        }

        if (-not (Test-Path -LiteralPath $keyPath)) {
            Write-Fail "Key generation failed"
            Write-Separator
            return
        }
        Write-Ok "SSH key generated at $keyPath"
    }

    $pubKey = (Get-Content -LiteralPath $pubPath -Raw).Trim()

    Write-Host ""
    Write-Box -Width 62 -Color Yellow -Lines @(
        'Copy this public key and add it to GitHub:',
        'https://github.com/settings/ssh/new'
    )
    Write-Host ""
    Write-Host $pubKey -ForegroundColor Green
    Write-Host ""
    try {
        Set-Clipboard -Value $pubKey
        Write-Info "Copied to the clipboard."
    } catch {
        # No clipboard in a service or remote session; the key is printed above.
    }
    Read-Host "  Press Enter once you have added the key to GitHub" | Out-Null

    Write-Separator
}

# --- Step 6: Add authorized_keys entry for remote SSH login ------------------

function Set-AuthorizedKey {
    param([string]$Number)

    Write-Step $Number "Setting up authorized_keys for remote login"

    # Windows sshd ignores ~\.ssh\authorized_keys for members of the
    # Administrators group; the shipped sshd_config routes them to a single
    # machine-wide file instead.
    #
    # Membership is read from the token's group SIDs rather than IsInRole,
    # because an unelevated admin's token carries the group as deny-only and
    # IsInRole reports false - which would silently write the key to a file
    # sshd never reads.
    $inAdminGroup = $identity.Groups -contains ([Security.Principal.SecurityIdentifier]'S-1-5-32-544')

    if ($inAdminGroup) {
        $authKeys = "$env:ProgramData\ssh\administrators_authorized_keys"
        if (-not $IS_ADMIN) {
            Write-Warn "You are an Administrator, so sshd only reads:"
            Write-Warn "  $authKeys"
            Write-Warn "Writing there needs elevation. Re-run this script as Administrator."
            Write-Separator
            return
        }
    } else {
        $authKeys = "$HOME\.ssh\authorized_keys"
    }

    Write-Host ""
    Write-Host "  Paste the public SSH key from the machine you will remote in from." -ForegroundColor Cyan
    Write-Host "  (e.g., from your local ~/.ssh/id_*.pub)" -ForegroundColor Cyan
    Write-Host "  Usually: cat ~/.ssh/id_ed25519.pub" -ForegroundColor Cyan
    Write-Host "  Press Enter to skip." -ForegroundColor Cyan
    Write-Host ""
    $pastedKey = (Read-Host "  Paste public key").Trim()

    if ([string]::IsNullOrWhiteSpace($pastedKey)) {
        Write-Warn "No key entered, skipping authorized_keys setup"
        Write-Separator
        return
    }

    if ($pastedKey -notmatch '^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp[0-9]+) ') {
        Write-Warn "Input does not look like a valid SSH public key (expected: ssh-ed25519 / ssh-rsa / ecdsa-sha2-*)"
        Write-Warn "Skipping. Add it manually to $authKeys if needed."
        Write-Separator
        return
    }

    $keyDir = Split-Path $authKeys -Parent
    if (-not (Test-Path -LiteralPath $keyDir)) {
        New-Item -ItemType Directory -Path $keyDir -Force | Out-Null
    }

    $existing = if (Test-Path -LiteralPath $authKeys) { @(Get-Content -LiteralPath $authKeys) } else { @() }
    if ($existing -contains $pastedKey) {
        Write-Ok "Key already present in $authKeys"
    } else {
        # ASCII: sshd will not parse a UTF-16 or BOM-prefixed authorized_keys.
        Set-Content -LiteralPath $authKeys -Encoding ASCII `
                    -Value ($existing + $pastedKey | Where-Object { $_ })
        Write-Ok "Key added to $authKeys"
    }

    if ($inAdminGroup) {
        # sshd ignores administrators_authorized_keys unless only Administrators
        # and SYSTEM can write to it - the most common cause of "key auth
        # silently does not work" on Windows.
        icacls.exe $authKeys /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null
        Write-Ok "Reset ACL on administrators_authorized_keys"
    }

    Write-Separator
}

# --- Step 7: Offer full dotfiles setup ---------------------------------------

function Invoke-DotfilesSetup {
    param([string]$Number)

    Write-Step $Number "Full dotfiles setup (optional)"

    $setupScript = "$DOTFILES_DIR\windows\setup.ps1"

    if (-not (Test-Path -LiteralPath $setupScript)) {
        Write-Warn "setup.ps1 not found at $setupScript"
        Write-Warn "Ensure the repo was cloned successfully."
        Write-Separator
        return
    }

    Write-Host ""
    $runSetup = Read-Host "  Run windows\setup.ps1 now for full dotfiles setup? [y/N]"
    Write-Host ""

    if ($runSetup -match '^[Yy]') {
        Write-Info "Launching $setupScript..."
        Write-Host ""
        & $setupScript
    } else {
        Write-Info "Skipped. Run it later with:"
        Write-Info "  $setupScript"
    }

    Write-Separator
}

# --- Main --------------------------------------------------------------------

function Invoke-Bootstrap {
    Write-Header
    if (-not (Confirm-Plan)) { return }

    if (-not (Test-Winget)) { return }   # Step 1
    Install-Prerequisite                 # Step 2
    Install-SshServer                    # Step 2b (Administrator only)

    # Numbered from 3 or 4 depending on whether step 2b ran, so the output
    # matches the plan printed above.
    $n = if ($IS_ADMIN) { 4 } else { 3 }
    Get-DotfilesRepo     -Number $n       # Step 3/4
    Set-GitIdentity      -Number ($n + 1) # Step 4/5
    New-SshKey           -Number ($n + 2) # Step 5/6
    Set-AuthorizedKey    -Number ($n + 3) # Step 6/7
    Invoke-DotfilesSetup -Number ($n + 4) # Step 7/8

    Write-Box -Lines 'Bootstrap Complete!' -Color Green -Center
    Write-Host ""

    $hasGit = [bool](Get-Command git -ErrorAction SilentlyContinue)
    $gitName = if ($hasGit) { git config --global user.name } else { $null }
    $gitEmail = if ($hasGit) { git config --global user.email } else { $null }
    if ([string]::IsNullOrWhiteSpace($gitName)) { $gitName = '(not set)' }
    if ([string]::IsNullOrWhiteSpace($gitEmail)) { $gitEmail = 'not set' }

    Write-Host "  Summary:" -ForegroundColor Blue
    Write-Host "  Dotfiles:     $DOTFILES_DIR"
    Write-Host "  Git identity: $gitName <$gitEmail>"
    Write-Host "  SSH key:      $HOME\.ssh\id_ed25519.pub"
    Write-Host ""
    Write-Host "  Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Verify GitHub SSH auth: ssh -T git@github.com"
    Write-Host "  2. Run dotfiles setup:     $DOTFILES_DIR\windows\setup.ps1"
    Write-Host ""
}

Invoke-Bootstrap
