# AGENTS.md

Guidance for AI coding agents working in this repository. Human-facing docs are in
[readme.md](readme.md) and the per-platform guides; read the top-level readme's "Repository layout"
and "The toolchain" sections before making structural changes.

## Workflow: always on a new branch

1. **Before changing anything, create a new branch from an up-to-date `master`.** Never commit to
   `master` directly, even for a one-line fix.
   ```sh
   git switch master && git pull --ff-only
   git switch -c claude/<short-kebab-topic>      # e.g. claude/add-gup-folgit
   ```
2. Do the work on that branch, and commit with the conventions below.
3. **Stop there.** Do not push, open a pull request or merge on your own initiative. The owner
   reviews the work, asks for a PR when it looks right, and merges it themselves.
4. When asked for a PR: push the branch and open it against `master` with `gh pr create`. Describe
   what changed, why, and how it was tested, including what could *not* be tested (a platform
   you could not run, an installer you did not execute).

If you find unrelated uncommitted changes when you start, ask before touching them.

## Commits

Conventional-commit style, matching the history:

```
<type>(<scope>): <imperative summary, lower case, no full stop>
```

- Types: `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `ci`, `chore`.
- Scopes in use: `base`, `windows`, `linux`, `mac`, `setup`, `bootstrap`, `vim`, `starship`,
  `zprompt`, `gum`, `mise`, `git`, `shell`.
- The body explains *why*, especially for a workaround (name the upstream bug or version).
- One logical change per commit. Keep moves (`git mv`) separate from edits to the moved file
  where practical, so history follows the file.

## Layout and where things go

```
shared/     config used on more than one platform: shell/ (bash+zsh snippets), vim/, nvim/,
            mise/config.toml, gup/gup.json, git/, zellij/, starship/
