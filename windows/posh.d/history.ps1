# History helpers -- the counterparts to hg / ch / forget in
# shared/shell/history.sh.
#
# PowerShell keeps two histories. Get-History is this session only, and is
# gone when the window closes. PSReadLine keeps its own, in a file that every
# session appends to and that Up-arrow and Ctrl-R search -- that file is the
# one that matters, so these work on it as well as on the session.

# In-session history size (Get-History). PSReadLine's file has its own limit.
$MaximumHistoryCount = 10000

# Path to PSReadLine's history file, or $null in a host without PSReadLine.
function Get-PSReadLineHistoryPath {
    if (-not (Get-Module PSReadLine)) { return $null }
    return (Get-PSReadLineOption).HistorySavePath
}

# Search all saved history (every session), newest last.
function hg {
    param([Parameter(Mandatory)][string]$Pattern)
    $file = Get-PSReadLineHistoryPath
    if ($file -and (Test-Path -LiteralPath $file)) {
        Select-String -LiteralPath $file -Pattern $Pattern -SimpleMatch | ForEach-Object { $_.Line }
    } else {
        Get-History | Where-Object { $_.CommandLine -like "*$Pattern*" } | ForEach-Object { $_.CommandLine }
    }
}

# Clear history: this session, PSReadLine's in-memory copy, and the file.
function ch {
    Clear-History
    if (Get-Module PSReadLine) {
        [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory()
    }
    $file = Get-PSReadLineHistoryPath
    if ($file -and (Test-Path -LiteralPath $file)) {
        Clear-Content -LiteralPath $file
    }
    Write-Host "History cleared (session and $(if ($file) { $file } else { 'no PSReadLine file' }))"
}

# Forget the previous command: removes it from the session and from the saved
# history file. Removes every saved copy of that exact line, since the file
# does not record which copy came from this session.
function forget {
    $last = Get-History -Count 1
    if (-not $last) {
        Write-Host "Nothing to forget"
        return
    }
    Clear-History -Id $last.Id

    $file = Get-PSReadLineHistoryPath
    if ($file -and (Test-Path -LiteralPath $file)) {
        $lines = @(Get-Content -LiteralPath $file)
        # The file is appended as you type, so its last line is this `forget`;
        # drop it too, along with the forgotten command.
        $kept = @($lines | Where-Object { $_ -ne $last.CommandLine })
        if ($kept.Count -gt 0 -and $kept[-1] -eq 'forget') {
            # Not $kept[0..-1] for a single line: in PowerShell that range
            # selects the first and last elements rather than none.
            $kept = if ($kept.Count -gt 1) { $kept[0..($kept.Count - 2)] } else { @() }
        }
        Set-Content -LiteralPath $file -Value $kept -Encoding utf8
    }
    Write-Host "Forgot: $($last.CommandLine)"
}
