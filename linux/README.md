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

| # | Option | What it does |
|---|---|---|
| 1 | Create Links | Symlinks `bashrc.d/*` → `~/.bashrc.d/`, `vim/.vimrc` → `~/.vimrc`, `zellij/config.kdl` → `~/.config/zellij/config.kdl`, and appends a `~/.bashrc.d` sourcing block to `~/.bashrc` (and `~/.zshrc` if present) |
| 2 | Install VimPlug | Downloads `plug.vim` into `~/.vim/autoload/` and `~/.local/share/nvim/site/autoload/` |
| 3 | Install zsh | Installs `zsh`, optionally Oh My Zsh, optionally `chsh` to zsh |
| 4 | Install Base Tools | Runs `installs/base.sh` |
| 5 | Install Desktop Apps | Runs `installs/desktop.sh` |
| 6 | Install Server Tools | Runs `installs/server.sh` |
| 7 | Install Avahi (mDNS) | Runs `installs/avahi.sh` |
| 8 | Update | `git pull --ff-only`; if that fails, shows what would be lost and requires typing `yes` before doing a hard reset |
| 9 | Quit | |

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
| Python | `python`, `python-pip` | `python3`, `python3-pip` | `python3`, `python3-pip` | `python3`, `python3-pip` |
| Node | nvm `v0.40.1` installer + `nvm install --lts` | same | same | same |
| Dev tools | `base-devel` | `@development-tools` | `groupinstall "Development Tools"` | `build-essential` |
| Git | `git` | `git` | `git` | `git` |

Additional actions:
- **Docker repo setup** — Fedora/RHEL: adds `docker-ce.repo` via `dnf config-manager`, handling both dnf4 (`--add-repo`) and dnf5 (`addrepo --from-repofile=`) syntax. Debian/Ubuntu: installs `apt-transport-https ca-certificates curl gnupg lsb-release`, removes stale `docker.list`/`docker.sources` and old keyrings, then adds Docker's key to `/etc/apt/keyrings/docker.gpg` and the repo for the correct `ubuntu`/`debian` path.
- Enables and starts the `docker` service, and adds the current user to the `docker` group (requires re-login).
- The zellij binary is selected by architecture (`x86_64` or `aarch64`); other architectures fail with a clear message rather than installing the wrong binary.
- Prompts for git `user.name` / `user.email` if not already set globally.

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

### Vim (`vim/.vimrc`)
Symlinked to `~/.vimrc`. Uses vim-plug; plugins include vim-airline, NERDTree,
Goyo & Limelight, and git integration (fugitive, gitgutter).

### Zellij (`zellij/config.kdl`)
Symlinked to `~/.config/zellij/config.kdl`. Zellij is the terminal multiplexer —
installed by `base.sh` on Linux and `mac/installs/base.sh` on macOS. Rounded pane
frames, copy-on-select, and a 10k-line scrollback.

### Shared helpers (`installs/common.sh`)
Sourced by every install script. Provides distro detection, the `pkg_install` /
`pkg_update` wrappers, Flatpak and AUR-helper bootstrapping, temp-directory
handling, and architecture detection.

## Requirements
- Bash 4.0+
- Git
- `sudo` access (all install scripts use it)
- `curl` (used for nvm, zellij, and repo keys)

## Customization

Add your own Bash scripts to `bashrc.d/` — they will be automatically sourced on
shell startup.