linux/      setup task table (tasks.sh), installers (installs/), bash-only snippet (bashrc.d/)
mac/        same shape, plus Brewfile; zsh-only snippet in zshrc.d/
windows/    setup.ps1 + menu.ps1, installers, packages.psd1, PowerShell snippets (posh.d/), tests/
lib/        bash libraries shared by linux/ and mac/: menu.sh, shared.sh, download.sh
tests/      unix-smoke.sh, vim-smoke.sh (Windows tests live in windows/tests/)
```

**The rule:** if two platforms would hold the same lines, they belong in `shared/`. A platform
folder only gets a file when its content genuinely differs (GNU vs BSD flags, a different package
manager, PowerShell instead of bash).

Where a new tool goes:

| Kind of tool | Add it to |
|---|---|
| Language runtime or language tooling | `shared/mise/config.toml` |
| CLI tool distros lack or ship stale (Linux) | the `os = ["linux"]` block of the mise config |
| Homebrew package (macOS) | `mac/Brewfile` |
| winget package (Windows) | `windows/packages.psd1` (verify the id with `winget show --id`) |
| Distro package (Linux) | `linux/installs/base.sh`, guarded with `pkg_available` where names vary |
| Go program shipped only as source | `shared/gup/gup.json` |
| Binary fetched from a GitHub release | an installer function that **verifies the published SHA-256** (`verify_sha256` / `Test-FileSha256`) |

A new tool usually also needs: a shell integration in `shared/shell/tools.sh` **and**
`windows/posh.d/tools.ps1`, a status-probe entry (`status_base` / `Get-BaseStatus`), and docs.

## Platform constraints (these have all bitten before)

- **macOS runs `setup.sh` under bash 3.2.** Anything in `lib/`, `mac/` or sourced by them: no
  `declare -A`, `readarray`, `${x^^}`, `&>>`, or `local -n`. CI checks syntax under real bash 3.2.
- **`shared/shell/*.sh` is sourced by both bash and zsh.** Branch on `$BASH_VERSION` /
  `$ZSH_VERSION` where they differ (`history`, `bind` vs `bindkey`, `forget`). Each file starts
  with `# shellcheck shell=bash`. Files are sourced in name order; `tools.sh` relies on that.
- **PowerShell must work in both Windows PowerShell 5.1 and PowerShell 7.**
  - `.ps1`/`.psd1` files containing any non-ASCII character need a **UTF-8 BOM**, or 5.1 misreads
    them. Files read by other tools (zellij's `.kdl`, gitconfig) must have **no** BOM.
  - DISM/`Appx` cmdlets fail under pwsh; follow `Install-WindowsCapabilityByPattern`.
  - Native command output inside a function becomes its return value. Use `Start-Process`
    (see `Install-Package`) or pipe to `Out-Host`/`Out-Null`.
  - When spawning the *other* edition, clear `PSModulePath` for the child (see `base.ps1`).
- **Line endings:** `.gitattributes` forces LF for shell scripts and Unix-read configs. Do not
  "fix" a working copy that shows CRLF warnings on Windows.
- **git config:** shared settings are `[include]`d at the **top** of `~/.gitconfig` so the
  user's own settings win. Never append includes with `git config --add include.path`.
- **mise:** `go.set_gobin = false` must stay, or `go install` tools vanish on Go upgrades.

## Conventions in the scripts

- **Idempotent everything.** Every task must be safe to re-run and should report what is already
  in place rather than redoing it.
- **Never destroy user state.** Back up a real file before replacing it (`<name>.bak-<timestamp>`);
  only remove links that point into this repo; never uninstall software. Report leftovers in
  Doctor with the command that removes them, and let the user run it.
- **One failure does not stop the batch.** Installers warn and continue (`|| warn ...` under
  `set -e`; `$global:DotfilesFailedPackages` on Windows) and summarise at the end.
- **Status probes run on every menu redraw** — keep them cheap (no network, no package-manager
  queries; `mise ls` is the most expensive thing allowed).
- **Menu tasks are rows in a table** (`menu_task` in `*/tasks.sh`, `Add-MenuTask` in
  `windows/setup.ps1`). Keep ids, groups and order consistent across all three platforms.
- **Shell start-up time matters.** Guard every integration with `command -v` / `Get-Command`.
  On Windows, cache `<tool> init` output with `Get-CachedInitScript`, and defer slow module
  imports to first use (see the PSFzf key handlers).
- **Comments explain why**, not what: the reason for a workaround, the bug it avoids, the
  upstream issue. Match the density of the surrounding code; this repo is commented heavily on
  purpose.

## Testing

**Never run setup, installers or `tests/unix-smoke.sh` on the host machine.** They change `$HOME`,
install software and edit shell profiles. Use containers.

| What | Command |
|---|---|
| shellcheck | `shellcheck -S warning -x $(git ls-files '*.sh' '*.bashrc' '*.zshrc' \| grep -v vendor/)` |
| bash 3.2 syntax | `docker run --rm -v "$PWD:/repo:ro" bash:3.2 bash -n /repo/lib/menu.sh` (and the other `lib/`, `mac/` files) |
| Linux end to end | see readme.md → "Checks" (`tests/unix-smoke.sh linux --tools` in a Debian/Fedora/Arch container) |
| vim + Neovim | `tests/vim-smoke.sh` in a Debian container (see readme.md) |
| Windows | `pwsh -NoProfile -File windows/tests/<name>.tests.ps1`, **and** the same with `powershell` (5.1) |

On Windows from Git Bash:

- Mounting the repo into Docker needs `MSYS_NO_PATHCONV=1` and `$(cygpath -w "$PWD")`.
- The checkout has CRLF endings, so copy it with CRs stripped before running shell scripts in a
  container.
- Run 5.1 with `env -u PSModulePath powershell ...`, or it inherits pwsh's module path.

Windows tests are plain scripts (PASS/FAIL, exit code), not Pester; follow the harness in
`windows/tests/toolchain.tests.ps1`. Lift functions out of `setup.ps1` through the PowerShell
parser rather than dot-sourcing it (that starts the menu).

When you add behaviour, add a test where it can fail for the right reason. Check that a new check
actually fails when the thing it guards is broken.

CI (`.github/workflows/ci.yml`) runs all of the above on every push, plus a macOS job that cannot
be run locally. Say so in the PR when macOS-specific code is untested.

## Documentation

Update docs in the same branch as the change:

- `readme.md` for anything cross-platform: layout, toolchain table, checks.
- `linux/README.md`, `mac/readme.md`, `windows/README.md` for task tables, what gets installed and
  where, and what gets linked.
- `docs/vim-plugins.md` for any `.vimrc` change.
- `shared/gup/README.md` and `shared/shell/vendor/README.md` when their contents change.

Docs state what the code does, so verify claims against the code (or a test run) rather than
intent.

## Things not to do

- Don't add a per-platform copy of a config that could be shared.
- Don't download and execute anything without checksum verification, except through an
  installer that verifies itself (mise.run, rustup, Homebrew's).
- Don't pin to `latest` where upstream has a known regression; pin and explain (see `ensure_gum`).
- Don't introduce new dependencies for the setup menu itself. It must run on a fresh machine with
  only bash/PowerShell and git (`gum` is optional).
- Don't edit files under `shared/shell/vendor/`; replace them from upstream.
