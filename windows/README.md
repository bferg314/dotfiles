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

### WezTerm (`wezterm/`)
- **.wezterm.lua**: Terminal configuration — launches `pwsh`, FiraCode Nerd Font Mono at 16

### Shared helpers (`common.ps1`)
Colour output, `Install-Package` (idempotent winget wrapper), `New-DotfileLink`, and the privilege
checks. Dot-sourced by `setup.ps1` and every script in `installs/`. The counterpart to
`linux/installs/common.sh`.

## Installation

1. Clone this repository:
```powershell
git clone https://github.com/bferg314/dotfiles.git
```

2. Run the setup script:
```powershell
.\windows\setup.ps1
```

### Menu options

| Option | What it does |
|---|---|
| 1. Create Links | Links every config below and configures both PowerShell profiles |
| 2. Install vim-plug | Downloads `plug.vim` for vim and Neovim |
| 3. Install PowerShell 7 | Installs `pwsh` and configures its profile |
| 4. Install Base Tools | Core dev tooling — **needs Administrator** |
| 5. Install Desktop Apps | GUI applications — **needs Administrator** |
| 6. Install Server Tools | OpenSSH server + optional key-only hardening — **needs Administrator** |
| 7. Update | Fast-forwards the repo; a destructive reset requires typing `yes` |

Every option is idempotent — re-running it is safe and will report what is already in place.

### What gets linked

| Source | Target |
|---|---|
| `windows/vim/.vimrc` | `~\_vimrc` |
| `windows/wezterm/.wezterm.lua` | `~\.wezterm.lua` |
| `starship/tokyo.toml` | `~\.config\starship.toml` |
| `windows/ahk/WindowsShortcuts.ahk` | Startup folder |
| `windows/posh.d/*.ps1` | Sourced from both PowerShell profiles |

The `posh.d` block is written to the **AllHosts** profile for both Windows PowerShell 5.1
(`Documents\WindowsPowerShell\profile.ps1`) and PowerShell 7 (`Documents\PowerShell\profile.ps1`),
so it also loads in the VS Code terminal. The block is delimited by
`# >>> dotfiles posh.d >>>` markers and is rewritten in place on every run, so moving the repo and
re-running option 1 fixes the paths.

### Symlinks and privileges

Windows only permits unprivileged symlink creation when **Developer Mode** is enabled
(Settings → System → For developers). Without it, `Create Links` falls back to a hard link, and
failing that to a plain copy — which will *not* track future repo changes. Enable Developer Mode or
run the setup script as Administrator to get real symlinks.

Any pre-existing real file at a link target is backed up to `<name>.bak-<timestamp>` before being
replaced.

## Packages

Installs use **winget**, which ships with Windows 10 1809+ and Windows 11 as part of "App Installer".
Chocolatey is no longer used. Package IDs live in `installs/base.ps1` and `installs/desktop.ps1`.

There is no `avahi` counterpart to the Linux setup: Windows 10+ resolves `.local` mDNS names natively.
There is no zellij option either — zellij has no native Windows support.

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
- winget (App Installer) — for the install options
- Developer Mode or Administrator — for real symlinks

Git, Python, Vim, starship, WezTerm, AutoHotkey and the terminal font are all installed by
`Install Base Tools`.

## Font

Everything assumes **FiraCode Nerd Font Mono** at size 16 — wezterm sets it directly, and the starship
prompt and vim-airline both draw glyphs that only a Nerd Font provides.

winget carries exactly one Nerd Font (JetBrainsMono), so `Install Base Tools` fetches FiraCode from the
[ryanoasis/nerd-fonts](https://github.com/ryanoasis/nerd-fonts) release instead — see `Install-NerdFont`
in `common.ps1`. It installs per-user (no elevation needed) into `%LOCALAPPDATA%\Microsoft\Windows\Fonts`
and registers each face under `HKCU`, which is what makes a per-user font visible to applications.

Only the `Mono` faces are installed; the archive also ships proportional and non-Mono families that
would otherwise clutter the font list. Terminals other than wezterm (Windows Terminal, VS Code) are not
tracked in this repo — set them to `FiraCode Nerd Font Mono` by hand.

## Customization

Add your own PowerShell scripts to `posh.d/` and they will be automatically sourced on startup.
