# Tests for the setup-menu engine in windows\menu.ps1, and for the task table
# that windows\setup.ps1 registers with it.
#
# The table is what the whole menu is derived from -- the listing, the run
# order, the preflight checks -- so a duplicated id, a preset pointing at a
# task that no longer exists, or a row whose handler was never written are all
# silent until someone picks that row on a real machine. The table is lifted
# out of setup.ps1 through the parser rather than copied here, so this
# exercises the shipped source and cannot drift from it.
#
# No Pester: it is not a dependency of this repo, and the version bundled with
# Windows PowerShell 5.1 is too old to be worth targeting. Plain PASS/FAIL with
# an exit code is enough, matching wezterm-cleanup.tests.ps1.
#
#   pwsh       -NoProfile -File windows\tests\menu.tests.ps1
#   powershell -NoProfile -File windows\tests\menu.tests.ps1
#
# Exits 0 when everything passed, 1 on any failure.

$ErrorActionPreference = 'Stop'

$TESTS_DIR = $PSScriptRoot
$REPO_ROOT = Split-Path (Split-Path $TESTS_DIR -Parent) -Parent

. "$REPO_ROOT/windows/common.ps1"
. "$REPO_ROOT/windows/menu.ps1"

# ─── Harness ──────────────────────────────────────────────────────────────────

$script:passed = 0
$script:failed = 0

function Test-Case {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        $script:passed++
        Write-Host "PASS  $Name" -ForegroundColor Green
    } catch {
        $script:failed++
        Write-Host "FAIL  $Name" -ForegroundColor Red
        Write-Host "        $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message = '')
    $e = ($Expected -join ',')
    $a = ($Actual -join ',')
    if ($e -ne $a) { throw "$Message expected [$e], got [$a]" }
}

# Silence the engine's warnings while exercising the failure paths.
function Write-Warn { param($Text) }

function Reset-Table {
    $script:MenuTasks = @()
    Clear-MenuSelection
}

# A small table standing in for a real one.
function Add-SampleTable {
    Reset-Table
    Add-MenuTask -Id 'pre'  -Label 'Preset'  -Group presets   -Order 1  -Expand @('links', 'base')
    Add-MenuTask -Id 'links' -Label 'Links'  -Group configure -Order 10 -Handler { 'links' } -Probe { New-MenuStatus -State todo -Detail 'no' }
    Add-MenuTask -Id 'base' -Label 'Base'    -Group install   -Order 30 -Handler { 'base' }  -Probe { New-MenuStatus -State todo -Detail 'no' } -Flags @('net', 'winget')
    Add-MenuTask -Id 'done' -Label 'Done'    -Group install   -Order 40 -Handler { 'done' }  -Probe { New-MenuStatus -State done -Detail 'yes' }
    Add-MenuTask -Id 'upd'  -Label 'Update'  -Group maintain  -Order 70 -Handler { 'upd' }   -Probe { New-MenuStatus -State todo -Detail 'behind' }
}

# ─── Engine ───────────────────────────────────────────────────────────────────

Test-Case 'run order follows Order, not registration order' {
    Reset-Table
    Add-MenuTask -Id 'c' -Label 'C' -Group install   -Order 30 -Handler { }
    Add-MenuTask -Id 'a' -Label 'A' -Group configure -Order 10 -Handler { }
    Add-MenuTask -Id 'b' -Label 'B' -Group install   -Order 20 -Handler { }
    Assert-Equal @('a', 'b', 'c') (Get-MenuRunOrder | ForEach-Object { $_.Id })
}

Test-Case 'selecting toggles, and a repeat selection does not duplicate' {
    Add-SampleTable
    Select-MenuTask 'links'
    Select-MenuTask 'links'
    Assert-Equal @('links') $script:MenuSelected
    Switch-MenuTask 'links'
    Assert-Equal @() $script:MenuSelected
}

Test-Case 'a preset expands into its tasks and removes itself' {
    Add-SampleTable
    Select-MenuTask 'pre'
    Expand-MenuSelection
    Assert-True (-not (Test-MenuSelected 'pre')) 'preset should not survive expansion'
    Assert-True (Test-MenuSelected 'links') 'links should be selected'
    Assert-True (Test-MenuSelected 'base') 'base should be selected'
}

Test-Case 'expanding a preset does not deselect what was already ticked' {
    Add-SampleTable
    Select-MenuTask 'upd'
    Select-MenuTask 'pre'
    Expand-MenuSelection
    Assert-True (Test-MenuSelected 'upd') 'upd should survive expansion'
}

Test-Case 'defaults preselect only outstanding configure/install tasks' {
    Add-SampleTable
    Update-MenuStatus
    Select-MenuDefaults
    # 'done' is already installed and 'upd' is a maintain task, so neither.
    Assert-Equal @('links', 'base') $script:MenuSelected
}

Test-Case 'select all skips presets' {
    Add-SampleTable
    Select-MenuAll
    Assert-True (-not (Test-MenuSelected 'pre')) 'presets are not tasks'
    Assert-Equal @('links', 'base', 'done', 'upd') $script:MenuSelected
}

Test-Case 'a probe that throws renders as unknown rather than taking the menu down' {
    Reset-Table
    Add-MenuTask -Id 'x' -Label 'X' -Group install -Order 10 -Handler { } -Probe { throw 'boom' }
    Update-MenuStatus
    Assert-Equal 'unknown' (Get-MenuTask 'x').State
}

