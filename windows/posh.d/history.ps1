# Increase history size
$MaximumHistoryCount = 10000

# Search history
function hg($pattern) {
    Get-History | Where-Object { $_.CommandLine -like "*$pattern*" }
}

# Clear history
function ch {
    Clear-History
    Write-Host "PowerShell history cleared"
}

# Forget last command
function forget {
    $history = Get-History
    if ($history.Count -gt 0) {
        Clear-History -Count 1 -Newest
    }
}
