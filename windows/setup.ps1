# Get script location and repo root
$SCRIPT_PATH = $MyInvocation.MyCommand.Path
$SCRIPT_DIR = Split-Path $SCRIPT_PATH -Parent
$REPO_ROOT = Split-Path $SCRIPT_DIR -Parent

# Create PowerShell profile if it doesn't exist
if (!(Test-Path -Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force
}

# Add sourcing code to profile if not already present
$sourceCode = @"

# Source all files from dotfiles posh.d directory
`$poshDPath = "$REPO_ROOT\windows\posh.d"
if (Test-Path -Path `$poshDPath) {
    Get-ChildItem -Path `$poshDPath -File | ForEach-Object {
        . `$_.FullName
    }
}
"@

if (!(Select-String -Path $PROFILE -Pattern "Source all files from dotfiles posh.d directory" -Quiet)) {
    Add-Content -Path $PROFILE -Value $sourceCode
}

Write-Host "Setup complete! Please restart PowerShell to apply changes."
