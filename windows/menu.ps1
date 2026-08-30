# Setup-menu engine for windows\setup.ps1.
#
# Dot-source this file, do not run it. The counterpart to lib/menu.sh, and
# deliberately the same shape: the same task-table schema, the same groups, the
# same run-order semantics and the same two-tier picker, so the Windows menu
# reads like the Linux and macOS ones.
#
# Requires common.ps1 (Write-Ok, Write-Warn, ...) to be dot-sourced first.
# Targets Windows PowerShell 5.1 as well as PowerShell 7.

# ─── Task table ───────────────────────────────────────────────────────────────
#
# Every part of the menu -- the listing, the run order, the status column, the
# preflight checks -- is derived from these rows, so adding a task is one call
# and the numbering can never drift out of sync with what the numbers do.

$script:MenuTasks = @()

function Add-MenuTask {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][ValidateSet('presets', 'configure', 'install', 'maintain')][string]$Group,
        [Parameter(Mandatory)][int]$Order,
        [scriptblock]$Handler,
        [scriptblock]$Probe,
        [string[]]$Flags = @(),
        # For a preset: the ids it stands for.
        [string[]]$Expand = @()
    )

    $script:MenuTasks += [pscustomobject]@{
        Id      = $Id
        Label   = $Label
        Group   = $Group
        Order   = $Order
        Handler = $Handler
        Probe   = $Probe
        Flags   = $Flags
        Expand  = $Expand
        State   = 'none'
        Detail  = ''
    }
}

# Tasks in canonical run order, which is independent of display position.
function Get-MenuRunOrder { $script:MenuTasks | Sort-Object Order }

function Get-MenuTask {
    param([Parameter(Mandatory)][string]$Id)
    $script:MenuTasks | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
}

# What a probe returns.
function New-MenuStatus {
    param(
        [ValidateSet('done', 'todo', 'unknown')][string]$State = 'unknown',
        [string]$Detail = ''
    )
    return [pscustomobject]@{ State = $State; Detail = $Detail }
}

# ─── Status probing ───────────────────────────────────────────────────────────

# The detail column is one cell on one row. A probe that returns something
# taller -- and an exception message is routinely several lines -- would push
# the rest of the table down the screen, so keep the first line only.
function ConvertTo-MenuDetail {
    param([string]$Text)
    if (-not $Text) { return '' }
    $line = ($Text -split "`r?`n")[0].Trim()
    if ($line.Length -gt 72) { $line = $line.Substring(0, 69) + '...' }
    return $line
}

# Probes are best-effort: one that throws renders as "?" rather than taking the
# menu down with it.
function Update-MenuStatus {
    foreach ($task in $script:MenuTasks) {
        if (-not $task.Probe) {
            $task.State = 'none'
            $task.Detail = ''
            continue
        }
        try {
            $result = & $task.Probe
            if ($result) {
                $task.State = $result.State
                $task.Detail = ConvertTo-MenuDetail $result.Detail
            } else {
                $task.State = 'unknown'
                $task.Detail = ''
            }
        } catch {
            $task.State = 'unknown'
            $task.Detail = ConvertTo-MenuDetail $_.Exception.Message
        }
    }
}

# ─── Selection ────────────────────────────────────────────────────────────────

$script:MenuSelected = @()

function Test-MenuSelected {
    param([Parameter(Mandatory)][string]$Id)
    return ($script:MenuSelected -contains $Id)
}

function Select-MenuTask {
    param([Parameter(Mandatory)][string]$Id)
    if (-not (Test-MenuSelected $Id)) { $script:MenuSelected += $Id }
}

function Unselect-MenuTask {
    param([Parameter(Mandatory)][string]$Id)
    $script:MenuSelected = @($script:MenuSelected | Where-Object { $_ -ne $Id })
}

function Switch-MenuTask {
    param([Parameter(Mandatory)][string]$Id)
    if (Test-MenuSelected $Id) { Unselect-MenuTask $Id } else { Select-MenuTask $Id }
}

function Clear-MenuSelection { $script:MenuSelected = @() }

function Select-MenuAll {
    foreach ($task in $script:MenuTasks) {
        if ($task.Group -ne 'presets') { Select-MenuTask $task.Id }
    }
}

# The baseline this machine is still missing.
#
# Two things are deliberately never preselected. Maintain tasks (update, doctor)
# are things you ask for. And so is anything flagged `optin`: for a role-specific
# task, "not installed" is not a gap to be filled, it is the correct permanent
# state on a machine of the other kind. Without that distinction a server -- where
# desktop apps are absent by design -- opens with Steam and Discord ticked, and
# the one destructive direction becomes the default.
function Select-MenuDefaults {
    Clear-MenuSelection
    foreach ($task in $script:MenuTasks) {
        if ($task.Group -in @('configure', 'install') -and
            $task.State -eq 'todo' -and
            -not ($task.Flags -contains 'optin')) {
            Select-MenuTask $task.Id
        }
    }
}

