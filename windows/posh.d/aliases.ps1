# Navigation
for ($i = 1; $i -le 5; $i++) {
    $u = "".PadLeft($i, "u")
    $unum = "u$i"
    $d = $u.Replace("u", "../")
    Invoke-Expression "function $u { push-location $d }"
    Invoke-Expression "function $unum { push-location $d }"
}

# Shorter commands for common operations
Set-Alias c Clear-Host

# ll falls back to Get-ChildItem; tools.ps1 replaces it with eza when eza is
# installed. `ls` itself is left as Get-ChildItem on purpose: it returns file
# objects, so `ls | Where-Object Length -gt 1MB` and friends keep working.
# (An earlier version pointed ls at Format-Wide | Out-Host, which printed
# nicely but silently broke every pipeline that started with ls.)
Set-Alias ll Get-ChildItem

# touch: create the file if it is missing, otherwise update its timestamp --
# what the Unix command does. A bare New-Item alias errored on existing files.
function touch {
    param([Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Path)
    foreach ($p in $Path) {
        if (Test-Path -LiteralPath $p) {
            (Get-Item -LiteralPath $p).LastWriteTime = Get-Date
        } else {
            New-Item -ItemType File -Path $p | Out-Null
        }
    }
}

# Quick edits
function Edit-Profile { code $PROFILE }
function Edit-Aliases { code $PSScriptRoot\aliases.ps1 }
function Edit-Mise    { code "$HOME\.config\mise\config.toml" }

# Run dotfiles setup from anywhere - the counterpart to dotsetup in
# linux/bashrc.d/alias-bash.bashrc.
#
# posh.d is sourced in place from the repo, so $PSScriptRoot already points at
# <repo>\windows\posh.d and none of the symlink resolution the Linux version
# needs applies here.
function dotsetup {
    $setup = Join-Path $PSScriptRoot '..\setup.ps1'
    if (-not (Test-Path -LiteralPath $setup)) {
        Write-Warning "Dotfiles setup not found at $setup"
        return
    }
    & $setup
}

# System info
function Get-MyIP { (Invoke-WebRequest -Uri "https://ifconfig.me/ip").Content }

# Create Unix-like aliases for PowerShell commands
Set-Alias grep Select-String
Set-Alias which Get-Command
Set-Alias cat Get-Content -Force -Option AllScope
