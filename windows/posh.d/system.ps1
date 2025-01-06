# System information functions
function sysinfo {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor
    $mem = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum

    Write-Host "OS: $($os.Caption) $($os.Version)"
    Write-Host "CPU: $($cpu.Name)"
    Write-Host "Memory: $([math]::Round($mem.Sum / 1GB, 2)) GB"
}

# Network utilities
function ports {
    Get-NetTCPConnection | 
    Where-Object State -eq "Listen" | 
    Sort-Object LocalPort |
    Format-Table -AutoSize
}

# Process search (like ps aux | grep)
function psg($pattern) {
    Get-Process | Where-Object { $_.ProcessName -like "*$pattern*" }
}

# View memory usage
function mem {
    Get-Process | 
    Sort-Object -Property WS -Descending | 
    Select-Object -First 10 Name, @{Name='Memory (MB)';Expression={[math]::Round($_.WS / 1MB, 2)}} |
    Format-Table -AutoSize
}

# View disk usage
function disk {
    Get-Volume | 
    Where-Object { $_.DriveLetter } | 
    Select-Object DriveLetter, @{N='Size(GB)';E={[math]::Round($_.Size/1GB,2)}}, @{N='Free(GB)';E={[math]::Round($_.SizeRemaining/1GB,2)}}
}
