# Base installation script for Windows
# Installs core development tools and utilities using Chocolatey
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

Write-Header "Base Tools Installation"

# 1. Ensure Chocolatey is installed
Write-Info "Checking for Chocolatey..."
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Warning "Chocolatey not found. Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Write-Success "Chocolatey installed"
} else {
    Write-Success "Chocolatey is already installed"
}
Write-Host ""

# 2. Install Git
Write-Info "Installing Git..."
choco install git -y
refreshenv
Write-Success "Git installed"
Write-Host ""

# Configure git if not already configured
$gitName = git config --global user.name
$gitEmail = git config --global user.email

if ([string]::IsNullOrEmpty($gitName)) {
    $name = Read-Host "Enter your Git name"
    git config --global user.name "$name"
}

if ([string]::IsNullOrEmpty($gitEmail)) {
    $email = Read-Host "Enter your Git email"
    git config --global user.email "$email"
}

Write-Info "Git configured with:"
Write-Host "  Name:  $(git config --global user.name)"
Write-Host "  Email: $(git config --global user.email)"
Write-Host ""

# 3. Install Vim
Write-Info "Installing Vim..."
choco install vim -y
Write-Success "Vim installed"
Write-Host ""

# 4. Install Docker Desktop
Write-Info "Installing Docker Desktop..."
choco install docker-desktop -y
Write-Success "Docker Desktop installed"
Write-Warning "NOTE: Docker Desktop requires a restart to complete installation"
Write-Host ""

# 5. Install Python
Write-Info "Installing Python..."
choco install python -y
refreshenv
Write-Success "Python installed"
Write-Host ""

# 6. Install Node.js LTS
Write-Info "Installing Node.js LTS..."
choco install nodejs-lts -y
refreshenv
Write-Success "Node.js LTS installed"
Write-Host ""

# 7. Install Visual Studio Build Tools (equivalent to build-essential)
Write-Info "Installing Visual Studio Build Tools..."
choco install visualstudio2022buildtools -y
choco install visualstudio2022-workload-vctools -y
Write-Success "Visual Studio Build Tools installed"
Write-Host ""

# 8. Install common development tools
Write-Info "Installing additional development tools..."
choco install 7zip -y
choco install wget -y
choco install curl -y
choco install jq -y
Write-Success "Additional tools installed"
Write-Host ""

Write-Header "Base Tools Installation Complete"
Write-Host ""
Write-Warning "IMPORTANT: Some installations may require a system restart to take effect."
Write-Warning "Particularly Docker Desktop and Visual Studio Build Tools."
Write-Host ""
