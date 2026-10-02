# Shell integrations for the toolchain: mise, PSReadLine, zoxide, fzf (via
# PSFzf), and shortcuts for eza / bat / lazygit. The PowerShell counterpart to
# shared/shell/tools.sh. starship stays in zprompt.ps1, which sorts last.
#
# Every block is guarded, so a machine that has not run Base tools yet gets a
# plain shell rather than an error per missing tool. Shell start-up time is
# the constraint throughout: anything that would spawn a process on every
# start is cached or deferred until first use.

# ─── Cached init scripts ──────────────────────────────────────────────────────
#
# `<tool> init powershell` prints a script to evaluate. Running it on every
# start costs a process spawn per tool, so the output is cached under
# %LOCALAPPDATA%\dotfiles\init and regenerated only when the tool's binary is
# newer than the cache -- i.e. after an upgrade.
#
# Returns the cache path for the caller to dot-source. It cannot dot-source it
# itself: that would define the init script's functions inside this function's
# scope, where they vanish as soon as it returns.
function Get-CachedInitScript {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][System.Management.Automation.CommandInfo]$Command,
        [Parameter(Mandatory)][string[]]$Arguments
    )
    $cache = Join-Path $env:LOCALAPPDATA "dotfiles\init\$Name.ps1"
    $cached = Get-Item -LiteralPath $cache -ErrorAction SilentlyContinue
    $binary = Get-Item -LiteralPath $Command.Source -ErrorAction SilentlyContinue
    if (-not $cached -or ($binary -and $cached.LastWriteTime -lt $binary.LastWriteTime)) {
        $null = New-Item -ItemType Directory -Force -Path (Split-Path $cache)

        # Both encodings matter, because PowerShell 7 and Windows PowerShell 5.1
        # share this cache. The tool's output is read as UTF-8 (5.1 would
        # otherwise decode it with the console's OEM code page), and the file
        # is written WITH a BOM: 5.1 reads a BOM-less file as ANSI, which turns
        # the init scripts' non-ASCII characters into smart quotes -- string
        # delimiters to PowerShell -- and the file no longer parses.
        $previous = [Console]::OutputEncoding
        try {
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            $text = (& $Command.Source @Arguments) -join "`r`n"
        } finally {
            [Console]::OutputEncoding = $previous
        }
        [System.IO.File]::WriteAllText($cache, $text, (New-Object System.Text.UTF8Encoding $true))
    }
    return $cache
}

# ─── mise ─────────────────────────────────────────────────────────────────────
#
# Shims rather than `mise activate pwsh`: activation re-evaluates the
# environment on every prompt, which on Windows costs a visible pause, while a
# shim only runs when you call the tool it stands for. Shims still honour a
# project's mise.toml, because each one resolves the version for the current
# directory when it runs.
#
# Prepended rather than appended, so mise's node/python/go win over any
# winget-installed copies still on the machine PATH from before mise.
$miseShims = Join-Path $env:LOCALAPPDATA 'mise\shims'
if ((Test-Path -LiteralPath $miseShims) -and ($env:Path -split ';' -notcontains $miseShims)) {
    $env:Path = "$miseShims;$env:Path"
}
Remove-Variable miseShims

# Where `go install` -- and gup, for the tools in shared/gup/gup.json -- puts
# binaries. mise leaves GOBIN unset (go.set_gobin = false), so it is Go's own
# default. Base tools adds it to the user PATH too; this covers a session that
# started before that.
$goBin = if ($env:GOBIN) { $env:GOBIN } else { Join-Path $HOME 'go\bin' }
if ((Test-Path -LiteralPath $goBin) -and ($env:Path -split ';' -notcontains $goBin)) {
    $env:Path = "$env:Path;$goBin"
}
Remove-Variable goBin

# ─── PSReadLine ───────────────────────────────────────────────────────────────
#
# Only in a host that loaded PSReadLine (the console, Windows Terminal, the VS
# Code terminal); the ISE and redirected hosts do not, and the cmdlets would
# throw there.
if (Get-Module PSReadLine) {
    $psrl = (Get-Module PSReadLine).Version

    # Up/Down search history for lines starting with what is already typed --
    # the same binding as bash and zsh in shared/shell/history.sh.
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # Tab cycles through a menu of completions instead of one at a time.
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

    # Predictions: suggestions from your history (and, in PowerShell 7.2+, from
    # plugins such as Az or CompletionPredictor) as you type. ListView shows a
    # dropdown; F2 switches to an inline ghost-text suggestion and back. Right
    # arrow or End accepts an inline suggestion.
    #
    # Windows PowerShell 5.1 ships PSReadLine 2.0, which predates predictions.
    if ($psrl -ge [version]'2.2' -and $PSVersionTable.PSVersion -ge [version]'7.2') {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView
    } elseif ($psrl -ge [version]'2.1') {
        Set-PSReadLineOption -PredictionSource History
    }

    # (PSReadLine 2.2+ already keeps lines that look like they hold a password,
    # token or API key out of the history file, so no filter is added here.)

    Remove-Variable psrl
}