# ─── Input parsing ────────────────────────────────────────────────────────────

# The display numbers are assigned by the renderer, so the list has to be drawn
# before input can be applied to it. 6>$null swallows its Write-Host output.
function Set-Display {
    Add-SampleTable
    Show-MenuList -Numbered 6>$null
}

Test-Case 'numbers toggle the rows they name' {
    Set-Display
    $null = Update-MenuSelectionFromInput '2 3'
    Assert-Equal @('links', 'base') $script:MenuSelected
}

Test-Case 'a range toggles every row in it' {
    Set-Display
    $null = Update-MenuSelectionFromInput '2-4'
    Assert-Equal @('links', 'base', 'done') $script:MenuSelected
}

Test-Case 'out-of-range and junk tokens are ignored, not fatal' {
    Set-Display
    $null = Update-MenuSelectionFromInput '99 wat 2'
    Assert-Equal @('links') $script:MenuSelected
}

Test-Case 'empty input runs, q quits, a/n select all and none' {
    Set-Display
    Assert-Equal 'run'  (Update-MenuSelectionFromInput '')
    Assert-Equal 'quit' (Update-MenuSelectionFromInput 'q')
    $null = Update-MenuSelectionFromInput 'a'
    Assert-True ($script:MenuSelected.Count -eq 4) 'a should select every task'
    $null = Update-MenuSelectionFromInput 'n'
    Assert-True ($script:MenuSelected.Count -eq 0) 'n should clear the selection'
}

# ─── Table validation ─────────────────────────────────────────────────────────

Test-Case 'Test-MenuTable rejects a duplicate id' {
    Reset-Table
    Add-MenuTask -Id 'x' -Label 'X' -Group install -Order 10 -Handler { }
    Add-MenuTask -Id 'x' -Label 'Y' -Group install -Order 20 -Handler { }
    Assert-True (-not (Test-MenuTable)) 'duplicate id should fail validation'
}

Test-Case 'Test-MenuTable rejects a duplicate run order' {
    Reset-Table
    Add-MenuTask -Id 'x' -Label 'X' -Group install -Order 10 -Handler { }
    Add-MenuTask -Id 'y' -Label 'Y' -Group install -Order 10 -Handler { }
    Assert-True (-not (Test-MenuTable)) 'duplicate order should fail validation'
}

Test-Case 'Test-MenuTable rejects a preset pointing at an unknown id' {
    Reset-Table
    Add-MenuTask -Id 'p' -Label 'P' -Group presets -Order 1 -Expand @('nope')
    Assert-True (-not (Test-MenuTable)) 'unknown expansion target should fail validation'
}

Test-Case 'Test-MenuTable rejects a task with no handler' {
    Reset-Table
    Add-MenuTask -Id 'x' -Label 'X' -Group install -Order 10
    Assert-True (-not (Test-MenuTable)) 'a task with no handler should fail validation'
}

# ─── The shipped table ────────────────────────────────────────────────────────

Test-Case 'the task table in setup.ps1 is consistent' {
    Reset-Table

    # Lifted out through the parser so this checks the shipped rows. The
    # handlers are scriptblocks and are never invoked here, so the functions
    # they call do not need to exist in this session.
    $setup = "$REPO_ROOT/windows/setup.ps1"
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($setup, [ref]$null, [ref]$null)
    $calls = $ast.FindAll({ param($n)
        $n -is [System.Management.Automation.Language.CommandAst] -and
        $n.GetCommandName() -eq 'Add-MenuTask' }, $true)

    Assert-True ($calls.Count -gt 0) 'no Add-MenuTask calls found in setup.ps1'
    foreach ($call in $calls) { . ([scriptblock]::Create($call.Extent.Text)) }

    Assert-True (Test-MenuTable) 'the shipped table failed validation'
}

Test-Case 'every preset in setup.ps1 expands to tasks that exist and can run' {
    foreach ($preset in ($script:MenuTasks | Where-Object { $_.Group -eq 'presets' })) {
        Assert-True ($preset.Expand.Count -gt 0) "$($preset.Id) expands to nothing"
        foreach ($id in $preset.Expand) {
            $target = Get-MenuTask $id
            Assert-True ($null -ne $target) "$($preset.Id) expands to unknown id '$id'"
            Assert-True ($null -ne $target.Handler) "$($preset.Id) expands to '$id', which has no handler"
        }
    }
}

Test-Case 'the SSH task is flagged as needing an elevated shell' {
    $server = Get-MenuTask 'server'
    Assert-True ($null -ne $server) 'no server task in the table'
    Assert-True ($server.Flags -contains 'admin') 'server tools install a service and need admin'
}

Test-Case 'every task that installs packages is flagged for winget and network' {
    foreach ($id in @('shell', 'base', 'desktop', 'server')) {
        $task = Get-MenuTask $id
        Assert-True ($task.Flags -contains 'winget') "$id should be flagged winget"
        Assert-True ($task.Flags -contains 'net') "$id should be flagged net"
    }
}

# ─── Result ───────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "$script:passed passed, $script:failed failed"
if ($script:failed -gt 0) { exit 1 }
exit 0
