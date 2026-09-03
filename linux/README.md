# Linux Dotfiles

Configuration files and scripts for setting up a Linux development environment.

## Supported Distributions

| Family | Detected by | `DISTRO` value | Package manager |
|---|---|---|---|
| Arch Linux | `pacman` present | `arch` | `pacman -S --needed --noconfirm` |
| Fedora | `dnf` present, `ID` not RHEL-like | `fedora` | `dnf install -y` |
| AlmaLinux / Rocky / RHEL / CentOS | `dnf` present, `ID` in `almalinux`,`rocky`,`rhel`,`centos` | `rhel` | `dnf install -y` |
| Ubuntu | `apt-get` present, `ID`/`ID_LIKE` is ubuntu | `ubuntu` | `apt-get install -y` |
| Debian | `apt-get` present | `debian` | `apt-get install -y` |

Detection and the package-manager wrappers live in `installs/common.sh`, which
every install script sources. `bootstrap.sh` at the repo root deliberately keeps
its own copy so it can be piped straight from a URL before the repo exists.

## Installation

1. Clone the repository:
```bash
git clone https://github.com/bferg314/dotfiles.git
```

2. Run the setup script:
```bash
cd dotfiles/linux
./setup.sh
```

For a brand-new machine, use the repo-root `bootstrap.sh` instead — see the
[top-level readme](../readme.md).

## Setup Menu (`setup.sh`)

The menu is a checklist, not a list of one-shot options: tick everything this machine
needs, confirm once, and the tasks run in a fixed order. Each row also shows what is
already true, so re-running is informed rather than guesswork.

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
    [ ] Tailscale (VPN)            · not installed
    [ ] Network discovery (mDNS)   · avahi not running

  MAINTAIN
    [ ] Update from git            ✓ up to date with origin/master
    [ ] Doctor (full report)