# ─── zoxide ───────────────────────────────────────────────────────────────────
#
# `z foo` jumps to the best-ranked directory matching "foo"; `zi foo` picks
# from a list with fzf. It learns from every directory change.
$zoxide = Get-Command zoxide -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($zoxide) {
    . (Get-CachedInitScript -Name zoxide -Command $zoxide -Arguments @('init', 'powershell'))
}
Remove-Variable zoxide

# ─── fzf (PSFzf) ──────────────────────────────────────────────────────────────
#
# Ctrl-R: fuzzy history search.  Ctrl-T: fuzzy-pick a path and paste it.
# Alt-C: fuzzy-pick a directory and cd into it. The same keys as bash/zsh.
#
# Bound lazily: importing PSFzf adds a noticeable fraction of a second to every
# shell start, so each key imports it on first press instead. Until Base tools
# has installed the module, Ctrl-R falls back to PSReadLine's own search.
if ((Get-Module PSReadLine) -and (Get-Command fzf -ErrorAction SilentlyContinue)) {
    if (Get-Command fd -ErrorAction SilentlyContinue) {
        $env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --follow --exclude .git'
        $env:FZF_CTRL_T_COMMAND = $env:FZF_DEFAULT_COMMAND
        $env:FZF_ALT_C_COMMAND = 'fd --type d --hidden --follow --exclude .git'
    }
    if (Get-Command bat -ErrorAction SilentlyContinue) {
        $env:FZF_CTRL_T_OPTS = "--preview 'bat --color=always --style=numbers --line-range=:200 {}'"
    }

    function Invoke-DotfilesFzfKey {
        param([Parameter(Mandatory)][string]$Handler, [scriptblock]$Fallback)
        if (-not (Get-Command $Handler -ErrorAction SilentlyContinue)) {
            Import-Module PSFzf -ErrorAction SilentlyContinue
        }
        if (Get-Command $Handler -ErrorAction SilentlyContinue) {
            & $Handler
        } elseif ($Fallback) {
            & $Fallback
        }
    }

    Set-PSReadLineKeyHandler -Key Ctrl+r -BriefDescription 'fzf history' -ScriptBlock {
        Invoke-DotfilesFzfKey -Handler Invoke-FzfPsReadlineHandlerHistory -Fallback {
            [Microsoft.PowerShell.PSConsoleReadLine]::ReverseSearchHistory()
        }
    }
    Set-PSReadLineKeyHandler -Key Ctrl+t -BriefDescription 'fzf path' -ScriptBlock {
        Invoke-DotfilesFzfKey -Handler Invoke-FzfPsReadlineHandlerProvider
    }
    Set-PSReadLineKeyHandler -Key Alt+c -BriefDescription 'fzf cd' -ScriptBlock {
        Invoke-DotfilesFzfKey -Handler Invoke-FzfPsReadlineHandlerSetLocation
    }
}

# ─── Modern CLI replacements ──────────────────────────────────────────────────
#
# `ls` / `dir` / `Get-ChildItem` are left alone: they return objects you can
# pipe into Where-Object and Select-Object, which eza's text output cannot
# replace. The short forms are the ones that change.
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function l  { eza --group-directories-first --icons=auto @args }
    function ll { eza -l --git --group-directories-first --icons=auto @args }
    function la { eza -la --git --group-directories-first --icons=auto @args }
    function lt { eza --tree --level=2 --group-directories-first --icons=auto @args }
    # aliases.ps1 maps ll to Get-ChildItem for machines without eza; an alias
    # outranks a function of the same name, so drop it here.
    if (Test-Path Alias:ll) { Remove-Item Alias:ll -Force }
}

# bat pages long files, so it does not replace cat (an alias for Get-Content,
# which pipelines need). batp is the plain, no-pager form for quick looks.
if (Get-Command bat -ErrorAction SilentlyContinue) {
    function batp { bat --paging=never --style=plain @args }
}

if (Get-Command lazygit -ErrorAction SilentlyContinue) {
    Set-Alias -Name lg -Value lazygit
}

# folgit (installed into ~\go\bin by gup, see shared/gup/): a dashboard of
# every repo under a folder. Its init defines a `folgit` wrapper function, so
# pressing `g` on a repo quits folgit and leaves this shell in that repo.
# Cached like zoxide's, so it costs no process spawn per shell start.
$folgit = Get-Command folgit -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($folgit) {
    . (Get-CachedInitScript -Name folgit -Command $folgit -Arguments @('init', 'powershell'))
}
Remove-Variable folgit
