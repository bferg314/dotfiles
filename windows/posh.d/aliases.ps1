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
Set-Alias touch New-Item
Set-Alias ll Get-ChildItem

# Directory listing with colors
function ls_color { Get-ChildItem | Format-Wide -AutoSize | Out-Host }
# ls ships as an AllScope alias in Windows PowerShell 5.1, and overriding it
# without -Force -Option AllScope errors on every shell start.
Set-Alias ls ls_color -Force -Option AllScope

# Quick edits
function Edit-Profile { code $PROFILE }
function Edit-Aliases { code $PSScriptRoot\aliases.ps1 }

# System info
function Get-MyIP { (Invoke-WebRequest -Uri "https://ifconfig.me/ip").Content }

# Create Unix-like aliases for PowerShell commands
Set-Alias grep Select-String
Set-Alias which Get-Command
Set-Alias cat Get-Content -Force -Option AllScope
