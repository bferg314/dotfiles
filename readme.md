# Dotfiles Repository

A unified configuration management system for maintaining consistent development environments across Windows and Linux systems.

## Overview

This repository contains my personal dotfiles, organized by operating system. It includes configurations for:

- Shell environments (PowerShell, Bash)
- Python development tools
- Vim editor
- AutoHotkey scripts (Windows)
- Various system utilities and aliases

## Quick Start

### New Linux Machine (Bootstrap)

Run this on any fresh Linux device — it will walk you through everything:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/bferg314/dotfiles/master/bootstrap.sh)
```

Or with curl:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/bferg314/dotfiles/master/bootstrap.sh)
```

This will:
1. Install `git` and `vim`
2. Clone this repo to `~/dotfiles`
3. Set up your git username and email
4. Generate an SSH key to import into GitHub
5. Add a public SSH key so you can remote in without a password

### Windows

```powershell
git clone https://github.com/bferg314/dotfiles.git
.\dotfiles\windows\setup.ps1
```

A menu that mirrors the Linux one: link configs, install tooling via winget, set up an SSH server,
and update the repo. See the [Windows Setup Guide](windows/README.md) for the full option list, what
gets linked where, and the Developer Mode requirement for symlinks.

### Linux (existing machine)
- Source the required `.bashrc` files
- See [Linux Setup Guide](linux/README.md) for detailed instructions

## Features

- Cross-platform Python development environment
- Consistent shell aliases across operating systems
- Automated setup scripts
- Version control integration
- Productivity shortcuts and utilities

## Requirements

### Windows
- PowerShell 5.1 or higher
- winget (App Installer), for the install options
- Developer Mode or Administrator, for real symlinks

### Linux
- Bash
- Git
- Python (optional)

## License

MIT License