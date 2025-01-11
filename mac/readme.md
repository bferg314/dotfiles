# macOS Dotfiles

Configuration files and scripts for setting up a macOS development environment.

## Components

### Shell Configuration (`zshrc.d/`)
- **alias-zsh.zshrc**: Common shell aliases and navigation shortcuts
- **alias-python.zshrc**: Python development environment setup
- **functions.zshrc**: Utility functions (mkcd, extract, etc.)
- **hist.zshrc**: Enhanced history management
- **list_aliases.zshrc**: Tool to list and manage aliases

### Vim Configuration (`vim/`)
- **.vimrc**: Vim editor setup with plugins:
  - vim-airline for status line
  - NERDTree for file navigation
  - Goyo & Limelight for distraction-free writing
  - Git integration (fugitive, gitgutter)

### Terminal Multiplexers
- **tmux/.tmux.conf**: tmux configuration with custom prefix and splits
- **screen/.screenrc**: GNU Screen configuration with status bar

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

The setup script provides options to:
- Create symbolic links for all dotfiles
- Install Vim-Plug
- Install Oh My Zsh
- Update the repository

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

### Terminal Multiplexing
- Custom tmux prefix (Ctrl+A)
- Easy window splitting
- Informative status bars
- Screen session management

## Requirements
- zsh
- Git
- Vim (optional)
- tmux/screen (optional)
- Python (optional)

## Customization

Add your own Zsh scripts to `zshrc.d/` - they will be automatically sourced on shell startup.
