# Tests for the toolchain pieces of the Windows setup: the winget manifest,
# checksum verification, the git include helpers, the generated zellij config,
# the init-script cache, and that every posh.d file loads cleanly.
#
# Same harness as menu.tests.ps1 -- plain PASS/FAIL and an exit code, no
# Pester. Functions that live in setup.ps1 are lifted out through the parser,
# since dot-sourcing setup.ps1 would start the menu.
#
#   pwsh       -NoProfile -File windows\tests\toolchain.tests.ps1
#   powershell -NoProfile -File windows\tests\toolchain.tests.ps1
#
# Exits 0 when everything passed, 1 on any failure.

$ErrorActionPreference = 'Stop'

$TESTS_DIR = $PSScriptRoot
$REPO_ROOT = Split-Path (Split-Path $TESTS_DIR -Parent) -Parent

. "$REPO_ROOT/windows/common.ps1"

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

# Keep the helpers' progress output out of the test log.
function Write-Ok   { param($Text) }
function Write-Info { param($Text) }
function Write-Warn { param($Text) }
function Write-Fail { param($Text) }

$TMP = Join-Path ([System.IO.Path]::GetTempPath()) "dotfiles-toolchain-tests-$([System.IO.Path]::GetRandomFileName())"
New-Item -ItemType Directory -Path $TMP -Force | Out-Null

# ─── packages.psd1 ────────────────────────────────────────────────────────────

$manifest = Import-PowerShellDataFile -Path (Join-Path $REPO_ROOT 'windows\packages.psd1')

Test-Case 'every package has an Id and a Name' {
    foreach ($pkg in $manifest.Packages) {
        Assert-True ([bool]$pkg.Id) "a package has no Id: $($pkg | Out-String)"
        Assert-True ([bool]$pkg.Name) "$($pkg.Id) has no Name"
    }
}

Test-Case 'package ids are unique' {
    $dupes = @($manifest.Packages | Group-Object { $_.Id } | Where-Object Count -gt 1 | ForEach-Object Name)
    Assert-Equal @() $dupes 'duplicated ids:'
}

Test-Case 'nothing mise now provides is still installed through winget' {
    $superseded = @($manifest.Superseded | ForEach-Object { $_.Id })
    $offenders = @($manifest.Packages | Where-Object { $superseded -contains $_.Id } | ForEach-Object { $_.Id })
    Assert-Equal @() $offenders 'superseded ids still in Packages:'
}

Test-Case 'mise is in the package list' {
    $ids = @($manifest.Packages | ForEach-Object { $_.Id })
    Assert-True ($ids -contains 'jdx.mise') 'jdx.mise is missing'
}

Test-Case 'VS Build Tools come before rustup (the msvc toolchain needs the linker)' {
    $ids = @($manifest.Packages | ForEach-Object { $_.Id })
    Assert-True ($ids.IndexOf('Microsoft.VisualStudio.2022.BuildTools') -lt $ids.IndexOf('Rustlang.Rustup')) 'wrong order'
}

# ─── Go tools (gup.json) ──────────────────────────────────────────────────────

Test-Case 'gup.json parses, and every entry has a unique name and an import path' {
    $gup = Get-Content -LiteralPath (Join-Path $REPO_ROOT 'shared\gup\gup.json') -Raw | ConvertFrom-Json
    Assert-Equal 1 $gup.schema_version 'schema_version:'
    $names = @(Get-GoToolNames -RepoRoot $REPO_ROOT)
    Assert-True ($names.Count -gt 0) 'no packages'
    Assert-True ($names -contains 'folgit') 'folgit is missing'
    Assert-Equal $names.Count @($names | Select-Object -Unique).Count 'duplicate names:'
    foreach ($pkg in $gup.packages) {
        Assert-True ($pkg.import_path -match '^[\w.-]+\.[a-z]+/') "$($pkg.name) has no usable import_path"
        Assert-True ($pkg.import_path -notmatch '@') "$($pkg.name)'s import_path carries a version"
    }
}

Test-Case 'a Go tool missing from the Go bin dir is reported, a present one is not' {
    $previous = $env:GOBIN
    $env:GOBIN = Join-Path $TMP 'gobin'
    try {
        New-Item -ItemType Directory -Force -Path $env:GOBIN | Out-Null
        Assert-Equal @('folgit') @(Get-MissingGoTools -RepoRoot $REPO_ROOT) 'before:'
        Set-Content -LiteralPath (Join-Path $env:GOBIN 'folgit.exe') -Value ''
        Assert-Equal @() @(Get-MissingGoTools -RepoRoot $REPO_ROOT) 'after:'
    } finally {
        $env:GOBIN = $previous
    }
}