# Replace presets in the selection with the tasks they stand for.
function Expand-MenuSelection {
    foreach ($task in $script:MenuTasks) {
        if ($task.Expand.Count -gt 0 -and (Test-MenuSelected $task.Id)) {
            Unselect-MenuTask $task.Id
            foreach ($id in $task.Expand) { Select-MenuTask $id }
        }
    }
}

# ─── Rendering ────────────────────────────────────────────────────────────────

$script:MenuTitle = 'Dotfiles Setup'

# Overridable by the caller to describe the machine.
function Get-MenuPlatformLine {
    $os = try { (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption } catch { 'Windows' }
    $parts = @($os.Trim())
    if ($env:PROCESSOR_ARCHITECTURE) { $parts += $env:PROCESSOR_ARCHITECTURE }
    $parts += "PowerShell $($PSVersionTable.PSVersion)"
    return ($parts -join ' · ')
}

function Show-MenuHeader {
    $branch = ''
    if ($REPO_ROOT) {
        $branch = (git -C $REPO_ROOT rev-parse --abbrev-ref HEAD 2>$null)
    }
    $line = Get-MenuPlatformLine
    if ($branch) { $line = "$line · branch $branch" }

    Write-Host ""
    Write-Host "  $script:MenuTitle" -ForegroundColor Cyan
    Write-Host "  $line" -ForegroundColor Blue
    Write-Host ""
}

function Get-MenuGroupTitle {
    param([string]$Group)
    switch ($Group) {
        'presets'   { 'PRESETS' }
        'configure' { 'CONFIGURE' }
        'install'   { 'INSTALL' }
        'maintain'  { 'MAINTAIN' }
        default     { $Group.ToUpper() }
    }
}

# The list, grouped, with a checkbox on the left and current state on the right.
# Numbers are display-only: they are assigned here and used only by the
# fallback picker, so nothing downstream depends on them.
$script:MenuDisplay = @()

function Show-MenuList {
    param([switch]$Numbered)

    $width = ($script:MenuTasks | ForEach-Object { $_.Label.Length } | Measure-Object -Maximum).Maximum
    $script:MenuDisplay = @()
    $n = 0

    foreach ($group in @('presets', 'configure', 'install', 'maintain')) {
        $rows = @($script:MenuTasks | Where-Object { $_.Group -eq $group })
        if ($rows.Count -eq 0) { continue }

        Write-Host ""
        Write-Host "  $(Get-MenuGroupTitle $group)"

        foreach ($task in $rows) {
            $n++
            $script:MenuDisplay += $task.Id

            $prefix = '    '
            if ($Numbered) { $prefix = '    {0,2} ' -f $n }
            Write-Host $prefix -NoNewline

            if (Test-MenuSelected $task.Id) {
                Write-Host '[x] ' -ForegroundColor Green -NoNewline
            } else {
                Write-Host '[ ] ' -NoNewline
            }

            Write-Host $task.Label.PadRight($width) -NoNewline

            switch ($task.State) {
                'done'    { Write-Host '  ✓ ' -ForegroundColor Green  -NoNewline }
                'todo'    { Write-Host '  · ' -ForegroundColor Yellow -NoNewline }
                'unknown' { Write-Host '  ? ' -ForegroundColor Yellow -NoNewline }
                default   { Write-Host '    ' -NoNewline }
            }
            Write-Host $task.Detail -ForegroundColor Blue
        }
    }
    Write-Host ""
}

# ─── Pickers ──────────────────────────────────────────────────────────────────

function Test-MenuGum {
    if ([Console]::IsInputRedirected) { return $false }
    return [bool](Get-Command gum -ErrorAction SilentlyContinue)
}

# gum choose gives arrow keys, space to toggle and / to filter from a single
# prebuilt binary, on all three platforms. We deliberately do not hand-roll a
# raw-mode equivalent: maintaining a PowerShell ReadKey TUI *and* a bash
# escape-sequence one is the duplication this rewrite exists to remove.
function Invoke-MenuGumPicker {
    $labels = @($script:MenuTasks | ForEach-Object { $_.Label })
    $selected = @($script:MenuTasks |
        Where-Object { Test-MenuSelected $_.Id } |
        ForEach-Object { $_.Label }) -join ','

    $argv = @('--no-limit', '--header', 'space toggles · / filters · enter confirms · esc quits')
    if ($selected) { $argv += @('--selected', $selected) }

    # Options are passed as arguments rather than piped in, so gum is not left
    # taking options from stdin and keystrokes from the console at once.
    $chosen = & gum choose @argv @labels
    if ($LASTEXITCODE -ne 0) { return $false }

    Clear-MenuSelection
    foreach ($label in @($chosen)) {
        if (-not $label) { continue }
        $task = $script:MenuTasks | Where-Object { $_.Label -eq $label } | Select-Object -First 1
        if ($task) { Select-MenuTask $task.Id }
    }
    return $true
}

# No gum, or no console: the same table with numbers, toggled by typing them.
# Accepts "1 3 5", ranges like "2-4", and the a/n shortcuts.
function Invoke-MenuFallbackPicker {
    while ($true) {
        Clear-Host
        Show-MenuHeader
        Show-MenuList -Numbered
        Write-Host "  type numbers to toggle (e.g. 1 3 5, 2-4) · a all · n none · enter runs · q quit" -ForegroundColor Blue
        Write-Host ""

        $reply = Read-MenuLine '  > '
        if ($null -eq $reply) { return $false }

        switch (Update-MenuSelectionFromInput $reply) {
            'run'  { return $true }
            'quit' { return $false }
        }
    }
}

# Split out of the picker so it can be tested without a console. Applies one
# line of input to the selection and says what the picker should do next:
# 'run', 'quit', or 'continue' to redraw and prompt again.
function Update-MenuSelectionFromInput {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$InputLine)

    switch ($InputLine.Trim()) {
        ''  { return 'run' }
        'q' { return 'quit' }
        'Q' { return 'quit' }
        'a' { Select-MenuAll;      return 'continue' }
        'A' { Select-MenuAll;      return 'continue' }
        'n' { Clear-MenuSelection; return 'continue' }
        'N' { Clear-MenuSelection; return 'continue' }
    }

    foreach ($token in ($InputLine -split '\s+' | Where-Object { $_ })) {
        if ($token -match '^(\d+)-(\d+)$') {
            foreach ($i in [int]$Matches[1]..[int]$Matches[2]) {
                if ($i -ge 1 -and $i -le $script:MenuDisplay.Count) {
                    Switch-MenuTask $script:MenuDisplay[$i - 1]
                }
            }
        } elseif ($token -match '^\d+$') {
            $i = [int]$token
            if ($i -ge 1 -and $i -le $script:MenuDisplay.Count) {
                Switch-MenuTask $script:MenuDisplay[$i - 1]
            } else {
                Write-Warn "No task numbered $i"
            }
        } else {
            Write-Warn "Ignoring '$token'"
        }
    }
    return 'continue'
}

