# macOS Dotfiles

Configuration files and scripts for setting up a macOS development environment.

Most of the configuration is shared with Linux and lives in [`shared/`](../shared); this folder
holds what is macOS-specific — the setup menu's task table, the installers, the
[`Brewfile`](Brewfile), and one zsh snippet.

## Installation

1. Clone the repository:
```bash
git clone https://github.com/bferg314/dotfiles.git
```

2. Run the setup script:
```bash
./dotfiles/mac/setup.sh
```

The setup script is a checklist, not a list of one-shot options — the same shape as the
Linux and Windows ones. Tick everything this machine needs, confirm once, and the tasks
run in a fixed order. Each row also shows what is already true, so re-running is informed
rather than guesswork.

| Task | What it does |
|---|---|
| Link dotfiles | Symlinks the shell snippets (`shared/shell/*.sh` and `mac/zshrc.d/*`) into `~/.zshrc.d/`, and the shared configs to their usual places (see [Configuration files](#configuration-files)). Adds `shared/git/gitconfig` to `~/.gitconfig` as an `[include]`, plus delta's pager settings once delta is installed. Appends a `~/.zshrc.d` sourcing block to `~/.zshrc` (and `~/.bashrc` if present). A real file already at a link's location is moved to `<name>.bak-<timestamp>` first; links left behind by files that moved in the repo are removed |
| Shell (zsh) | Installs zsh if missing, then offers oh-my-zsh and making zsh the default shell |
| Editor plugins | Downloads `plug.vim` for vim and Neovim |
| Base tools | Runs `installs/base.sh` — see [What Base tools installs](#what-base-tools-installs) |
| Desktop apps | Runs `installs/desktop.sh` |
| Server tools (SSH) | Runs `installs/server.sh` |
| Tailscale (VPN) | Runs `installs/tailscale.sh` — installs the `tailscale-app` cask. Approve its system extension in System Settings, then `tailscale up` |
| Update from git | `git pull --ff-only`; if that fails, shows what would be lost and requires typing `yes` before doing a hard reset |
| Doctor (full report) | Prints every check in full, plus git identity, Homebrew version, shell config, the versions mise has active, whether the Go tools from `shared/gup/gup.json` are installed, whether the shared git config is included, and leftovers from the old toolchain (`~/.nvm`, nvm lines in your rc files, `/usr/local/go`) with the command that removes each. Read-only |

The two presets at the top are shortcuts: ticking one replaces it with the tasks it stands
for, so you can add or remove individual rows afterwards. Tailscale is deliberately in
neither — joining a tailnet is a per-machine decision, so it is only installed by ticking
its row.

The menu opens with the **baseline** this machine is still missing already ticked —
`Link dotfiles`, `Editor plugins`, `Shell` and `Base tools`. The role-specific tasks
(`Desktop apps`, `Server tools` and `Tailscale`) are never preselected, however
missing they are: on a machine of the other kind, "not installed" is the correct
permanent state rather than a gap to fill. They arrive from a preset, or from
your own tick.

Tasks always run in the order above regardless of the order you tick them, and everything
the batch needs is checked once up front rather than failing halfway through. A task that
fails does not stop the rest; a summary at the end says what did and did not work. Every
task is idempotent, so re-running is safe.

With [`gum`](https://github.com/charmbracelet/gum) installed (`Base tools` installs it),
the picker is a real checklist — arrow keys, space to toggle, `/` to filter. Without it
the same list is numbered and you type `1 3 5`, `2-4`, `a`, `n`, enter to run, or `q` to
quit. Both show the same rows, grouping and status column.

Once the links are in place, `dotsetup` reopens this menu from anywhere.

The menu engine is shared with Linux (`lib/menu.sh`), and so are the linking and toolchain helpers
(`lib/shared.sh`); only the task table in `tasks.sh` differs. All of it runs under the bash 3.2
that macOS ships, which CI checks on every push.

## What Base tools installs

`installs/base.sh` installs the Xcode Command Line Tools and Homebrew if they are missing, then:

| What | From | Notes |
|---|---|---|
| Everything in [`Brewfile`](Brewfile) | `brew bundle` | git, gh, vim, neovim, zellij, mise, starship, zoxide, fzf, atuin, eza, bat, git-delta, lazygit, fd, ripgrep, jq, shellcheck, yazi and its preview extras, Docker Desktop |
| gum | GitHub release, SHA-256 verified | Pinned to `v0.17.0` — see `ensure_gum` in `installs/common.sh` |
| FiraCode Nerd Font Mono | GitHub release, SHA-256 verified | Same release as Linux and Windows |
| rustup | `sh.rustup.rs` | Same installer as Linux |
| node (LTS), python 3.14, go, uv, ruff, gup | mise, from [`shared/mise/config.toml`](../shared/mise/config.toml) | Replaces nvm, Homebrew's `python@3.14` and the `/usr/local/go` tarball |
| folgit, and any other Go tool in [`shared/gup/gup.json`](../shared/gup/gup.json) | `gup import` → `~/go/bin` | Built from source with mise's Go; `gup update` keeps them current |

The Brewfile is the one list of what Homebrew installs on a Mac. To add a tool, add a line there and
re-run Base tools (or `brew bundle --file=mac/Brewfile`). `brew bundle check --file=mac/Brewfile`
shows what is missing without installing anything, and `brew bundle cleanup --file=mac/Brewfile`
lists what is installed but not in the file.

Runtimes are not in the Brewfile on purpose: mise owns them on every platform, so a version pinned in
`shared/mise/config.toml` is the version you get on macOS, Linux and Windows alike.

The first `Base tools` run after mise is in place also imports your existing zsh history into atuin,
and adds delta as git's pager.

## Configuration files

| Repo file | Linked to |
|---|---|
| `shared/shell/*.sh` | `~/.zshrc.d/` |
| `mac/zshrc.d/alias-zsh.zshrc` | `~/.zshrc.d/` |
| `shared/vim/.vimrc` | `~/.vimrc` |
| `shared/nvim/init.vim` | `~/.config/nvim/init.vim` (skipped if you have an `init.lua`) |
| `shared/zellij/config.kdl` | `~/.config/zellij/config.kdl` |
| `shared/starship/tokyo.toml` | `~/.config/starship.toml` |
| `shared/mise/config.toml` | `~/.config/mise/config.toml` |
| `shared/git/ignore` | `~/.config/git/ignore` |
| `shared/git/gitconfig` | `[include]`d from `~/.gitconfig` |
| `shared/git/delta.gitconfig` | `[include]`d from `~/.gitconfig`, once delta is installed |

### Shell snippets (`~/.zshrc.d/`)

Sourced, in name order, by the block Link dotfiles adds to `~/.zshrc`. Everything except
`alias-zsh.zshrc` is shared with bash on Linux — the
[Linux readme](../linux/README.md#shell-snippets-bashrcd) describes each file.

- **alias-zsh.zshrc** — the zsh/macOS-only bits: BSD `ls` colours, `rc` (reload `~/.zshrc`),
  `ports` (`lsof`), `disk`, `flushdns`, and `dotsetup`
- **tools.sh** — `mise activate zsh`, zoxide, fzf key bindings, atuin, starship, the eza / bat /
  lazygit shortcuts, and folgit's shell integration

**oh-my-zsh:** starship replaces oh-my-zsh's theme, because `tools.sh` initialises it after
oh-my-zsh has loaded. Set `ZSH_THEME=""` in `~/.zshrc` so oh-my-zsh does not draw a prompt
first. Its plugins keep working.

### Vim
`shared/vim/.vimrc`, one config for every platform and for Neovim. See
[docs/vim-plugins.md](../docs/vim-plugins.md) for what each plugin does and its keyboard shortcuts.

## Font

The terminal font is **FiraCode Nerd Font Mono** at size 16, the same on every platform. `installs/base.sh`
installs it into `~/Library/Fonts` from the [ryanoasis/nerd-fonts](https://github.com/ryanoasis/nerd-fonts)
release — the same source the Linux and Windows installers use, so every machine ends up on an identical
version. (Homebrew's `font-fira-code-nerd-font` cask would also work, but versions would drift.) Only the
`Mono` faces are installed; point Terminal/iTerm at it afterwards.

## Requirements
- macOS with zsh (the default since Catalina)
- Xcode Command Line Tools and Homebrew — `Base tools` installs both

## Customization

- **Something for every machine:** add a `*.sh` file to `shared/shell/` (zsh and bash both source
  it), or a zsh-only one to `mac/zshrc.d/`, and re-run Link dotfiles.
- **Something for this machine only:** put a file straight into `~/.zshrc.d/`. Link dotfiles only
  manages links that point into the repo, so it leaves your own files alone.
- **A Homebrew package:** add it to `Brewfile`.
- **A runtime version:** `mise use -g node@22` for this machine; edit `shared/mise/config.toml`
  for every machine.
