# Tests for the setup menu's self-update in windows\setup.ps1 (Invoke-SelfUpdate
# and Invoke-QuietFetch): fetch on start, fast-forward, restart on the new code,
# and leave the checkout alone whenever that is not safe. The counterpart to
# tests/self-update.sh.
#
# The functions are lifted out of setup.ps1 through the parser, as in
# wezterm-cleanup.tests.ps1, and run against a throwaway origin and checkout in
# the temp directory. Restart-DotfilesSetup is replaced with a stub that records
# the call instead of starting a process. Needs git on PATH.
#
#   pwsh       -NoProfile -File windows\tests\self-update.tests.ps1
#   powershell -NoProfile -File windows\tests\self-update.tests.ps1
#
# Exits 0 when everything passed, 1 on any failure.

$TESTS_DIR = $PSScriptRoot
$REPO_ROOT_REAL = Split-Path (Split-Path $TESTS_DIR -Parent) -Parent

. "$REPO_ROOT_REAL/windows/common.ps1"

# ─── Load the code under test ─────────────────────────────────────────────────

$setup = Join-Path $REPO_ROOT_REAL 'windows/setup.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($setup, [ref]$null, [ref]$null)
foreach ($name in 'Invoke-SelfUpdate', 'Invoke-QuietFetch') {
    $fnAst = $ast.FindAll({ param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $n.Name -eq $name }, $true) | Select-Object -First 1
    if (-not $fnAst) { throw "$name not found in $setup" }
    . ([scriptblock]::Create($fnAst.Extent.Text))
}

# The real one starts a new process and exits; record the call and unwind
# instead, the way the exit would.
function Restart-DotfilesSetup {
    param([string]$From)
    $script:restartedFrom = $From
    throw 'RESTARTED'
}

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

$env:GIT_AUTHOR_NAME = 'test';    $env:GIT_AUTHOR_EMAIL = 'test@example.com'
$env:GIT_COMMITTER_NAME = 'test'; $env:GIT_COMMITTER_EMAIL = 'test@example.com'

$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) 'dotfiles-self-update-test'

function Invoke-Git { git -c init.defaultBranch=main -c advice.detachedHead=false @args 2>&1 | Out-Null }

# A fresh origin with one commit, a checkout of it, and a second commit pushed
# from elsewhere, so the checkout is one behind once it fetches. $REPO_ROOT is
# what the functions under test read.
function New-Repos {
    if (Test-Path $sandbox) { Remove-Item $sandbox -Recurse -Force }
    New-Item -ItemType Directory -Path $sandbox | Out-Null
    $script:origin = Join-Path $sandbox 'origin.git'
    $script:REPO_ROOT = Join-Path $sandbox 'checkout'
    $other = Join-Path $sandbox 'other'

    Invoke-Git init -q --bare $origin
    Invoke-Git clone -q $origin $REPO_ROOT
    Set-Content -Path (Join-Path $REPO_ROOT 'file') -Value 'one'
    Invoke-Git -C $REPO_ROOT add file
    Invoke-Git -C $REPO_ROOT commit -qm one
    Invoke-Git -C $REPO_ROOT push -q origin main
    Invoke-Git clone -q $origin $other
    Set-Content -Path (Join-Path $other 'file') -Value 'two'
    Invoke-Git -C $other commit -qam two
    Invoke-Git -C $other push -q origin main

    $script:start = git -C $REPO_ROOT rev-parse HEAD
    $script:latest = git -C $other rev-parse HEAD
    $script:restartedFrom = $null
    $script:MenuNotice = ''
}

function Get-Head { git -C $REPO_ROOT rev-parse HEAD }

# Run it the way setup.ps1 does; a restart surfaces as the stub's throw.
function Invoke-Update {
    param([switch]$Skip)
    try { Invoke-SelfUpdate -Skip:$Skip } catch { if ($_.Exception.Message -ne 'RESTARTED') { throw } }
}

# ─── Cases ────────────────────────────────────────────────────────────────────

