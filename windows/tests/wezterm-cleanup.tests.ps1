# Tests for Remove-LegacyWeztermLink in windows\setup.ps1.
#
# wezterm was dropped from this repo, and that function cleans up the
# ~\.wezterm.lua left behind on a machine set up before the change. Getting it
# wrong is quiet in both directions: it either leaves a stale config in place
# or deletes one you wrote yourself, and neither shows up until much later.
#
# The function and its hash table are lifted out of setup.ps1 through the
# parser rather than copied here, so this exercises the shipped source and
# cannot drift from it. $HOME is redirected at a sandbox for the duration.
#
# No Pester: it is not a dependency of this repo, and the version bundled with
# Windows PowerShell 5.1 is too old to be worth targeting. Plain PASS/FAIL with
# an exit code is enough.
#
#   pwsh       -NoProfile -File windows\tests\wezterm-cleanup.tests.ps1
#   powershell -NoProfile -File windows\tests\wezterm-cleanup.tests.ps1
#
# Exits 0 when everything passed, 1 on any failure. Skips are not failures:
# the symlink cases need Developer Mode or an elevated shell, and the
# historical-content cases need the git history to be present.

$ErrorActionPreference = 'Stop'

$TESTS_DIR = $PSScriptRoot
$REPO_ROOT = Split-Path (Split-Path $TESTS_DIR -Parent) -Parent

. "$REPO_ROOT\windows\common.ps1"

# ─── Load the code under test ─────────────────────────────────────────────────

$setup = "$REPO_ROOT\windows\setup.ps1"
$ast = [System.Management.Automation.Language.Parser]::ParseFile($setup, [ref]$null, [ref]$null)

$fnAst = $ast.FindAll({ param($n)
    $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $n.Name -eq 'Remove-LegacyWeztermLink' }, $true) | Select-Object -First 1
if (-not $fnAst) { throw "Remove-LegacyWeztermLink not found in $setup" }

$hashAst = $ast.FindAll({ param($n)
    $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $n.Left.Extent.Text -eq '$WEZTERM_CONFIG_HASHES' }, $true) | Select-Object -First 1
if (-not $hashAst) { throw "WEZTERM_CONFIG_HASHES not found in $setup" }

. ([scriptblock]::Create($hashAst.Extent.Text))
. ([scriptblock]::Create($fnAst.Extent.Text))

# Defined after common.ps1 so it shadows the real one: the function under test
# reports a removal through Write-Ok, and that is what we assert on.
$script:removedMsg = $null
function Write-Ok { param($m) $script:removedMsg = $m }

# ─── Harness ──────────────────────────────────────────────────────────────────

$sandbox   = Join-Path ([System.IO.Path]::GetTempPath()) 'dotfiles-wezterm-cleanup-test'
$repoDir   = Join-Path $sandbox 'dotfiles\windows\wezterm'
$fakeHome  = Join-Path $sandbox 'home'
$elsewhere = Join-Path $sandbox 'elsewhere'
$link      = Join-Path $fakeHome '.wezterm.lua'
$target    = Join-Path $repoDir '.wezterm.lua'

$results = @()

function Add-Result($result, $name, $detail) {
    $script:results += [pscustomobject]@{ Result = $result; Case = $name; Detail = $detail }
}
function Check($name, $ok, $detail) {
    Add-Result $(if ($ok) { 'PASS' } else { 'FAIL' }) $name $detail
}
function Skip($name, $why) { Add-Result 'SKIP' $name $why }

function Reset-Sandbox {
    if (Test-Path $sandbox) { Remove-Item $sandbox -Recurse -Force }
    New-Item -ItemType Directory -Force $repoDir, $fakeHome, $elsewhere | Out-Null
    $script:removedMsg = $null
}

# Test-Path is no good here: a symlink whose target is gone reports $false,
# and that is the state several of these cases end in.
function Test-Gone { $null -eq (Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue) }

