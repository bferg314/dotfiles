# Dotfiles setup script for Windows
# Requires PowerShell 5.1 or higher

# Get script location and repo root
$SCRIPT_PATH = $MyInvocation.MyCommand.Path
$SCRIPT_DIR = Split-Path $SCRIPT_PATH -Parent
$REPO_ROOT = Split-Path $SCRIPT_DIR -Parent

# Color helper functions
function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " $Text" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Success {
    param([string]$Text)
    Write-Host "✓ $Text" -ForegroundColor Green
}

function Write-Info {
    param([string]$Text)
    Write-Host "$Text" -ForegroundColor Blue
}

function Write-Warning {
    param([string]$Text)
    Write-Host "$Text" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Text)
    Write-Host "✗ $Text" -ForegroundColor Red
}

# Function to create symlinks
function Set-DotfileLinks {
    Write-Header "Creating Dotfile Links"

    # Create PowerShell profile if it doesn't exist
    $profileDir = Split-Path $PROFILE -Parent
    if (!(Test-Path -Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    if (!(Test-Path -Path $PROFILE)) {
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
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
        Write-Success "Added posh.d sourcing to PowerShell profile"
    } else {
        Write-Success "PowerShell profile already configured"
    }

    # Reload profile
    . $PROFILE

    Write-Success "Setup complete! Links created and PowerShell configured."
    Write-Host ""
    Read-Host "Press Enter to continue"
}

# Function to install base tools via Chocolatey
function Install-BaseTools {
    $installScript = Join-Path $SCRIPT_DIR "installs\base.ps1"

    if (Test-Path $installScript) {
        & $installScript
    } else {
        Write-Error "Install script not found: $installScript"
    }

    Read-Host "Press Enter to continue"
}

# Function to install desktop apps via Chocolatey
function Install-DesktopApps {
    $installScript = Join-Path $SCRIPT_DIR "installs\desktop.ps1"

    if (Test-Path $installScript) {
        & $installScript
    } else {
        Write-Error "Install script not found: $installScript"
    }

    Read-Host "Press Enter to continue"
}

# Function to update dotfiles repository
function Update-Dotfiles {
    Write-Header "Updating Dotfiles Repository"

    Push-Location $REPO_ROOT

    Write-Info "Resetting repository..."
    git reset --hard HEAD

    Write-Info "Cleaning repository..."
    git clean -xffd

    Write-Info "Pulling latest changes..."
    git pull

    Pop-Location

    Write-Success "Repository updated successfully"
    Write-Host ""
    Read-Host "Press Enter to continue"
}

# Main menu
function Show-Menu {
    Clear-Host

    Write-Host ""
    Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║     Dotfiles Setup & Installation      ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Create Links" -ForegroundColor White
    Write-Host "2. Install Base Tools" -ForegroundColor White
    Write-Host "3. Install Desktop Apps" -ForegroundColor White
    Write-Host "4. Update" -ForegroundColor White
    Write-Host "5. Quit" -ForegroundColor White
    Write-Host ""
}

# Main loop
do {
    Show-Menu
    $choice = Read-Host "Enter your choice (1-5)"

    switch ($choice) {
        "1" { Set-DotfileLinks }
        "2" { Install-BaseTools }
        "3" { Install-DesktopApps }
        "4" { Update-Dotfiles }
        "5" {
            Write-Host ""
            Write-Host "Goodbye!" -ForegroundColor Cyan
            Write-Host ""
            exit
        }
        default {
            Write-Warning "Invalid option. Please try again."
            Start-Sleep -Seconds 1
        }
    }
} while ($choice -ne "5")
