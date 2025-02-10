
# Starship
# Link: https://starship.rs/guide/#%F0%9F%9A%80-installation
# Chocolatey: choco install starship
# Invoke-Expression (&starship init powershell)

# oh-my-posh
# link: https://ohmyposh.dev/
# chocolatey: choco install oh-my-posh
# default theme:
# oh-my-posh init pwsh | Invoke-Expression
# custom theme:
Clear-Host
Invoke-Expression (&oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/kali.omp.json")
# lil help for missing venv visibility


# Completely custom prompt
# function Update-PathToShortPath([string] $path) {
#     $loc = $path.Replace($HOME, '~')

#     # remove prefix for UNC paths
#     $loc = $loc -replace '^[^:]+::', ''

#     # make path shorter like tabs in Vim,
#     # handle paths starting with \\ and . correctly
#     return ($loc -replace '\\(\.?)([^\\])[^\\]*(?=\\)','\$1$2')
# }

 
# 
# $Global:PromptAdmin=''
# $CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
# $principal = new-object System.Security.principal.windowsprincipal($CurrentUser)
# if ($principal.IsInRole("Administrators")) { $PromptAdmin='ADMIN' }

# function global:prompt {
#     $Success = $?
#     ## Time calculation
#     $LastExecutionTimeSpan = if (@(Get-History).Count -gt 0) {
#         Get-History | Select-Object -Last 1 | ForEach-Object {
#             New-TimeSpan -Start $_.StartExecutionTime -End $_.EndExecutionTime
#         }
#     }
#     else {
#         New-TimeSpan
#     }

#     $LastExecutionShortTime = if ($LastExecutionTimeSpan.Days -gt 0) {
#         "$($LastExecutionTimeSpan.Days + [Math]::Round($LastExecutionTimeSpan.Hours / 24, 2)) d"
#     }
#     elseif ($LastExecutionTimeSpan.Hours -gt 0) {
#         "$($LastExecutionTimeSpan.Hours + [Math]::Round($LastExecutionTimeSpan.Minutes / 60, 2)) h"
#     }
#     elseif ($LastExecutionTimeSpan.Minutes -gt 0) {
#         "$($LastExecutionTimeSpan.Minutes + [Math]::Round($LastExecutionTimeSpan.Seconds / 60, 2)) m"
#     }
#     elseif ($LastExecutionTimeSpan.Seconds -gt 0) {
#         "$($LastExecutionTimeSpan.Seconds + [Math]::Round($LastExecutionTimeSpan.Milliseconds / 1000, 2)) s"
#     }
#     elseif ($LastExecutionTimeSpan.Milliseconds -gt 0) {
#         "$([Math]::Round($LastExecutionTimeSpan.TotalMilliseconds, 2)) ms"
#     }
#     else {
#         "0 s"
#     }

#     Write-Host -Object "[$(Get-Date -Format 'HH:mm:ss')]" -NoNewline -ForegroundColor DarkCyan

#     if ($Success) {
#         Write-Host -Object "[$LastExecutionShortTime] " -NoNewline -ForegroundColor DarkCyan
#     }
#     else {
#         Write-Host -Object "! [$LastExecutionShortTime] " -NoNewline -ForegroundColor Red
#     }

#     if ($PromptAdmin) {
#         Write-Host -Object "$($env:USERNAME) ($PromptAdmin) " -NoNewline -ForegroundColor Yellow
#     } else {
#         Write-Host -Object "$($env:USERNAME) " -NoNewline -ForegroundColor Gray
#     }

#     ## Path
#     $cdelim = [ConsoleColor]::DarkCyan
#     $cloc = [ConsoleColor]::Cyan
#     Write-Host "$([char]0x0A7) " -n -f $cloc
#     Write-Host ($($env:COMPUTERNAME)) -n -f Gray
#     Write-Host ' {' -n -f $cdelim
#     Write-Host (Update-PathToShortPath($pwd).Path) -n -f $cloc
#     Write-Host '}' -n -f $cdelim
#     Write-Host ""
#     Write-Host "$([char]0x03C6)" -n -f Green
#     return " "
# }