function Invoke-MenuPicker {
    if (Test-MenuGum) {
        Clear-Host
        Show-MenuHeader
        Show-MenuList
        return (Invoke-MenuGumPicker)
    }
    return (Invoke-MenuFallbackPicker)
}

# ─── Input ────────────────────────────────────────────────────────────────────

# Every prompt goes through this. A closed stdin (piped input that ran out, a
# console that went away) must end the menu, not spin it: Read-Host returns
# empty rather than failing at EOF, so the main loop would otherwise re-prompt
# forever against input that can never arrive.
function Read-MenuLine {
    param([string]$Prompt = '')

    if ($Prompt) { Write-Host $Prompt -NoNewline -ForegroundColor Blue }

    if ([Console]::IsInputRedirected) {
        $line = [Console]::In.ReadLine()
        if ($null -ne $line) { Write-Host $line }
        return $line
    }
    return (Read-Host)
}

function Wait-MenuEnter {
    param([string]$Message = 'Press Enter to continue...')
    return ($null -ne (Read-MenuLine "  $Message"))
}

# ─── Preflight ────────────────────────────────────────────────────────────────
#
# Every requirement of the whole batch is checked once, up front. Discovering
# that the shell is not elevated five minutes into a run of base + desktop is
# the failure mode this exists to prevent.