```

| Task | What it does |
|---|---|
| Link dotfiles | Symlinks `bashrc.d/*` → `~/.bashrc.d/`, `vim/.vimrc` → `~/.vimrc`, `zellij/config.kdl` → `~/.config/zellij/config.kdl`, and appends a `~/.bashrc.d` sourcing block to `~/.bashrc` (and `~/.zshrc` if present) |
| Editor plugins | Downloads `plug.vim` into `~/.vim/autoload/` and `~/.local/share/nvim/site/autoload/` |
| Base tools | Runs `installs/base.sh` |
| Desktop apps | Runs `installs/desktop.sh` |
| Server tools (SSH) | Runs `installs/server.sh` |
| Tailscale (VPN) | Runs `installs/tailscale.sh` — installs the client and enables `tailscaled`. It does not log in; run `sudo tailscale up` yourself |
| Network discovery (mDNS) | Runs `installs/avahi.sh` |
| Update from git | `git pull --ff-only`; if that fails, shows what would be lost and requires typing `yes` before doing a hard reset |
| Doctor (full report) | Prints every check in full, plus git identity, detected distro and shell config. Read-only |

The two presets are shortcuts: ticking one replaces it with the tasks it stands for, so
you can add or remove individual rows afterwards. Tailscale is deliberately in neither —
joining a tailnet is a per-machine decision, so it is only installed by ticking its row.

The menu opens with the **baseline** this machine is still missing already ticked —
`Link dotfiles`, `Editor plugins` and `Base tools`. The role-specific tasks
(`Desktop apps`, `Server tools`, `Tailscale` and `mDNS`) are never preselected,
however missing they are: on a machine of the other kind, "not installed" is the
correct permanent state rather than a gap to fill. They arrive from a preset, or
from your own tick.

Tasks always run in the order above regardless of the order you tick them, and everything
the batch needs — `sudo`, network — is checked once up front rather than failing halfway
through. A task that fails does not stop the rest; a summary at the end says what did and
did not work. Every task is idempotent, so re-running is safe.

### Controls

With [`gum`](https://github.com/charmbracelet/gum) installed, the picker is a real
checklist: arrow keys to move, space to toggle, `/` to filter, enter to confirm. `gum` is
installed by `bootstrap.sh` and by `Base tools`, into `/usr/local/bin` — the same place the
zellij release binary goes, and on PATH everywhere. Without sudo it falls back to
`~/.local/bin` and says so, since nothing here puts that on PATH.

Both pickers show the same rows, the same grouping and the same status column —
`gum` just gives you arrow keys and a filter instead of typing numbers.

Without it the same list is numbered and you type at a prompt — no second dependency, and
it also works over a serial console or with piped input:

| Input | Effect |
|---|---|
| `1 3 5` | Toggle those rows |
| `2-4` | Toggle a range |
| `a` / `n` | Select all / none |
| enter | Run what is ticked |
| `q` | Quit |

---

## What Gets Installed

### `bootstrap.sh` (repo root — day-zero setup)

Run before the repo exists on the machine. Installs the bare minimum, then hands off to `setup.sh`.

| Package | Arch | Fedora | RHEL/Alma/Rocky | Debian/Ubuntu |
|---|---|---|---|---|
| git | `git` | `git` | `git` | `git` |
| vim | `vim` | `vim-enhanced` | `vim-enhanced` | `vim` |
| sudo *(only when run as root)* | `sudo` | `sudo` | `sudo` | `sudo` |
| SSH server | `openssh` | `openssh-server` | `openssh-server` | `openssh-server` |

Also: enables/starts `sshd` (`ssh` on Debian/Ubuntu), optionally creates a regular
user and adds them to `wheel` (Arch/Fedora/RHEL) or `sudo` (Debian/Ubuntu), clones
the dotfiles repo to `~/dotfiles`, sets git `user.name`/`user.email`, generates an
ed25519 SSH key, and appends a pasted public key to `~/.ssh/authorized_keys`.

---

### `installs/base.sh` — Base Tools (all machines)

| Tool | Arch | Fedora | RHEL/Alma/Rocky | Debian/Ubuntu |
|---|---|---|---|---|
| Vim | `vim` | `vim-enhanced` | `vim-enhanced` | `vim` |
| Docker | `docker`, `docker-compose`, `docker-buildx` | `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-compose-plugin` (Docker's Fedora repo) | same packages, Docker's RHEL repo | `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-compose-plugin` (Docker's apt repo) |
| Zellij | `zellij` | latest GitHub release binary → `/usr/local/bin/zellij` | same | same |
| Font | latest Nerd Fonts release → `~/.local/share/fonts/FiraCode` | same | same | same |
| Python 3.14 | `python`, `python-pip` | `python3.14`, `python3-pip` | `python3.14`, `python3-pip` | `python3.14`, `python3.14-venv`, `python3-pip` |
| Node | nvm `v0.40.1` installer + `nvm install --lts` | same | same | same |
| Dev tools | `base-devel` | `@development-tools` | `groupinstall "Development Tools"` | `build-essential` |
| Rust | `rustup` from `sh.rustup.rs` → `~/.cargo` | same | same | same |
| Git | `git` | `git` | `git` | `git` |
| GitHub CLI | `github-cli` | `gh` (GitHub's `gh-cli` repo) | `gh` (GitHub's `gh-cli` repo) | `gh` (GitHub's apt repo) |
| yazi (TUI file manager) | `yazi` | `yazi` (`lihaohong/yazi` COPR) | same COPR | `yazi` (yazi's own apt repo) |
| yazi extras | `ffmpeg`, `7zip`, `jq`, `poppler`, `fd`, `ripgrep`, `fzf`, `zoxide`, `resvg`, `imagemagick` | best-effort subset of the same, whatever `pkg_available` finds | same | same |

Additional actions:
- **Docker repo setup** — Fedora/RHEL: adds `docker-ce.repo` via `dnf config-manager`, handling both dnf4 (`--add-repo`) and dnf5 (`addrepo --from-repofile=`) syntax. Debian/Ubuntu: installs `apt-transport-https ca-certificates curl gnupg lsb-release`, removes stale `docker.list`/`docker.sources` and old keyrings, then adds Docker's key to `/etc/apt/keyrings/docker.gpg` and the repo for the correct `ubuntu`/`debian` path.
- Enables and starts the `docker` service, and adds the current user to the `docker` group (requires re-login).
- The zellij binary is selected by architecture (`x86_64` or `aarch64`); other architectures fail with a clear message rather than installing the wrong binary.
- **FiraCode Nerd Font Mono** is installed per-user from the [ryanoasis/nerd-fonts](https://github.com/ryanoasis/nerd-fonts) release rather than from the distro repos, which package the Nerd variants inconsistently (Arch has `ttf-firacode-nerd`; Fedora and Debian ship only non-Nerd Fira Code). Pulling the release directly also means every machine — Linux, macOS and Windows — lands on the same version. Only the `Mono` faces are copied; `fc-cache -f` refreshes the font list. A font failure warns rather than aborting the base install.
- **Python** is pinned to the 3.14 series. Arch's plain `python` already tracks upstream; Fedora, RHEL
  and Debian/Ubuntu get the versioned `python3.14` package when their repos carry it, checked with
  `pkg_available` first. Where they do not, the default `python3` is installed and the script says so
  rather than failing — `python3` keeps pointing at the distro default either way, so use
  `python3.14` explicitly for new virtualenvs.
- **Rust** comes from the upstream `rustup` installer rather than the distro package: only Arch
  carries a current `rustup`, while Debian and the RHEL family ship a pinned `rustc` with no toolchain
  management. It runs with `--no-modify-path`, so rustup does not append its own block to `~/.bashrc`,
  `~/.profile` and `~/.zshenv` — `bashrc.d/rust.bashrc` puts `~/.cargo/bin` on PATH instead. Installed
  after the development tools, since the default toolchain links with `cc`. A rustup failure warns
  rather than aborting the base install.
- Prompts for git `user.name` / `user.email` if not already set globally.
- The GitHub CLI comes from GitHub's own repo on dnf/apt rather than the distro
  repos, which lag. It is installed but not authenticated — run `gh auth login`
  yourself.
- **yazi** comes from Arch's official repo, the `lihaohong/yazi` Fedora/EL9+ COPR, or
  yazi's own apt repo — none of the four carry a current release in their own repos yet.
  Launch it with `yazi`; image, video, PDF and archive previews work out of the box in a
  terminal with graphics-protocol support (kitty, wezterm, foot, ...). The preview/jump
  extras (`ffmpeg`, `7zip`/`p7zip`, `jq`, `poppler`, `fd`, `ripgrep`, `fzf`, `zoxide`,
  `imagemagick`, and on Arch `resvg`) install best-effort, per package, via
  `pkg_available` — whichever ones this distro's repos do not carry are skipped with a
  warning rather than failing the rest of the base install. Debian/Ubuntu's `fd-find`
  installs its binary as `fdfind`; a symlink to `fd` is added automatically.

---

### `installs/desktop.sh` — Desktop Apps

| App | Arch | Fedora | RHEL/Alma/Rocky | Debian/Ubuntu |
|---|---|---|---|---|
| GUI Vim (clipboard) | `gvim` | `vim-X11` | `vim-X11` | `vim-gtk3` |
| Steam | `steam` (enables `[multilib]`) | `steam` (enables RPM Fusion free + nonfree) | Flatpak `com.valvesoftware.Steam` | `steam-installer`, falling back to `steam` |
| Firefox | `firefox` | `firefox` | `firefox` | `firefox` |
| VS Code | AUR `visual-studio-code-bin` | `code` from `packages.microsoft.com` | `code` from `packages.microsoft.com` | `code` from `packages.microsoft.com` |
| Obsidian | AUR `obsidian` | Flatpak `md.obsidian.Obsidian` | Flatpak `md.obsidian.Obsidian` | `.deb` from `obsidianmd/obsidian-releases` |
| Spotify | AUR `spotify` | Flatpak `com.spotify.Client` | Flatpak `com.spotify.Client` | `spotify-client` from `repository.spotify.com` |
| Discord | `discord` | Flatpak `com.discordapp.Discord` | Flatpak `com.discordapp.Discord` | `.deb` from `discord.com/api/download` |
| GitHub Desktop | AUR `github-desktop-bin` | Flatpak `io.github.shiftey.Desktop` | Flatpak `io.github.shiftey.Desktop` | `.deb` resolved from the `shiftkey/desktop` release API |

Additional actions:
- **Fedora/RHEL only:** installs `flatpak` and adds the Flathub remote first.
- **Arch:** if neither `yay` nor `paru` is present, `yay-bin` is built from the AUR
  automatically so the AUR apps install instead of silently skipping. Must be run
  as a regular user — `makepkg` refuses to run as root.
- **Debian/Ubuntu:** enables the `i386` architecture on amd64 (Steam needs 32-bit
  libraries). Ubuntu enables `multiverse`; Debian ships Steam in `non-free` and
  warns if that component is not enabled.
- All downloads go to a temp directory that is cleaned up on exit, rather than
  into the current working directory.
- **Third-party repos added:** Microsoft (VS Code) on dnf/apt, Spotify on apt,
  RPM Fusion on Fedora, `multilib` on Arch, `multiverse` on Ubuntu.

---

### `installs/server.sh` — Server Tools

| Tool | Arch | Fedora | RHEL/Alma/Rocky | Debian/Ubuntu |
|---|---|---|---|---|
| SSH server | `openssh` | `openssh-server` | `openssh-server` | `openssh-server` |
| Monitoring *(prompted)* | `htop`, `ncdu`, `net-tools` | same | same | same |

Additional actions:
- Enables and starts `sshd` (`ssh` on Debian/Ubuntu).
- **Prompted — key-only SSH auth.** When `sshd_config` uses `Include
  /etc/ssh/sshd_config.d/*.conf`, the settings are written to a high-numbered
  drop-in (`99-dotfiles-hardening.conf`) so distro drop-ins such as Ubuntu's
  `50-cloud-init.conf` cannot override them. Otherwise the main config is edited
  in place with a timestamped backup.
- Refuses to disable password authentication when `~/.ssh/authorized_keys` is
  empty or missing, unless you confirm a second time — that combination locks you
  out of the machine.
- Validates with `sshd -t` before restarting, and reverts if the config is bad.

---

### `installs/base.sh` also installs `gum`

The setup menu's checklist picker. Fetched from the upstream GitHub release the same way zellij and
the Nerd Font are, and installed to `/usr/local/bin`. It is optional — the menu falls back to a
numbered list — so a failure here warns rather than aborting the base install.

Pinned to `v0.17.0` rather than the latest release (and Arch's own package, which carries the same
release, is bypassed too): gum `2.0.0`'s migration to Bubble Tea v2 broke the Space key as a toggle
in `gum choose --no-limit` — `x` and `tab` still work, Space silently does nothing. `0.17.0` is the
last release before that migration. Revert `GUM_PIN_TAG` in `ensure_gum` (`installs/common.sh`)
once upstream fixes it.

### `installs/tailscale.sh` — Tailscale

| Source | Arch | Fedora | RHEL/Alma/Rocky | Debian/Ubuntu |
|---|---|---|---|---|
| Tailscale | `install.sh` | `install.sh` | `install.sh` | `install.sh` |

Unlike every other installer here, this uses upstream's
`curl -fsSL https://tailscale.com/install.sh | sh` on **all** distributions
rather than configuring the package repository itself. Tailscale's repository
URLs embed the Fedora release and the apt codename —
`stable/fedora/39/tailscale.repo`, `stable/ubuntu/noble.noarmor.gpg` — so
hardcoding that mapping here would 404 on any distro release they have not
published for yet. Their script resolves it instead, from one code path. (The
same reasoning as `install_rustup` in `installs/common.sh`, which pipes
`sh.rustup.rs`.)

Additional actions:
- Enables and starts `tailscaled`, best-effort: the client is installed by that
  point, so a machine whose unit is missing or masked gets a warning rather than
  an aborted script.
- Skips the download entirely when `tailscale` is already on `PATH`.
- **Does not log in.** The script prints `sudo tailscale up` and the two flags
  worth knowing about (`--ssh`, `--advertise-exit-node`) and leaves it to you,
  so the task stays non-interactive.

---

### `installs/avahi.sh` — Avahi / mDNS

| Packages | Arch | Fedora | RHEL/Alma/Rocky | Debian/Ubuntu |
|---|---|---|---|---|
| Avahi | `avahi`, `nss-mdns` | `avahi`, `avahi-tools`, `nss-mdns` | `avahi`, `avahi-tools`, `nss-mdns` | `avahi-daemon`, `avahi-utils`, `libnss-mdns` |

Additional actions:
- Enables and starts `avahi-daemon`.
- Inserts `mdns_minimal [NOTFOUND=return]` after `files` on the `hosts:` line of
  `/etc/nsswitch.conf`, preserving `myhostname`, `resolve`, and anything else the
  distro configured. The original file is backed up first.
- Opens UDP 5353 on whichever firewall is actually running: `firewall-cmd
  --add-service=mdns`, `ufw allow 5353/udp`, or a raw `iptables` rule
  (non-persistent). Falls through to the next option if a firewall is installed
  but inactive.
- Makes the machine reachable at `<hostname>.local`.

---

## Configuration Files

### Bash Configuration (`bashrc.d/`)
Symlinked into `~/.bashrc.d/` and sourced by both `~/.bashrc` and `~/.zshrc`.

- **alias-bash.bashrc** — common shell aliases and navigation shortcuts
- **alias-python.bashrc** — Python development environment setup
- **functions.bashrc** — utility functions (mkcd, extract, etc.)
- **hist.bashrc** — enhanced history management
- **list_aliases.bashrc** — tool to list and manage aliases
- **rust.bashrc** — puts `~/.cargo/bin` on PATH and adds the cargo shortcuts (`cb`, `cr`, `ct`, `ck`,
  `cfmt`, `ccl`)

### Vim (`vim/.vimrc`)
Symlinked to `~/.vimrc`. Uses vim-plug; plugins include vim-airline, NERDTree,
Goyo & Limelight, and git integration (fugitive, gitgutter). See
[docs/vim-plugins.md](../docs/vim-plugins.md) for what each plugin does and its keyboard shortcuts.

### Zellij (`zellij/config.kdl`)
Symlinked to `~/.config/zellij/config.kdl`. Zellij is the terminal multiplexer —
installed by `base.sh` on Linux and `mac/installs/base.sh` on macOS. Rounded pane
frames, copy-on-select, and a 10k-line scrollback.

### Shared helpers (`installs/common.sh`)
Sourced by every install script. Provides distro detection, the `pkg_install` /
`pkg_update` / `pkg_available` wrappers, Flatpak and AUR-helper bootstrapping,
temp-directory handling, architecture detection, `install_rustup`, and
`install_nerd_font`.

## Font

The terminal font is **FiraCode Nerd Font Mono** at size 16, the same on every platform. The starship
prompt and vim-airline both draw glyphs that only a Nerd Font provides. `installs/base.sh` installs it;
point your terminal emulator at it afterwards.

## Requirements
- Bash 4.0+
- Git
- `sudo` access (all install scripts use it)
- `curl` (used for nvm, rustup, zellij, the font, and repo keys)
- `fontconfig` for `fc-cache` (the font install warns and continues without it)

## Customization

Add your own Bash scripts to `bashrc.d/` — they will be automatically sourced on
shell startup.