Test-Case 'mise leaves GOBIN alone, so Go tools survive a Go upgrade' {
    $config = Get-Content -LiteralPath (Join-Path $REPO_ROOT 'shared\mise\config.toml') -Raw
    Assert-True ($config -match '(?m)^go\.set_gobin\s*=\s*false') 'go.set_gobin = false is missing'
    Assert-True ($config -match '(?m)^gup\s*=') 'gup is not in the mise config'
}

# ─── Checksums ────────────────────────────────────────────────────────────────

$listing = @"
68e3bd6164864b8b514605bc34e3a87ac401c8c48682fcce6478c70263340207  FiraCode.tar.xz
239395BAF60C89B2EAF4862B6B09DB0EF95605CD3E8EEF51C00345822A81A665 *FiraCode.zip
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff  FiraCode.zip.sig
"@

Test-Case 'a checksum listing yields the hash for the exact name, lowercased' {
    Assert-Equal '239395baf60c89b2eaf4862b6b09db0ef95605cd3e8eef51c00345822a81a665' `
        (ConvertFrom-ChecksumList -Text $listing -Name 'FiraCode.zip')
    Assert-Equal '68e3bd6164864b8b514605bc34e3a87ac401c8c48682fcce6478c70263340207' `
        (ConvertFrom-ChecksumList -Text ($listing -replace "`n", "`r`n") -Name 'FiraCode.tar.xz') 'CRLF listing:'
}

Test-Case 'a name missing from the listing yields nothing rather than a near match' {
    Assert-True ($null -eq (ConvertFrom-ChecksumList -Text $listing -Name 'FiraCode')) 'prefix matched'
    Assert-True ($null -eq (ConvertFrom-ChecksumList -Text '' -Name 'FiraCode.zip')) 'empty listing matched'
}

Test-Case 'Test-FileSha256 accepts a match, and rejects a mismatch or a missing checksum' {
    $file = Join-Path $TMP 'payload.bin'
    [System.IO.File]::WriteAllBytes($file, [byte[]](1, 2, 3))
    $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
    Assert-True (Test-FileSha256 -Path $file -Expected $hash.ToLower()) 'lowercase match rejected'
    Assert-True (Test-FileSha256 -Path $file -Expected $hash) 'uppercase match rejected'
    Assert-True (-not (Test-FileSha256 -Path $file -Expected ('0' * 64))) 'mismatch accepted'
    Assert-True (-not (Test-FileSha256 -Path $file -Expected '')) 'missing checksum accepted'
}

# ─── Git ──────────────────────────────────────────────────────────────────────

Test-Case 'git include paths use forward slashes' {
    Assert-Equal 'C:/Users/me/dotfiles/shared/git/gitconfig' (ConvertTo-GitPath 'C:\Users\me\dotfiles\shared\git\gitconfig')
}

Test-Case 'Add-GitInclude adds once and Test-GitInclude sees it (isolated ~/.gitconfig)' {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Host '        (git not installed; skipped)'; return }
    $previous = $env:GIT_CONFIG_GLOBAL
    $env:GIT_CONFIG_GLOBAL = Join-Path $TMP 'gitconfig'
    try {
        $target = Join-Path $REPO_ROOT 'shared\git\gitconfig'
        # A setting already in ~/.gitconfig that the shared file also sets.
        Set-Content -LiteralPath $env:GIT_CONFIG_GLOBAL -Value "[merge]`n`tconflictStyle = diff3"
        Assert-True (-not (Test-GitInclude -Path $target)) 'include reported before it was added'
        Add-GitInclude -Path $target
        Add-GitInclude -Path $target
        Assert-True (Test-GitInclude -Path $target) 'include not found after adding'
        $paths = @(git config --global --get-all include.path)
        Assert-Equal 1 $paths.Count 'include added twice:'
        Assert-Equal 'true' (git config --includes --global pull.rebase) 'shared setting not in effect:'
        Assert-Equal 'diff3' (git config --includes --global merge.conflictStyle) 'the shared file overrode ~/.gitconfig:'
        # The shared file must parse: a typo there breaks every git command.
        git -c "include.path=$(ConvertTo-GitPath $target)" config --list *> $null
        Assert-Equal 0 $LASTEXITCODE 'shared/git/gitconfig does not parse:'
        git -c "include.path=$(ConvertTo-GitPath (Join-Path $REPO_ROOT 'shared\git\delta.gitconfig'))" config --list *> $null
        Assert-Equal 0 $LASTEXITCODE 'shared/git/delta.gitconfig does not parse:'
    } finally {
        $env:GIT_CONFIG_GLOBAL = $previous
    }
}

# ─── setup.ps1: shared links and the generated zellij config ──────────────────