function Test-MenuPreflight {
    param([Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Ids)

    $tasks = @(Get-MenuRunOrder | Where-Object { $Ids -contains $_.Id })
    $flags = @($tasks | ForEach-Object { $_.Flags } | Select-Object -Unique)
    $ok = $true

    if ($flags -contains 'admin') {
        Write-Step "Checking for an elevated shell..."
        if (Test-Admin) {
            Write-Ok "running elevated"
        } else {
            Write-Warn "The selected tasks need an elevated shell (Run as Administrator)."
            Write-Warn "Nothing was run. Re-select without them, or restart elevated."
            $ok = $false
        }
    }

    if ($flags -contains 'winget') {
        Write-Step "Checking winget..."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Ok "winget present"
        } else {
            Write-Warn "winget not found; the install tasks cannot run. See windows/README.md."
            $ok = $false
        }
    }

    # Advisory rather than blocking: a proxy or captive portal can fail this
    # probe on a machine where the actual downloads would have worked, and a
    # false refusal is worse than a slow failure.
    # Skipped when something already refused the run: an eight-second probe and
    # a "continue anyway?" prompt are noise when the answer is already no.
    if ($flags -contains 'net' -and $ok) {
        Write-Step "Checking network..."
        $reachable = $false
        try {
            [Net.ServicePointManager]::SecurityProtocol =
                [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri 'https://github.com' -UseBasicParsing -TimeoutSec 8 -Method Head | Out-Null
            $reachable = $true
        } catch { }

        if ($reachable) {
            Write-Ok "github.com reachable"
        } else {
            Write-Warn "Could not reach github.com - downloads may fail"
            $reply = Read-MenuLine '  Continue anyway? (y/N) '
            if ($reply -notmatch '^(y|yes)$') { return $false }
        }
    }

    return $ok
}

# ─── Runner ───────────────────────────────────────────────────────────────────

function Confirm-MenuPlan {
    param([Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Ids)

    Write-Host ""
    Write-Host "  Will run, in order:"
    $n = 0
    foreach ($task in (Get-MenuRunOrder | Where-Object { $Ids -contains $_.Id })) {
        $n++
        Write-Host ("    {0}. {1}" -f $n, $task.Label)
    }
    Write-Host ""

    $reply = Read-MenuLine '  Proceed? (y/N) '
    if ($null -eq $reply) { return $false }
    if ($reply -match '^(y|yes)$') { return $true }

    Write-Info "Nothing run."
    return $false
}

# One failing task does not abort the rest: the installers are long, and a
# missing package in `desktop` should not cost you the `links` you also asked
# for. Results are tallied and reported at the end instead.
function Invoke-MenuRun {
    param([Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Ids)

    $results = @()

    foreach ($task in (Get-MenuRunOrder | Where-Object { $Ids -contains $_.Id })) {
        if (-not $task.Handler) { continue }

        Write-Host ""
        Write-Host "━━━ $($task.Label) ━━━" -ForegroundColor Cyan
        Write-Host ""

        $failed = $false
        try {
            & $task.Handler
        } catch {
            Write-Fail $_.Exception.Message
            $failed = $true
        }
        $results += [pscustomobject]@{ Label = $task.Label; Failed = $failed }
    }

    Write-Host ""
    Write-Host "━━━ Summary ━━━" -ForegroundColor Cyan
    $failures = 0
    foreach ($r in $results) {
        if ($r.Failed) {
            Write-Fail $r.Label
            $failures++
        } else {
            Write-Ok $r.Label
        }
    }
    if ($failures -gt 0) { Write-Warn "$failures task(s) failed" }
    Write-Host ""
}

# ─── Main loop ────────────────────────────────────────────────────────────────

# Guards against a typo'd id in a preset's Expand list, and against two tasks
# sharing an id or a run-order slot.
function Test-MenuTable {
    $problems = 0

    $dupeIds = @($script:MenuTasks | Group-Object Id | Where-Object { $_.Count -gt 1 })
    foreach ($d in $dupeIds) { Write-Warn "duplicate task id: $($d.Name)"; $problems++ }

    $dupeOrders = @($script:MenuTasks | Group-Object Order | Where-Object { $_.Count -gt 1 })
    foreach ($d in $dupeOrders) { Write-Warn "duplicate order: $($d.Name)"; $problems++ }

    foreach ($task in $script:MenuTasks) {
        if ($task.Group -ne 'presets' -and -not $task.Handler) {
            Write-Warn "$($task.Id) has no handler"; $problems++
        }
        foreach ($id in $task.Expand) {
            if (-not (Get-MenuTask $id)) {
                Write-Warn "$($task.Id) expands to an unknown id: $id"; $problems++
            }
        }
    }

    return ($problems -eq 0)
}

function Invoke-Menu {
    if (-not (Test-MenuTable)) {
        Invoke-Die "Task table is inconsistent (see above)"
    }

    while ($true) {
        Update-MenuStatus
        if ($script:MenuSelected.Count -eq 0) { Select-MenuDefaults }

        if (-not (Invoke-MenuPicker)) { break }

        Expand-MenuSelection
        $ids = @($script:MenuSelected)

        if ($ids.Count -eq 0) {
            Write-Info "Nothing selected."
            Write-Host ""
            if (-not (Wait-MenuEnter)) { break }
            continue
        }

        if ((Confirm-MenuPlan -Ids $ids) -and (Test-MenuPreflight -Ids $ids)) {
            Invoke-MenuRun -Ids $ids
            # A run changes what the probes would report, so drop anything they
            # cached (the winget listing) before the next redraw.
            if (Get-Command Reset-MenuProbeCache -ErrorAction SilentlyContinue) {
                Reset-MenuProbeCache
            }
        }

        Clear-MenuSelection
        if (-not (Wait-MenuEnter 'Press Enter to return to the menu...')) { break }
    }

    Write-Host ""
    Write-Host "Goodbye!" -ForegroundColor Cyan
    Write-Host ""
}
