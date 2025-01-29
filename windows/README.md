# Windows Dotfiles

This directory contains configuration files and scripts for setting up a Windows development environment.

## Components

### PowerShell Configuration (`posh.d/`)
- **alias-python.ps1**: Python development environment aliases and functions
- **system.ps1**: System information and monitoring tools
- **history.ps1**: Enhanced command history management
- **functions.ps1**: Utility functions for daily tasks
- **aliases.ps1**: Common command aliases and shortcuts

### Vim Configuration (`vim/`)
- **.vimrc**: Vim editor configuration with plugins:
  - vim-airline for enhanced status line
  - NERDTree for file navigation
  - Git integration (fugitive, gitgutter)
  - Code formatting and syntax checking

### AutoHotkey Scripts (`ahk/`)
- **WindowsShortcuts.ahk**: Custom keyboard shortcuts for Windows

## Installation

1. Clone this repository:
```powershell
git clone https://github.com/yourusername/dotfiles.git
```

2. Run the setup script:
```powershell
.\setup.ps1
```

This will:
- Create PowerShell profile if it doesn't exist
- Add the necessary source lines to your profile
- Set up automatic loading of all scripts in `posh.d`

## Usage

### Python Development
- `py`: Run Python
- `cvenv`: Create virtual environment
- `avenv`: Activate virtual environment
- `dvenv`: Deactivate virtual environment
- `pip-upgrade`: Update all pip packages
- `pt`: Run pytest
- `pr`: Run Django development server

### System Commands
- `sysinfo`: Display system information
- `ports`: List open ports
- `psg`: Process search
- `mem`: Show memory usage
- `disk`: Show disk usage

### File Operations
- `mkcd`: Create and enter directory
- `bak`: Create backup of a file
- `extract`: Extract various archive formats
- `ff`: Find files by pattern

### Requirements
- PowerShell 5.1 or higher
- Git
- Python (optional)
- Vim (optional)
- AutoHotkey v2 (optional)

## Customization

Add your own PowerShell scripts to `posh.d/` and they will be automatically sourced on startup.
