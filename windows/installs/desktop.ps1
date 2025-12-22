# Desktop installation script for Windows
# Installs desktop applications using Chocolatey
# Requires Administrator privileges

# Check for admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "ERROR: This script requires Administrator privileges." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

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

Write-Header "Desktop Applications Installation"

# Ensure Chocolatey is installed
Write-Info "Checking for Chocolatey..."
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Error "Chocolatey is not installed. Please run 'Install Base Tools' first."
    exit 1
}
Write-Success "Chocolatey is ready"
Write-Host ""

# 1. Install Steam
Write-Info "Installing Steam..."
choco install steam -y
Write-Success "Steam installed"
Write-Host ""

# 2. Install Firefox
Write-Info "Installing Firefox..."
choco install firefox -y
Write-Success "Firefox installed"
Write-Host ""

# 3. Install VS Code
Write-Info "Installing VS Code..."
choco install vscode -y
Write-Success "VS Code installed"
Write-Host ""

# 4. Install Obsidian
Write-Info "Installing Obsidian..."
choco install obsidian -y
Write-Success "Obsidian installed"
Write-Host ""

# 5. Install Spotify
Write-Info "Installing Spotify..."
choco install spotify -y
Write-Success "Spotify installed"
Write-Host ""

# 6. Install Discord
Write-Info "Installing Discord..."
choco install discord -y
Write-Success "Discord installed"
Write-Host ""

# 7. Install GitHub Desktop
Write-Info "Installing GitHub Desktop..."
choco install github-desktop -y
Write-Success "GitHub Desktop installed"
Write-Host ""

# 8. Install additional useful desktop tools
Write-Info "Installing additional desktop tools..."
choco install vlc -y
choco install notepadplusplus -y
choco install everything -y
choco install flow-launcher -y
choco install caffeine -y
choco install mremoteng -y
choco install bitwarden -y
Write-Success "Additional tools installed"
Write-Host ""

Write-Header "Desktop Applications Installation Complete"
Write-Host ""
