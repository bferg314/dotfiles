# Dotfiles Repository

A unified configuration management system for maintaining consistent development environments across Windows, Linux and macOS.

## Overview

This repository contains my personal dotfiles, organized by operating system. It includes configurations for:

- Shell environments (PowerShell, Bash, Zsh)
- Python development tools
- Rust toolchain (rustup)
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

### New Windows Machine (Bootstrap)

Run this in PowerShell on any fresh Windows device — it walks through the same steps as the Linux
bootstrap:

```powershell
irm https://raw.githubusercontent.com/bferg314/dotfiles/master/bootstrap.ps1 | iex
```

This will:
1. Install `git`, `vim` and `UniGetUI` via winget, plus the OpenSSH client
2. Clone this repo to `%USERPROFILE%\dotfiles`
3. Set up your git username and email
4. Generate an SSH key to import into GitHub
5. Add a public SSH key so you can remote in without a password

Run it **as Administrator** to also install and start the OpenSSH *server*, and to write the key to
`administrators_authorized_keys` — the only authorized-keys file Windows sshd reads for members of
the Administrators group.

### Windows (existing machine)

```powershell
git clone https://github.com/bferg314/dotfiles.git
.\dotfiles\windows\setup.ps1
```

The same menu as the Linux and macOS ones: link configs, install tooling via winget, set up an SSH
server, and update the repo. See the [Windows Setup Guide](windows/README.md) for the full task
list, what gets linked where, and the Developer Mode requirement for symlinks.

### Linux (existing machine)

```bash
git clone https://github.com/bferg314/dotfiles.git
./dotfiles/linux/setup.sh
```

See the [Linux Setup Guide](linux/README.md) for the full task list and what each installer puts on
the machine.

### macOS (existing machine)

```bash
git clone https://github.com/bferg314/dotfiles.git
./dotfiles/mac/setup.sh
```

See the [macOS Setup Guide](mac/readme.md) for details.

## The setup menu

All three platforms present the same menu: a checklist of tasks rather than a list of one-shot
options. Tick everything the machine needs, confirm once, and they run in a fixed order — links
before installs — with the current state of each shown alongside, so re-running is informed rather
than guesswork.

```
  Dotfiles Setup
  arch · x86_64 · branch master

  PRESETS
    [ ] Workstation preset
    [ ] Server preset

  CONFIGURE
    [x] Link dotfiles              · not linked
    [x] Editor plugins             · not installed

  INSTALL
    [x] Base tools                 · missing: docker, gh, rustup
    [ ] Desktop apps               ✓ installed
    [ ] Server tools (SSH)         · sshd not enabled
    [ ] Network discovery (mDNS)   · avahi not running

  MAINTAIN
    [ ] Update from git            ✓ up to date with origin/master
    [ ] Doctor (full report)
```

Everything the batch needs — `sudo` or an elevated shell, winget, network — is checked once before
anything runs, rather than failing halfway through. A task that fails does not stop the rest, and a
summary at the end says what did and did not work.

The checklist is drawn by [`gum`](https://github.com/charmbracelet/gum), a single prebuilt binary
that both bootstraps install. It is optional: without it the same list is numbered and you type
`1 3 5`, `2-4`, `a`, `n`, enter to run, or `q` to quit — which also works over a serial console or
with piped input.

Tasks are defined once per platform in a table (`linux/tasks.sh`, `mac/tasks.sh`, and the
`Add-MenuTask` calls in `windows/setup.ps1`), and the listing, run order, status column and
preflight checks are all derived from it. Linux and macOS share one engine in `lib/menu.sh`;
`windows/menu.ps1` is its PowerShell counterpart.

Once the links are in place, `dotsetup` reopens the menu from anywhere on all three platforms.

## Features

- Cross-platform Python development environment, pinned to the same 3.14 series everywhere
- Rust via `rustup` on all three platforms, so toolchains are managed the same way
- Consistent shell aliases across operating systems
- One terminal font everywhere — FiraCode Nerd Font Mono at 16, installed from the
  same [nerd-fonts](https://github.com/ryanoasis/nerd-fonts) release on all three platforms
- One setup menu on all three platforms — the same checklist, tasks and run order
- Version control integration
- Productivity shortcuts and utilities

## Requirements

### Windows
- PowerShell 5.1 or higher
- winget (App Installer), for the install tasks
- Developer Mode or Administrator, for real symlinks

### Linux
- Bash
- Git
- `curl` (used by the install scripts for rustup, nvm, zellij and the font)
- Python 3.14 (optional)

### macOS
- Bash 3.2 (what macOS ships — the setup menu runs under it)
- Git
- Homebrew, installed by `mac/installs/base.sh` if missing
- Python 3.14 (optional)

### All platforms
- [`gum`](https://github.com/charmbracelet/gum) (optional) — draws the setup menu's checklist.
  Both bootstraps install it; without it the menu falls back to a numbered list.

## License

MIT License