Test-Case 'behind: fast-forwards and restarts from where it started' {
    New-Repos
    Invoke-Update
    Assert-True ($script:restartedFrom -eq $start) "restartedFrom [$script:restartedFrom], want [$start]"
    Assert-True ((Get-Head) -eq $latest) "HEAD $(Get-Head), want $latest"
}

Test-Case 'after restart: does not update again, reports what arrived' {
    Invoke-Git -C $REPO_ROOT remote set-url origin (Join-Path $sandbox 'missing.git')
    $script:restartedFrom = $null
    $env:DOTFILES_UPDATED = $start
    Invoke-Update
    Assert-True ($null -eq $script:restartedFrom) 'restarted again'
    Assert-True (-not $env:DOTFILES_UPDATED) 'DOTFILES_UPDATED was left set'
    $want = "updated from $($start.Substring(0, 7)) · 1 new commit(s)"
    Assert-True ($script:MenuNotice -eq $want) "notice [$script:MenuNotice], want [$want]"
}

Test-Case 'up to date: no restart, no notice' {
    New-Repos
    Invoke-Git -C $REPO_ROOT pull -q --ff-only origin main
    Invoke-Update
    Assert-True ($null -eq $script:restartedFrom) 'restarted'
    Assert-True (-not $script:MenuNotice) "notice [$script:MenuNotice]"
}

Test-Case 'dirty file in the way: no restart, edit and HEAD untouched' {
    New-Repos
    Set-Content -Path (Join-Path $REPO_ROOT 'file') -Value 'mine'
    Invoke-Update
    Assert-True ($null -eq $script:restartedFrom) 'restarted'
    Assert-True ($script:MenuNotice -like '1 update(s) not applied*') "notice [$script:MenuNotice]"
    Assert-True ((Get-Head) -eq $start) 'HEAD moved'
    Assert-True ((Get-Content (Join-Path $REPO_ROOT 'file')) -eq 'mine') 'the edit was lost'
}

Test-Case 'diverged: no restart, local commit kept' {
    New-Repos
    Set-Content -Path (Join-Path $REPO_ROOT 'extra') -Value 'extra'
    Invoke-Git -C $REPO_ROOT add extra
    Invoke-Git -C $REPO_ROOT commit -qm local
    $mine = Get-Head
    Invoke-Update
    Assert-True ($null -eq $script:restartedFrom) 'restarted'
    Assert-True ((Get-Head) -eq $mine) 'local commit lost'
}

Test-Case 'unreachable origin: runs the local version' {
    New-Repos
    Invoke-Git -C $REPO_ROOT remote set-url origin (Join-Path $sandbox 'missing.git')
    Invoke-Update
    Assert-True ($script:MenuNotice -like 'could not reach origin*') "notice [$script:MenuNotice]"
}

Test-Case '-NoUpdate: skips the check' {
    New-Repos
    Invoke-Update -Skip
    Assert-True ($null -eq $script:restartedFrom -and (Get-Head) -eq $start) 'updated anyway'
}

Test-Case 'DOTFILES_NO_UPDATE: skips the check' {
    New-Repos
    $env:DOTFILES_NO_UPDATE = '1'
    try { Invoke-Update } finally { Remove-Item Env:DOTFILES_NO_UPDATE }
    Assert-True ($null -eq $script:restartedFrom -and (Get-Head) -eq $start) 'updated anyway'
}

Test-Case 'branch not on origin: says so, no restart' {
    New-Repos
    Invoke-Git -C $REPO_ROOT switch -q -c local-only
    Invoke-Update
    Assert-True ($script:MenuNotice -like 'no origin/local-only*') "notice [$script:MenuNotice]"
}

Test-Case 'detached HEAD: skips the check' {
    New-Repos
    Invoke-Git -C $REPO_ROOT switch -q --detach
    Invoke-Update
    Assert-True ($script:MenuNotice -like 'detached HEAD*') "notice [$script:MenuNotice]"
}

if (Test-Path $sandbox) { Remove-Item $sandbox -Recurse -Force }

Write-Host ""
Write-Host "$script:passed passed, $script:failed failed"
if ($script:failed -gt 0) { exit 1 }
exit 0