# Lift the functions and the marker assignments out of setup.ps1 without
# running it.
$setupAst = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $REPO_ROOT 'windows\setup.ps1'), [ref]$null, [ref]$null)
$wanted = @('Get-SharedLinks', 'Test-DotfileLinked',
            'Write-GeneratedFile', 'Test-GeneratedFileCurrent',
            'Get-ZellijConfigContent', 'Write-ZellijConfig', 'Test-ZellijConfigCurrent',
            'Get-GitIgnoreContent', 'Write-GitIgnore', 'Test-GitIgnoreCurrent')
foreach ($fn in $setupAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
    if ($wanted -contains $fn.Name) { . ([scriptblock]::Create($fn.Extent.Text)) }
}
foreach ($assign in $setupAst.FindAll({ param($n)
            $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            "$($n.Left)" -in @('$ZELLIJ_MARKER', '$GIT_IGNORE_MARKER') }, $false)) {
    . ([scriptblock]::Create($assign.Extent.Text))
}

Test-Case 'every shared link points at a file that exists in the repo' {
    foreach ($link in Get-SharedLinks) {
        Assert-True (Test-Path -LiteralPath $link.Source) "missing: $($link.Source)"
    }
}

Test-Case 'the zellij config is the shared file plus default_shell pwsh, without a BOM' {
    $script:ZELLIJ_CONFIG = Join-Path $TMP 'zellij\config.kdl'
    Write-ZellijConfig
    $bytes = [System.IO.File]::ReadAllBytes($ZELLIJ_CONFIG)
    Assert-True (-not ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB)) 'written with a BOM'
    $text = [System.IO.File]::ReadAllText($ZELLIJ_CONFIG)
    Assert-True ($text.StartsWith($ZELLIJ_MARKER)) 'marker missing'
    Assert-True ($text -match '(?m)^default_shell "pwsh"$') 'default_shell missing'
    Assert-True ($text -match 'scroll_buffer_size') 'shared content missing'
    Assert-True (Test-ZellijConfigCurrent) 'not reported current right after writing'
}

Test-Case 'a zellij config you wrote yourself is backed up, not overwritten' {
    $script:ZELLIJ_CONFIG = Join-Path $TMP 'zellij-own\config.kdl'
    New-Item -ItemType Directory -Force -Path (Split-Path $ZELLIJ_CONFIG) | Out-Null
    Set-Content -LiteralPath $ZELLIJ_CONFIG -Value 'theme "mine"'
    Assert-True (-not (Test-ZellijConfigCurrent)) 'a foreign config reported current'
    Write-ZellijConfig
    $backups = @(Get-ChildItem -LiteralPath (Split-Path $ZELLIJ_CONFIG) -Filter 'config.kdl.bak-*')
    Assert-Equal 1 $backups.Count 'backups:'
    Assert-True ((Get-Content -LiteralPath $backups[0].FullName -Raw) -match 'mine') 'backup lost the content'
}

Test-Case 'a stale generated zellij config is rewritten in place, with no backup' {
    $script:ZELLIJ_CONFIG = Join-Path $TMP 'zellij-stale\config.kdl'
    New-Item -ItemType Directory -Force -Path (Split-Path $ZELLIJ_CONFIG) | Out-Null
    Set-Content -LiteralPath $ZELLIJ_CONFIG -Value "$ZELLIJ_MARKER`nold"
    Write-ZellijConfig
    Assert-True (Test-ZellijConfigCurrent) 'not rewritten'
    Assert-Equal 0 @(Get-ChildItem -LiteralPath (Split-Path $ZELLIJ_CONFIG) -Filter '*.bak-*').Count 'backups:'
}

# ─── setup.ps1: the git ignore file is copied, never linked ───────────────────
#
# Git for Windows treats a dangling global-ignore symlink as fatal for every
# command in every repo. The link dangled as soon as this checkout moved to a
# commit without shared/git/ignore, which locked git up on a real machine.

Test-Case 'the git ignore file is not among the shared links' {
    $targets = @(Get-SharedLinks | ForEach-Object { Split-Path $_.Target -Leaf })
    Assert-True ($targets -notcontains 'ignore') 'shared/git/ignore is linked; it must be copied'
}

Test-Case 'the git ignore file is written as a real file with the shared patterns' {
    $script:GIT_IGNORE = Join-Path $TMP 'git\ignore'
    Write-GitIgnore
    $item = Get-Item -LiteralPath $GIT_IGNORE -Force
    Assert-True (-not $item.LinkType) "written as a $($item.LinkType)"
    $text = [System.IO.File]::ReadAllText($GIT_IGNORE)
    Assert-True ($text.StartsWith($GIT_IGNORE_MARKER)) 'marker missing'
    Assert-True ($text -match '(?m)^\.DS_Store$') 'shared patterns missing'
    $bytes = [System.IO.File]::ReadAllBytes($GIT_IGNORE)
    Assert-True (-not ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB)) 'written with a BOM'
    Assert-True (Test-GitIgnoreCurrent) 'not reported current right after writing'
    # And git can read it as an exclude file.
    if (Get-Command git -ErrorAction SilentlyContinue) {
        git -c "core.excludesFile=$GIT_IGNORE" -C $REPO_ROOT status --short *> $null
        Assert-Equal 0 $LASTEXITCODE 'git rejects the copy as an exclude file:'
    }
}

