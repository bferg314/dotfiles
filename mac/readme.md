# macOS Dotfiles

Configuration files and scripts for setting up a macOS development environment.

## Components

### Shell Configuration (`zshrc.d/`)
- **alias-zsh.zshrc**: Common shell aliases and navigation shortcuts
- **alias-python.zshrc**: Python development environment setup
- **functions.zshrc**: Utility functions (mkcd, extract, etc.)
- **hist.zshrc**: Enhanced history management
- **list_aliases.zshrc**: Tool to list and manage aliases
- **rust.zshrc**: Puts `~/.cargo/bin` on PATH and adds the cargo shortcuts

### Vim Configuration (`vim/`)
- **.vimrc**: Vim editor setup with plugins:
  - vim-airline for status line
  - NERDTree for file navigation
  - Goyo & Limelight for distraction-free writing
  - Git integration (fugitive, gitgutter)

### Terminal Multiplexer
- **zellij/config.kdl**: zellij configuration (linked to `~/.config/zellij/config.kdl`)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/dotfiles.git
```

2. Run the setup script:
```bash
cd dotfiles/mac
chmod +x setup.sh
./setup.sh
```

The setup script is a checklist, not a list of one-shot options — the same shape as the
Linux and Windows ones. Tick everything this machine needs, confirm once, and the tasks
run in a fixed order. Each row also shows what is already true, so re-running is informed
rather than guesswork.

| Task | What it does |
|---|---|
| Link dotfiles | Symlinks `zshrc.d/*` → `~/.zshrc.d/`, `vim/.vimrc` → `~/.vimrc`, `zellij/config.kdl` → `~/.config/zellij/config.kdl`, and appends a `~/.zshrc.d` sourcing block to `~/.zshrc` (and `~/.bashrc` if present) |
| Shell (zsh) | Installs zsh if missing, then offers oh-my-zsh and making zsh the default shell |
| Editor plugins | Downloads `plug.vim` for vim and Neovim |
| Base tools | Runs `installs/base.sh` |
| Desktop apps | Runs `installs/desktop.sh` |
| Server tools (SSH) | Runs `installs/server.sh` |
| Tailscale (VPN) | Runs `installs/tailscale.sh` — installs the `tailscale-app` cask. Approve its system extension in System Settings, then `tailscale up` |
| Update from git | `git pull --ff-only`; if that fails, shows what would be lost and requires typing `yes` before doing a hard reset |
| Doctor (full report) | Prints every check in full, plus git identity, Homebrew version and shell config. Read-only |

The two presets at the top are shortcuts: ticking one replaces it with the tasks it stands
for, so you can add or remove individual rows afterwards. Tailscale is deliberately in
neither — joining a tailnet is a per-machine decision, so it is only installed by ticking
its row.

Tasks always run in the order above regardless of the order you tick them, and everything
the batch needs is checked once up front rather than failing halfway through. A task that
fails does not stop the rest; a summary at the end says what did and did not work. Every
task is idempotent, so re-running is safe.

With [`gum`](https://github.com/charmbracelet/gum) installed (`Base tools` installs it),
the picker is a real checklist — arrow keys, space to toggle, `/` to filter. Without it
the same list is numbered and you type `1 3 5`, `2-4`, `a`, `n`, enter to run, or `q` to
quit.

Once the links are in place, `dotsetup` reopens this menu from anywhere.

The menu engine is shared with Linux (`lib/menu.sh`); only the task table in `tasks.sh`
differs. It runs under the bash 3.2 that macOS ships.

## Features

### Shell Enhancements
- Directory navigation shortcuts (u1-u5)
- Enhanced command history
- File extraction utilities
- System monitoring shortcuts

### Python Development
- Virtual environment management
- Code formatting tools
- Package management helpers

`installs/base.sh` installs Homebrew's `python@3.14` — the same series the Linux and Windows
installers target. It is keg-only, so `python3` keeps pointing at whatever else Homebrew has linked
until you put its `libexec/bin` on PATH; the script prints that path when it finishes.

### Rust Development
- `rustup` from the upstream installer (not Homebrew's formula), so all three platforms manage
  toolchains the same way. It runs with `--no-modify-path` and `zshrc.d/rust.zshrc` puts
  `~/.cargo/bin` on PATH instead, keeping the shell config in this repo.
- `cb`, `cr`, `ct`, `ck`, `cfmt`, `ccl` — cargo build / run / test / check / fmt / clippy

### Terminal Multiplexing
- zellij with rounded pane frames
- Copy on select
- 10k line scrollback

## Font

The terminal font is **FiraCode Nerd Font Mono** at size 16, the same on every platform. `installs/base.sh`
installs it into `~/Library/Fonts` from the [ryanoasis/nerd-fonts](https://github.com/ryanoasis/nerd-fonts)
release — the same source the Linux and Windows installers use, so every machine ends up on an identical
version. (Homebrew's `font-fira-code-nerd-font` cask would also work, but versions would drift.) Only the
`Mono` faces are installed; point Terminal/iTerm at it afterwards.

## Requirements
- zsh
- Git
- Vim (optional)
- zellij (optional)
- Python 3.14 (optional)
- Rust via rustup (optional)

## Customization

Add your own Zsh scripts to `zshrc.d/` - they will be automatically sourced on shell startup.
