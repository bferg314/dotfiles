# winget packages for the Windows "Base tools" task -- the one list of what
# winget installs on a Windows machine, and the counterpart to mac/Brewfile.
# windows/installs/base.ps1 installs these in order, each one independently,
# so a single failure is reported at the end rather than stopping the rest.
#
# Each entry: Id (the exact winget id), Name (shown in progress output), and
# optionally ExtraArgs (passed through to `winget install`). Group is only for
# reading. `winget show --id <Id>` describes a package before you add it.
#
# Not here, on purpose:
#   * node, python, go, uv, ruff -- mise owns runtimes (shared/mise/config.toml)
#   * the Nerd Font               -- not on winget; same GitHub release as Linux/macOS
#   * desktop apps                -- windows/installs/desktop.ps1 (an opt-in task)
#   * PSFzf                       -- a PowerShell module, installed by base.ps1
@{
    Packages = @(
        # ── Core ───────────────────────────────────────────────────────────
        @{ Group = 'Core'; Id = 'Git.Git';              Name = 'Git' }
        @{ Group = 'Core'; Id = 'GitHub.cli';           Name = 'GitHub CLI' }
        @{ Group = 'Core'; Id = 'vim.vim';              Name = 'Vim' }
        @{ Group = 'Core'; Id = 'Neovim.Neovim';        Name = 'Neovim' }
        @{ Group = 'Core'; Id = 'jdx.mise';             Name = 'mise' }
        @{ Group = 'Core'; Id = 'Docker.DockerDesktop'; Name = 'Docker Desktop' }
        # A GUI over winget/scoop/chocolatey/pip/npm. Published as
        # MartiCliment.UniGetUI (and WingetUI before that) until the project
        # moved to Devolutions; the old ids now resolve only to pre-releases.
        @{ Group = 'Core'; Id = 'Devolutions.UniGetUI'; Name = 'UniGetUI' }

        # ── Shell: prompt, navigation, setup menu ──────────────────────────
        @{ Group = 'Shell'; Id = 'Starship.Starship';     Name = 'starship' }
        @{ Group = 'Shell'; Id = 'ajeetdsouza.zoxide';    Name = 'zoxide' }
        @{ Group = 'Shell'; Id = 'junegunn.fzf';          Name = 'fzf' }
        @{ Group = 'Shell'; Id = 'charmbracelet.gum';     Name = 'gum' }
        @{ Group = 'Shell'; Id = 'AutoHotkey.AutoHotkey'; Name = 'AutoHotkey' }
        # Upstream ships an official x86_64-pc-windows-msvc MSI, which winget
        # packages, so unlike Linux this needs no manual release fetch.
        @{ Group = 'Shell'; Id = 'Zellij.Zellij';         Name = 'zellij' }

        # ── Modern CLI tools ───────────────────────────────────────────────
        # atuin has no native Windows build; PSReadLine predictions and PSFzf's
        # Ctrl-R cover the same ground there.
        @{ Group = 'CLI'; Id = 'eza-community.eza';       Name = 'eza' }
        @{ Group = 'CLI'; Id = 'sharkdp.bat';             Name = 'bat' }
        @{ Group = 'CLI'; Id = 'dandavison.delta';        Name = 'delta' }
        @{ Group = 'CLI'; Id = 'JesseDuffield.lazygit';   Name = 'lazygit' }
        @{ Group = 'CLI'; Id = 'sharkdp.fd';              Name = 'fd' }
        @{ Group = 'CLI'; Id = 'BurntSushi.ripgrep.MSVC'; Name = 'ripgrep' }
        @{ Group = 'CLI'; Id = 'jqlang.jq';               Name = 'jq' }
        @{ Group = 'CLI'; Id = 'koalaman.shellcheck';     Name = 'shellcheck' }
        # curl is omitted: curl.exe ships with Windows 10 1803+.
        @{ Group = 'CLI'; Id = 'JernejSimoncic.Wget';     Name = 'wget' }
        @{ Group = 'CLI'; Id = '7zip.7zip';               Name = '7-Zip' }

        # ── Build tools ────────────────────────────────────────────────────
        # The build-essential equivalent. The C++ workload has to be requested
        # through --override, since the base package installs the shell only.
        # Must come before rustup: the default x86_64-pc-windows-msvc toolchain
        # needs the MSVC linker, and rustup only warns about a missing one.
        @{ Group = 'Build'; Id = 'Microsoft.VisualStudio.2022.BuildTools'; Name = 'VS Build Tools'
           ExtraArgs = @('--override', '--quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended') }
        @{ Group = 'Build'; Id = 'Rustlang.Rustup'; Name = 'rustup' }

        # ── yazi (TUI file manager) and its preview extras ────────────────
        # resvg (SVG preview) has no winget package yet, per yazi's own docs.
        @{ Group = 'yazi'; Id = 'sxyazi.yazi';             Name = 'yazi' }
        @{ Group = 'yazi'; Id = 'Gyan.FFmpeg';             Name = 'ffmpeg' }
        @{ Group = 'yazi'; Id = 'oschwartz10612.Poppler';  Name = 'poppler' }
        @{ Group = 'yazi'; Id = 'ImageMagick.ImageMagick'; Name = 'ImageMagick' }
    )

    # Installed by an earlier version of this repo, and now provided by mise
    # instead. base.ps1 never uninstalls them -- it lists the ones still
    # present so you can remove them when you are ready.
    Superseded = @(
        @{ Id = 'Python.Python.3.14'; Name = 'Python 3.14'; By = 'mise (python)' }
        @{ Id = 'OpenJS.NodeJS.LTS';  Name = 'Node.js LTS'; By = 'mise (node)' }
        @{ Id = 'GoLang.Go';          Name = 'Go';          By = 'mise (go)' }
    )
}