Test-Case 'a git ignore file you wrote yourself is backed up, not overwritten' {
    $script:GIT_IGNORE = Join-Path $TMP 'git-own\ignore'
    New-Item -ItemType Directory -Force -Path (Split-Path $GIT_IGNORE) | Out-Null
    Set-Content -LiteralPath $GIT_IGNORE -Value '*.mine'
    Write-GitIgnore
    $backups = @(Get-ChildItem -LiteralPath (Split-Path $GIT_IGNORE) -Filter 'ignore.bak-*')
    Assert-Equal 1 $backups.Count 'backups:'
    Assert-True ((Get-Content -LiteralPath $backups[0].FullName -Raw) -match 'mine') 'backup lost the content'
}

Test-Case 'a git ignore symlink left by an older setup is replaced by a copy' {
    if (-not (Test-CanSymlink)) {
        Write-Host '        (needs Developer Mode or an elevated shell to create a symlink; skipped)'
        return
    }
    $script:GIT_IGNORE = Join-Path $TMP 'git-link\ignore'
    New-Item -ItemType Directory -Force -Path (Split-Path $GIT_IGNORE) | Out-Null
    New-Item -ItemType SymbolicLink -Path $GIT_IGNORE -Target (Join-Path $REPO_ROOT 'shared\git\ignore') | Out-Null
    Assert-True (-not (Test-GitIgnoreCurrent)) 'a symlink reported current, so the menu would never replace it'
    Write-GitIgnore
    Assert-True (-not (Get-Item -LiteralPath $GIT_IGNORE -Force).LinkType) 'still a link'
    Assert-True (Test-GitIgnoreCurrent) 'not current after replacing the link'
}

# ─── posh.d ───────────────────────────────────────────────────────────────────

Test-Case 'the init-script cache is written with a BOM and reused until the binary changes' {
    . (Join-Path $REPO_ROOT 'windows\posh.d\tools.ps1')
    $previous = $env:LOCALAPPDATA
    $env:LOCALAPPDATA = $TMP
    try {
        $cmd = Get-Command cmd.exe -CommandType Application | Select-Object -First 1
        $path = Get-CachedInitScript -Name probe -Command $cmd -Arguments @('/c', 'echo $probe = 1')
        $bytes = [System.IO.File]::ReadAllBytes($path)
        Assert-True ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) 'no BOM'
        . $path
        Assert-Equal 1 $probe 'cached script did not run:'

        $stamp = (Get-Item -LiteralPath $path).LastWriteTime
        Start-Sleep -Milliseconds 50
        $again = Get-CachedInitScript -Name probe -Command $cmd -Arguments @('/c', 'echo $probe = 2')
        Assert-Equal $stamp (Get-Item -LiteralPath $again).LastWriteTime 'regenerated although the binary is unchanged:'
    } finally {
        $env:LOCALAPPDATA = $previous
    }
}

Test-Case 'every posh.d file loads without error in a fresh shell' {
    $exe = [System.Diagnostics.Process]::GetCurrentProcess().Path
    $script = "`$ErrorActionPreference = 'Stop'; Get-ChildItem '$REPO_ROOT\windows\posh.d' -Filter *.ps1 | Sort-Object Name | ForEach-Object { . `$_.FullName }; 'LOADED'"
    $out = & $exe -NoProfile -NonInteractive -Command $script 2>&1
    Assert-True (($out | Select-Object -Last 1) -eq 'LOADED') "load failed: $($out -join ' | ')"
}

Test-Case 'ls is left as Get-ChildItem, so pipelines on it keep working' {
    $exe = [System.Diagnostics.Process]::GetCurrentProcess().Path
    $script = "Get-ChildItem '$REPO_ROOT\windows\posh.d' -Filter *.ps1 | Sort-Object Name | ForEach-Object { . `$_.FullName }; @(ls '$REPO_ROOT\windows\posh.d' | Where-Object Name -like '*.ps1').Count"
    $count = & $exe -NoProfile -NonInteractive -Command $script 2>$null | Select-Object -Last 1
    Assert-True ([int]$count -gt 0) "ls | Where-Object returned $count"
}

# ─── Done ─────────────────────────────────────────────────────────────────────

Remove-Item -LiteralPath $TMP -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "$script:passed passed, $script:failed failed"
if ($script:failed -gt 0) { exit 1 }
exit 0
