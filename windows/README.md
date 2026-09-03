# Windows Dotfiles

This directory contains configuration files and scripts for setting up a Windows development environment.

## Components

### PowerShell Configuration (`posh.d/`)
- **alias-python.ps1**: Python development environment aliases and functions
- **rust.ps1**: cargo shortcuts, and `~\.cargo\bin` on PATH for the current session
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
  - Goyo & Limelight for distraction-free writing

  See [docs/vim-plugins.md](../docs/vim-plugins.md) for what each plugin does and its keyboard shortcuts.

### AutoHotkey Scripts (`ahk/`)
- **WindowsShortcuts.ahk**: Custom keyboard shortcuts for Windows

### TUI File Manager
- **yazi**: installed by `Base tools` via winget (`sxyazi.yazi`), along with its
  preview/navigation extras — ffmpeg, 7-Zip (already installed above), jq, poppler, fd,
  ripgrep, fzf, zoxide and ImageMagick. Each installs independently via `Install-Package`,
  so one failing package does not block the rest. Launch with `yazi`. `resvg` (SVG preview)
  has no winget package yet; install it with Scoop if you want it.

### Zellij (`zellij/`)
- **config.kdl**: Rounded pane frames, copy-on-select, 10k-line scrollback — the same settings as the
  Linux and macOS copies. It is a separate file only because `default_shell` has to differ
  (`bash` / `zsh` / `pwsh`) and zellij's config format has no include mechanism. Without the
  `pwsh` line zellij falls back to `cmd.exe`, even when launched from PowerShell
  ([zellij#4897](https://github.com/zellij-org/zellij/issues/4897)).

### Shared helpers (`common.ps1`)
Colour output, `Install-Package` (idempotent winget wrapper), `New-DotfileLink`, and the privilege
checks. Dot-sourced by `setup.ps1` and every script in `installs/`. The counterpart to
`linux/installs/common.sh`.

### DISM needs Windows PowerShell, even under pwsh

`Get-WindowsCapability` and `Add-WindowsCapability` are DISM cmdlets, and DISM's COM interfaces are
registered only for Windows PowerShell. Under PowerShell 7 they do not merely misbehave — they
throw **"Class not registered"** before doing any work.

That is a trap here specifically, because this repo installs PowerShell 7, points your terminal at
it, and makes it the SSH shell. pwsh is therefore the *likeliest* shell for these scripts to run
under, and anything reaching for a Windows capability from one would fail every time.

So nothing calls those cmdlets directly. `Install-WindowsCapabilityByPattern` in `common.ps1` runs
them inline when already in Windows PowerShell, and otherwise hands the work to `powershell.exe`
5.1 as an `-EncodedCommand`, reporting back through a `RESULT:` marker so stray DISM output cannot
be mistaken for the answer. `bootstrap.ps1` carries its own trimmed copy, as it does for
`Install-Package`, because it is fetched and run on its own.

`windows/tests/menu.tests.ps1` walks the AST of both files and fails if either calls a DISM cmdlet
anywhere outside that helper.

### Reading installed state without winget

The `Desktop apps` row reads the Uninstall registry keys, not `winget list`. Parsing winget made a
*status hint* depend on winget being resolvable, so a shell that could not find it showed `?` —
no information at all — about apps that were plainly installed. winget still installs things; it is
just not needed to look at them.

Resolving winget for the install path is its own small problem, since it ships as an App Execution
Alias on the *user's* PATH: an elevated shell routinely reports it missing on a machine that has it.
`Get-WingetPath` tries PATH, then `%LOCALAPPDATA%\Microsoft\WindowsApps`, then the `WindowsApps`
package payload, and `Doctor` prints which of the three answered. (Not `Get-AppxPackage` — `Appx` is
another Windows PowerShell-only module, so it throws in pwsh, which is precisely the shell needing
the fallback.)

### Menu engine (`menu.ps1`)
The task table, the two pickers, the preflight checks and the runner. `setup.ps1` registers its
tasks with `Add-MenuTask` and calls `Invoke-Menu`; everything the menu shows is derived from those
rows, so adding a task is one call and the numbering cannot drift out of sync with what the numbers
do. The counterpart to `lib/menu.sh`, which Linux and macOS share, and deliberately the same shape.

## Installation

### Day zero (`bootstrap.ps1`)

On a machine with nothing installed, run the bootstrap from the repo root instead — it installs git,
clones this repo, sets your git identity, generates an SSH key for GitHub, and hands off to
`setup.ps1`:

```powershell
irm https://raw.githubusercontent.com/bferg314/dotfiles/master/bootstrap.ps1 | iex
```

The counterpart to `bootstrap.sh`, with the differences Windows forces:

| `bootstrap.sh` | `bootstrap.ps1` |
|---|---|
| Detects pacman / dnf / apt | Requires winget (one target, so it only checks) |
| Installs `sudo` when run as root | Nothing — elevation is per-process on Windows |
| Offers to create a regular user | Nothing — you are already a normal user |
| Installs `openssh-server` | Adds the `OpenSSH.Server` capability + a TCP/22 firewall rule, **elevated only** |
| Key goes in `~/.ssh/authorized_keys` | Administrators' keys go in `%ProgramData%\ssh\administrators_authorized_keys`, with the ACL sshd demands |

Running unelevated is supported; it skips the SSH-server step and says so up front.

### Existing machine

1. Clone this repository:
```powershell
git clone https://github.com/bferg314/dotfiles.git
```

2. Run the setup script:
```powershell
.\windows\setup.ps1
```

### Menu tasks

The menu is a checklist, not a list of one-shot options — the same shape as the Linux and
macOS ones. Tick everything this machine needs, confirm once, and the tasks run in a fixed
order. Each row also shows what is already true, so re-running is informed rather than
guesswork.

| Task | What it does |
|---|---|
| Link dotfiles | Links every config below and configures both PowerShell profiles |
| Shell (PowerShell 7) | Installs `pwsh` and configures its profile |
| Editor plugins | Downloads `plug.vim` for vim and Neovim |
| Base tools | Core dev tooling — **needs Administrator** |
| Desktop apps | GUI applications — **needs Administrator** |
| Server tools (SSH) | OpenSSH server, PowerShell 7 as the SSH shell, optional key-only hardening — **needs Administrator** |
| Tailscale (VPN) | Installs the Tailscale client — **needs Administrator**. It does not log in; run `tailscale up` yourself |
| Update from git | Fast-forwards the repo; a destructive reset requires typing `yes` |
| Doctor (full report) | Prints every check in full, plus git identity, symlink capability and winget version. Read-only |

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
the batch needs — winget, an elevated shell, network — is checked once up front rather
than failing halfway through. Picking a task whose installer calls `Assert-Admin` in an
unelevated shell is refused before anything runs, not after. A task that fails does not stop the rest; a summary at
the end says what did and did not work. Every task is idempotent — re-running it is safe
and will report what is already in place.

### Controls

With [`gum`](https://github.com/charmbracelet/gum) installed, the picker is a real
checklist: arrow keys to move, space to toggle, `/` to filter, enter to confirm. `gum` is
installed by `bootstrap.ps1` and by `Base tools`.

Both pickers show the same rows, the same grouping and the same status column —
`gum` just gives you arrow keys and a filter instead of typing numbers.

Without it the same list is numbered and you type at a prompt — no second dependency, and
it also works with redirected input:

| Input | Effect |
|---|---|
| `1 3 5` | Toggle those rows |
| `2-4` | Toggle a range |
| `a` / `n` | Select all / none |
| enter | Run what is ticked |
| `q` | Quit |

### SSH sessions get PowerShell 7

`Server tools` sets `HKLM:\SOFTWARE\OpenSSH\DefaultShell` to `pwsh.exe`, unprompted. Without that
key sshd hands an incoming session `cmd.exe`, where none of the `posh.d` config loads — not what
anyone setting a machine up from these dotfiles wants. If PowerShell 7 is not installed yet it falls
back to Windows PowerShell 5.1 and says so; run the `Shell (PowerShell 7)` task and re-run this one.

Installing the OpenSSH server itself goes through the Windows capability store, not winget, so the
task is not gated on winget being available. Only the optional monitoring extras at the end use it,
and they skip themselves with a warning if it is missing rather than taking a working SSH server
down with them.

### What gets linked

| Source | Target |
|---|---|
| `windows/vim/.vimrc` | `~\_vimrc` |
| `starship/tokyo.toml` | `~\.config\starship.toml` |
| `windows/zellij/config.kdl` | `%APPDATA%\Zellij\config\config.kdl` |
| `windows/ahk/WindowsShortcuts.ahk` | Startup folder |
| `windows/posh.d/*.ps1` | Sourced from both PowerShell profiles |

The `posh.d` block is written to the **AllHosts** profile for both Windows PowerShell 5.1
(`Documents\WindowsPowerShell\profile.ps1`) and PowerShell 7 (`Documents\PowerShell\profile.ps1`),
so it also loads in the VS Code terminal. The block is delimited by
`# >>> dotfiles posh.d >>>` markers and is rewritten in place on every run, so moving the repo and
re-running `Link dotfiles` fixes the paths.

`Link dotfiles` also removes a leftover `~\.wezterm.lua` link on machines set up before wezterm was
dropped from this repo. A `.wezterm.lua` of your own is left alone — only links pointing into
`windows\wezterm\` are removed.

### Symlinks and privileges

Windows only permits unprivileged symlink creation when **Developer Mode** is enabled
(Settings → System → For developers). Without it, `Link dotfiles` falls back to a hard link, and
failing that to a plain copy — which will *not* track future repo changes. Enable Developer Mode or
run the setup script as Administrator to get real symlinks.

Any pre-existing real file at a link target is backed up to `<name>.bak-<timestamp>` before being
replaced.

## Tests

There is no test framework here — `windows/tests/*.tests.ps1` are plain scripts that print
PASS/FAIL and exit non-zero on failure. Run one directly:

```powershell
pwsh -NoProfile -File windows\tests\wezterm-cleanup.tests.ps1
pwsh -NoProfile -File windows\tests\menu.tests.ps1
```

They are worth running under **both** hosts, since `setup.ps1` supports Windows PowerShell 5.1 as
well as PowerShell 7:

```powershell
powershell -NoProfile -File windows\tests\wezterm-cleanup.tests.ps1
```

Cases that need something the machine may not have are skipped rather than failed — the symlink
cases need Developer Mode or an elevated shell, and the fixture cases need the git history. A run
that skips everything still exits 0, so check the counts.

`wezterm-cleanup.tests.ps1` covers `Remove-LegacyWeztermLink`, which deletes the `~\.wezterm.lua`
left behind on machines set up before wezterm was dropped. It gets the function and its hash table
out of `setup.ps1` through the PowerShell parser rather than duplicating them, and points `$HOME` at
a sandbox, so it tests the shipped source without touching your real config.

## Packages

Installs use **winget**, which ships with Windows 10 1809+ and Windows 11 as part of "App Installer".
Chocolatey is no longer used. Package IDs live in `installs/base.ps1` and `installs/desktop.ps1`.

`bootstrap.ps1` and `Install Base Tools` both install **UniGetUI** (`Devolutions.UniGetUI`), a GUI over
winget, scoop, chocolatey, pip and npm. Its package id has moved twice — WingetUI, then
`MartiCliment.UniGetUI` — and the older ids now resolve only to the pre-release channel, so the
current one is pinned explicitly.

There is no `avahi` counterpart to the Linux setup: Windows 10+ resolves `.local` mDNS names natively.

## Usage

### Rust Development
- `cb` / `cr` / `ct`: cargo build / run / test
- `ck`: cargo check
- `cfmt`: cargo fmt
- `ccl`: cargo clippy

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

### Dotfiles
- `dotsetup`: Open the setup menu from anywhere, the same as the Linux `dotsetup`. Available once
  `Create Links` has configured your profile and you have opened a new shell.

### File Operations
- `mkcd`: Create and enter directory
- `bak`: Create backup of a file
- `extract`: Extract various archive formats
- `ff`: Find files by pattern

### Requirements
- PowerShell 5.1 or higher
- winget (App Installer) — for the install options
- Developer Mode or Administrator — for real symlinks

Git, Python 3.14, Vim, zellij, starship, rustup, AutoHotkey, UniGetUI and the terminal font are all
installed by `Install Base Tools`.

`rustup` is installed after the VS Build Tools on purpose: the default `x86_64-pc-windows-msvc`
toolchain needs the MSVC linker, and rustup only warns about a missing one rather than failing.
`cargo` and `rustc` are on PATH in a new shell.

## Font

Everything assumes **FiraCode Nerd Font Mono** at size 16 — the starship prompt and vim-airline both
draw glyphs that only a Nerd Font provides.

winget carries exactly one Nerd Font (JetBrainsMono), so `Install Base Tools` fetches FiraCode from the
[ryanoasis/nerd-fonts](https://github.com/ryanoasis/nerd-fonts) release instead — see `Install-NerdFont`
in `common.ps1`. It installs per-user (no elevation needed) into `%LOCALAPPDATA%\Microsoft\Windows\Fonts`
and registers each face under `HKCU`, which is what makes a per-user font visible to applications.

Only the `Mono` faces are installed; the archive also ships proportional and non-Mono families that
would otherwise clutter the font list. No terminal emulator config is tracked in this repo, so set
whichever one you use (Windows Terminal, VS Code) to `FiraCode Nerd Font Mono` by hand.

## Customization

Add your own PowerShell scripts to `posh.d/` and they will be automatically sourced on startup.
