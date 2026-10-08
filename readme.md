# Dotfiles Repository

A unified configuration management system for maintaining consistent development environments across Windows, Linux and macOS.

[![CI](https://github.com/bferg314/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/bferg314/dotfiles/actions/workflows/ci.yml)

## Overview

This repository contains my personal dotfiles. Configuration that is the same everywhere lives once,
in [`shared/`](shared); each OS folder holds only what is genuinely different there — its setup
menu, its installers, and a few platform-specific snippets. It covers:

- Shells — bash (Linux), zsh (macOS), PowerShell 5.1 and 7 (Windows) — with a starship prompt,
  zoxide, fzf key bindings and atuin / PSReadLine history
- Language runtimes through [mise](https://mise.jdx.dev): Node, Python, Go, plus uv and ruff for
  Python — the same versions on every machine. Rust through rustup
- A managed git config, with delta as the pager
- Vim and Neovim from one config — see [docs/vim-plugins.md](docs/vim-plugins.md) for the plugins
  and their keyboard shortcuts
- zellij, yazi, eza, bat, lazygit and other CLI tools
- AutoHotkey scripts (Windows)
- A setup menu that installs and links all of it, the same on all three platforms

## Quick Start

### New Linux Machine (Bootstrap)

Run this on any fresh Linux device — it will walk you through everything:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/bferg314/dotfiles/main/bootstrap.sh)
```

Or with curl:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/bferg314/dotfiles/main/bootstrap.sh)
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
irm https://raw.githubusercontent.com/bferg314/dotfiles/main/bootstrap.ps1 | iex
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
  arch · x86_64 · branch main

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
    [ ] Tailscale (VPN)            · installed, not connected
    [ ] Network discovery (mDNS)   · avahi not running

  MAINTAIN
    [ ] Update from git            ✓ up to date with origin/main
    [ ] Doctor (full report)
```

The menu opens with the baseline a machine is still missing already ticked — links, editor
plugins, shell and base tools. Role-specific tasks (desktop apps, server tools, Tailscale, mDNS)
are never preselected however missing they are, because on a machine of the other kind "not
installed" is the correct permanent state rather than a gap to fill; those come from a preset or
your own tick.

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

## Repository layout

```
shared/                 configuration used on more than one platform
  shell/                  bash + zsh snippets (aliases, functions, history, python, tools...)
    vendor/                 third-party files kept verbatim (bash-preexec)
  vim/.vimrc              the one vimrc, for vim and Neovim on every platform
  nvim/init.vim           Neovim's entry point; sources the vimrc
  mise/config.toml        language runtimes and tooling pinned for every platform
  gup/gup.json            Go tools that only ship as source (folgit), installed by gup
  git/                    gitconfig (included from ~/.gitconfig), delta.gitconfig, global ignore
  zellij/config.kdl       zellij config
  starship/               prompt themes (tokyo.toml is the one linked)
linux/                  setup menu tasks, installers, bash-only snippet (bashrc.d/)
mac/                    setup menu tasks, installers, Brewfile, zsh-only snippet (zshrc.d/)
windows/                setup menu, installers, packages.psd1, PowerShell snippets (posh.d/), AutoHotkey
lib/                    shell libraries shared by linux/ and mac/
  menu.sh                 the setup menu engine
  shared.sh               linking, git includes, mise installs, Doctor reports
  download.sh             GitHub API (token-aware) and SHA-256 verification
tests/                  smoke tests for Linux/macOS and for vim/Neovim (Windows tests: windows/tests/)
docs/                   vim plugin reference
.github/workflows/      CI
```

A rule of thumb for where something goes: if two platforms would hold the same lines, it belongs in
`shared/`. A platform folder only gets a file when the content really differs — GNU vs BSD flags, a
different package manager, PowerShell instead of bash.

## The toolchain

Who installs what, and why:

| Kind of tool | Managed by | Where it is listed |
|---|---|---|
| Language runtimes and their tooling: Node, Python, Go, uv, ruff, gup | **mise**, on every OS | [`shared/mise/config.toml`](shared/mise/config.toml) |
| Go programs that only ship as source, such as [folgit](https://github.com/bferg314/folgit) | **gup** (`go install` into `~/go/bin`), on every OS | [`shared/gup/gup.json`](shared/gup/gup.json) |
| Rust | **rustup**, on every OS | the base installers |
| Apps and CLI tools on macOS | **Homebrew** | [`mac/Brewfile`](mac/Brewfile) |
| Apps and CLI tools on Windows | **winget** | [`windows/packages.psd1`](windows/packages.psd1) |
| Apps and CLI tools on Linux | the distro (pacman / dnf / apt), plus mise for CLI tools distros package late or not at all (starship, zoxide, fzf, eza, bat, delta, lazygit, atuin) | [`linux/installs/base.sh`](linux/installs/base.sh), `shared/mise/config.toml` |
| Release binaries no package manager carries (zellij on Linux, gum, the Nerd Font) | the installers, **SHA-256 verified** | `lib/download.sh`, `windows/common.ps1` |

**Go tools.** [gup](https://github.com/nao1215/gup) manages the binaries `go install` puts in
`~/go/bin`. `Base tools` runs `gup import` on [`shared/gup/gup.json`](shared/gup/gup.json), which
installs each listed tool at its latest version — currently [folgit](https://github.com/bferg314/folgit),
the repo dashboard — and `gup update` keeps everything in `~/go/bin` current afterwards. mise is set
not to move `GOBIN` into its per-version directory (`go.set_gobin = false`), so these tools survive Go
upgrades. folgit's shell integration is loaded automatically, so pressing `g` on a repo in folgit
leaves your shell in it. See [`shared/gup/README.md`](shared/gup/README.md) to add a tool.

mise replaced nvm, the per-platform Python 3.14 packages and the Go tarball/MSI. Because one file
pins the versions, `python`, `node` and `go` are the same version on every machine, and a project can
pin its own with a `mise.toml` (`mise use node@22` writes one). On Linux and macOS the shell runs
`mise activate`; on Windows mise's shims sit at the front of PATH.

**Upgrading from before this toolchain?** Pull, run `dotsetup`, tick *Link dotfiles* and
*Base tools*, and open a new terminal. Then run *Doctor*: it lists what the old setup left behind
(nvm, `/usr/local/go`, or winget's Python / Node.js / Go) with the command that removes each. Nothing
is removed automatically.

### Shell features, on every platform

| Feature | bash / zsh | PowerShell |
|---|---|---|
| Prompt | starship | starship |
| Jump to a directory you have visited: `z foo`, `zi` | zoxide | zoxide |
| History search: Ctrl-R | atuin (full-screen, records directory and exit code) | fzf, through PSFzf |
| Fuzzy-pick a path: Ctrl-T. Fuzzy `cd`: Alt-C | fzf | fzf, through PSFzf |
| Up/Down search history for what is already typed | yes | yes |
| Suggestions from history as you type | — | PSReadLine predictions (F2 switches list/inline) |
| `l` / `ll` / `la` / `lt` (tree) | eza | eza |
| `batp` (bat, no pager), `lg` (lazygit) | yes | yes |
| Python workflow: `cvenv`, `uva`, `uvr`, `pt`, `lint`, `fmt`, `jl` | uv + ruff | uv + ruff |

`ls` itself is never replaced — in PowerShell it keeps returning objects, so pipelines work.

### git

`shared/git/gitconfig` is pulled into `~/.gitconfig` with an `[include]` rather than replacing it, so
your name, email and anything machine-specific stay in `~/.gitconfig` — and win, because they are
read after the include. It sets rebase-on-pull with autostash, `push.autoSetupRemote`, pruning on
fetch, `zdiff3` conflict markers, `histogram` diffs with moved-code highlighting, rerere, branches
sorted by recent use, and a handful of aliases (`git s`, `git lg`, `git amend`, `git undo`,
`git gone`, …). delta becomes the pager through a second include, added only once delta is
installed, since git fails outright when its pager is missing.

## Checks

Every push runs [CI](.github/workflows/ci.yml):

| Job | What it checks |
|---|---|
| lint | shellcheck on every shell file; bash 3.2 syntax for everything macOS runs |
| linux | On Debian 13, Ubuntu 24.04, Fedora 43 and Arch: Link dotfiles, install the whole mise toolchain, then start an interactive bash and check it loads with no errors and every tool and key binding is live |
| macos | The same with zsh and Homebrew, plus a Brewfile parse |
| windows | The PowerShell test suites under 5.1 and 7, and PSScriptAnalyzer (errors fail the build) |
| editor | vim and Neovim install every plugin and start with no errors |

To run them locally:

```bash
# Linux smoke test in a throwaway container (it changes $HOME, so never run it on your machine)
docker run --rm -t -v "$PWD:/repo:ro" debian:13 bash -c \
    'apt-get update -qq && apt-get install -y -qq git curl ca-certificates xz-utils >/dev/null &&
     cp -r /repo /dotfiles && /dotfiles/tests/unix-smoke.sh linux --tools'

# vim + Neovim
docker run --rm -t -v "$PWD:/repo:ro" debian:13 bash -c \
    'apt-get update -qq && apt-get install -y -qq git curl ca-certificates vim neovim >/dev/null &&
     /repo/tests/vim-smoke.sh'

# shellcheck
shellcheck -S warning -x $(git ls-files '*.sh' '*.bashrc' '*.zshrc' | grep -v vendor/)
```

```powershell
# Windows, under both hosts
foreach ($t in Get-ChildItem windows\tests -Filter *.tests.ps1) {
    pwsh -NoProfile -File $t.FullName
    powershell -NoProfile -File $t.FullName
}
```

Line endings: [`.gitattributes`](.gitattributes) keeps shell scripts and the configs Unix tools
read as LF in every checkout, including a Windows one, so a Windows clone can be used from WSL or a
container without bash failing on carriage returns.

## Features

- One configuration for shells, vim, git, zellij and the prompt, shared by all three platforms
- The same language runtimes everywhere, pinned in one file (mise)
- Rust via `rustup` on all three platforms, so toolchains are managed the same way
- One terminal font everywhere — FiraCode Nerd Font Mono at 16, installed from the
  same [nerd-fonts](https://github.com/ryanoasis/nerd-fonts) release on all three platforms
- One setup menu on all three platforms — the same checklist, tasks and run order
- Declarative package lists on macOS (`Brewfile`) and Windows (`packages.psd1`)
- Every directly downloaded binary checked against its published SHA-256
- [yazi](https://yazi-rs.github.io/) TUI file manager on all three platforms, with image,
  video, PDF and archive previews and `fd`/`ripgrep`/`fzf`/`zoxide` jump integrations
- CI on every push: Linux distros, macOS, Windows, and the editor config

## Requirements

### Windows
- PowerShell 5.1 or higher
- winget (App Installer), for the install tasks
- Developer Mode or Administrator, for real symlinks

### Linux
- Bash
- Git
- `curl` (used by the install scripts for mise, rustup, zellij and the font)

### macOS
- Bash 3.2 (what macOS ships — the setup menu runs under it)
- Git
- Homebrew, installed by `mac/installs/base.sh` if missing

### All platforms
- [`gum`](https://github.com/charmbracelet/gum) (optional) — draws the setup menu's checklist.
  Both bootstraps install it; without it the menu falls back to a numbered list.
- A GitHub token is optional but helps: `$GH_TOKEN`, `$GITHUB_TOKEN` or a logged-in `gh` lifts the
  60-an-hour anonymous GitHub API limit the installers would otherwise share with everyone on your
  network.

## License

MIT License