function Write-Raw($path, $text) {
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

# ─── Capability probes ────────────────────────────────────────────────────────

# Ask by trying, rather than trusting Test-CanSymlink: this only needs to know
# whether a link can actually be made here.
function Test-SymlinkWorks {
    $probeDir = Join-Path ([System.IO.Path]::GetTempPath()) "symlink-probe-$PID"
    try {
        New-Item -ItemType Directory -Force $probeDir | Out-Null
        New-Item -ItemType SymbolicLink -Path (Join-Path $probeDir 'l') `
                 -Target (Join-Path $probeDir 'no-such-file') -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    } finally {
        if (Test-Path $probeDir) { Remove-Item $probeDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

$canSymlink = Test-SymlinkWorks

# Every .wezterm.lua this repo ever shipped, by blob. Read back out of git so
# the fixtures are the real files rather than a transcription.
$blobs = [ordered]@{
    '9df876b initial' = 'b31a70feebb83a40ceab27d9bfe83c7de3a4544e'
    'ed07861 parity'  = '84b380e5542e993494c389084dab9d0612a256b1'
    'dd34575 fira16'  = 'c4aef2b7cde8c93930e6105f63582a08109c98f2'
    'ecfa486 size15'  = 'c689c98e95b1e33934e108d334ed01a7a3d65cb7'
}

$content = [ordered]@{}
$hasGit = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
if ($hasGit) {
    foreach ($name in $blobs.Keys) {
        & git -C $REPO_ROOT cat-file -e "$($blobs[$name])" 2>$null
        if ($LASTEXITCODE -ne 0) { continue }   # shallow clone, or history rewritten
        $content[$name] = (& git -C $REPO_ROOT cat-file blob $blobs[$name] | Out-String) -replace "`r`n", "`n"
    }
}

Write-Host "Loaded $($WEZTERM_CONFIG_HASHES.Count) known config hashes, $($content.Count)/$($blobs.Count) historical files"
Write-Host "Symlink cases: $(if ($canSymlink) { 'enabled' } else { 'SKIPPED (needs Developer Mode or an elevated shell)' })"
Write-Host ""

# HOME is read-only rather than constant, so -Force can point it at the sandbox.
$realHome = $HOME

try {
    Set-Variable HOME -Value $fakeHome -Force -Scope Global

    # ─── The hash table itself ────────────────────────────────────────────────
    #
    # Guards the fixtures and the shipped table against each other: if someone
    # adds a config version without adding its hash, or mistypes one, every
    # removal case below would still pass while the real cleanup quietly missed
    # that version.
    foreach ($name in $blobs.Keys) {
        if (-not $content.Contains($name)) { Skip "hash table covers $name" 'blob not in this clone'; continue }
        Reset-Sandbox
        Write-Raw $link $content[$name]
        $hash = Get-NormalisedFileHash $link
        Check "hash table covers $name" ($hash -in $WEZTERM_CONFIG_HASHES) $hash
    }

    # ─── Nothing to do ────────────────────────────────────────────────────────

    Reset-Sandbox
    Remove-LegacyWeztermLink
    Check 'no file present' ((Test-Gone) -and -not $removedMsg) 'no-op'

    # ─── Symlinks ─────────────────────────────────────────────────────────────

    if (-not $canSymlink) {
        Skip 'symlink into repo, target deleted' 'cannot create symlinks here'
        Skip 'symlink into repo, target present' 'cannot create symlinks here'
        Skip 'symlink outside repo'              'cannot create symlinks here'
    } else {
        # The case the function was written for: the repo file is gone, so the
        # link dangles and only its stored target identifies it.
        Reset-Sandbox
        Write-Raw $target '-- content is irrelevant, the target path identifies it'
        New-Item -ItemType SymbolicLink -Path $link -Target $target | Out-Null
        Remove-Item $target -Force
        Remove-LegacyWeztermLink
        Check 'symlink into repo, target deleted' ((Test-Gone) -and $removedMsg) 'removed'

        # Same link before the repo file is deleted, e.g. re-running setup on a
        # checkout that predates the removal.
        Reset-Sandbox
        Write-Raw $target '-- still present'
        New-Item -ItemType SymbolicLink -Path $link -Target $target | Out-Null
        Remove-LegacyWeztermLink
        Check 'symlink into repo, target present' ((Test-Gone) -and $removedMsg) 'removed'

        # Your own config, linked in from somewhere else. Must survive.
        Reset-Sandbox
        $mine = Join-Path $elsewhere 'my.wezterm.lua'
        Write-Raw $mine "-- entirely my own`n"
        New-Item -ItemType SymbolicLink -Path $link -Target $mine | Out-Null
        Remove-LegacyWeztermLink
        Check 'symlink outside repo' ((-not (Test-Gone)) -and -not $removedMsg) 'kept'
    }

    # ─── Hard link, repo file deleted ─────────────────────────────────────────
    #
    # The regression this suite exists for. New-DotfileLink falls back to a hard
    # link when it cannot symlink, and once the repo file is deleted the link
    # reports an empty LinkType and Target - indistinguishable from a plain file,
    # so the target-path check alone never fired. Hard links need no privilege,
    # so this runs everywhere.
    if (-not $content.Contains('ecfa486 size15')) {
        Skip 'hardlink into repo, repo file deleted' 'blob not in this clone'
    } else {
        Reset-Sandbox
        Write-Raw $target $content['ecfa486 size15']
        New-Item -ItemType HardLink -Path $link -Target $target | Out-Null
        Remove-Item $target -Force
        $item = Get-Item -LiteralPath $link -Force
        Remove-LegacyWeztermLink
        Check 'hardlink into repo, repo file deleted' (Test-Gone) `
              "LinkType=[$($item.LinkType)] Target=[$(@($item.Target) -join ',')]"
    }

    # ─── Plain copies ─────────────────────────────────────────────────────────
    #
    # The other New-DotfileLink fallback, and the one that never had a link to
    # follow. Both line endings, because core.autocrlf gives the working copy
    # CRLF while git stores LF.
    foreach ($name in $content.Keys) {
        Reset-Sandbox
        Write-Raw $link $content[$name]
        Remove-LegacyWeztermLink
        Check "copy of $name (LF)" ((Test-Gone) -and $removedMsg) 'removed'

        Reset-Sandbox
        Write-Raw $link ($content[$name] -replace "`n", "`r`n")
        Remove-LegacyWeztermLink
        Check "copy of $name (CRLF)" ((Test-Gone) -and $removedMsg) 'removed'
    }

    # ─── Things that must survive ─────────────────────────────────────────────

    Reset-Sandbox
    Write-Raw $link "-- my own config, nothing to do with this repo`n"
    Remove-LegacyWeztermLink
    Check 'hand-written regular file' ((-not (Test-Gone)) -and -not $removedMsg) 'kept'

    if (-not $content.Contains('ecfa486 size15')) {
        Skip 'shipped config, then edited' 'blob not in this clone'
    } else {
        # Started as ours, but you changed it - so it no longer hashes, and it
        # is now yours to keep.
        Reset-Sandbox
        Write-Raw $link ($content['ecfa486 size15'] + "`n-- my tweak`n")
        Remove-LegacyWeztermLink
        Check 'shipped config, then edited' ((-not (Test-Gone)) -and -not $removedMsg) 'kept'
    }

    # A directory at that path is not something this should ever delete.
    Reset-Sandbox
    New-Item -ItemType Directory -Path $link | Out-Null
    Remove-LegacyWeztermLink
    Check 'directory at path' ((-not (Test-Gone)) -and -not $removedMsg) 'kept'

} finally {
    Set-Variable HOME -Value $realHome -Force -Scope Global
    if (Test-Path $sandbox) { Remove-Item $sandbox -Recurse -Force -ErrorAction SilentlyContinue }
}

# ─── Report ───────────────────────────────────────────────────────────────────

$results | Format-Table -AutoSize | Out-String | Write-Host

$failed  = @($results | Where-Object Result -eq 'FAIL').Count
$skipped = @($results | Where-Object Result -eq 'SKIP').Count
$passed  = @($results | Where-Object Result -eq 'PASS').Count

if ($failed -gt 0) {
    Write-Host "FAILED: $failed failed, $passed passed, $skipped skipped" -ForegroundColor Red
    exit 1
}
Write-Host "OK: $passed passed, $skipped skipped" -ForegroundColor Green
exit 0
