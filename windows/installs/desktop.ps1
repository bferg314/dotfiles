# Desktop installation script for Windows
# Installs desktop applications using winget
# Requires Administrator privileges
#
# The counterpart to linux/installs/desktop.sh.

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\common.ps1"

Assert-Admin
Write-Header "Desktop Applications Installation"
Assert-Winget
Reset-PackageFailures

# ─── Apps shared with the linux desktop install ───────────────────────────────

Install-Package -Id 'Valve.Steam'                -Name 'Steam'           | Out-Null
Install-Package -Id 'Mozilla.Firefox'            -Name 'Firefox'         | Out-Null
Install-Package -Id 'Microsoft.VisualStudioCode' -Name 'VS Code'         | Out-Null
Install-Package -Id 'Obsidian.Obsidian'          -Name 'Obsidian'        | Out-Null
Install-Package -Id 'Spotify.Spotify'            -Name 'Spotify'         | Out-Null
Install-Package -Id 'Discord.Discord'            -Name 'Discord'         | Out-Null
Install-Package -Id 'GitHub.GitHubDesktop'       -Name 'GitHub Desktop'  | Out-Null
Write-Host ""

# ─── Windows-only extras ──────────────────────────────────────────────────────

Install-Package -Id 'VideoLAN.VLC'                 -Name 'VLC'           | Out-Null
Install-Package -Id 'Notepad++.Notepad++'          -Name 'Notepad++'     | Out-Null
Install-Package -Id 'voidtools.Everything'         -Name 'Everything'    | Out-Null
Install-Package -Id 'Flow-Launcher.Flow-Launcher'  -Name 'Flow Launcher' | Out-Null
Install-Package -Id 'ZhornSoftware.Caffeine'       -Name 'Caffeine'      | Out-Null
Install-Package -Id 'mRemoteNG.mRemoteNG'          -Name 'mRemoteNG'     | Out-Null
Install-Package -Id 'Bitwarden.Bitwarden'          -Name 'Bitwarden'     | Out-Null
Write-Host ""

Write-Header "Desktop Applications Installation Complete"

if (-not (Show-PackageFailures)) { exit 1 }
