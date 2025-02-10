# System information functions
function sysinfo {
    # Get Operating System Information
    $os = Get-WmiObject -Class Win32_OperatingSystem
    Write-Host "==================== SYSTEM INFORMATION ===================="
    Write-Host "Operating System: $($os.Caption)"
    Write-Host "Version: $($os.Version)"
    Write-Host "Build Number: $($os.BuildNumber)"
    Write-Host "Architecture: $($os.OSArchitecture)"
    Write-Host "Last Boot Time: $([System.Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime))"
    Write-Host ""

    # Get Processor Information
    $cpu = Get-WmiObject -Class Win32_Processor
    Write-Host "==================== PROCESSOR INFORMATION ===================="
    foreach ($processor in $cpu) {
        Write-Host "Name: $($processor.Name)"
        Write-Host "Cores: $($processor.NumberOfCores)"
        Write-Host "Logical Processors: $($processor.NumberOfLogicalProcessors)"
        Write-Host "Clock Speed: $($processor.MaxClockSpeed) MHz"
    }
    Write-Host ""

    # Get Memory Information
    $os = Get-WmiObject -Class Win32_OperatingSystem
    $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
    
    # Physical Memory calculations
    $totalPhysMB = [math]::Round($computerSystem.TotalPhysicalMemory / 1MB, 2)
    $totalPhysGB = [math]::Round($totalPhysMB / 1024, 2)
    $availPhysMB = [math]::Round($os.FreePhysicalMemory / 1KB, 2)
    $availPhysGB = [math]::Round($availPhysMB / 1024, 2)
    $usedPhysMB = $totalPhysMB - $availPhysMB
    $usedPhysGB = [math]::Round($usedPhysMB / 1024, 2)
    $usedPhysPercent = [math]::Round(($usedPhysMB / $totalPhysMB) * 100, 1)

    # Virtual Memory calculations
    $totalVirtualMB = [math]::Round($os.TotalVirtualMemorySize / 1KB, 2)
    $totalVirtualGB = [math]::Round($totalVirtualMB / 1024, 2)
    $availVirtualMB = [math]::Round($os.FreeVirtualMemory / 1KB, 2)
    $availVirtualGB = [math]::Round($availVirtualMB / 1024, 2)
    $usedVirtualMB = $totalVirtualMB - $availVirtualMB
    $usedVirtualGB = [math]::Round($usedVirtualMB / 1024, 2)
    $usedVirtualPercent = [math]::Round(($usedVirtualMB / $totalVirtualMB) * 100, 1)

    # Create progress bars (20 chars wide)
    $physProgressBar = "[" + ("█" * [math]::Round($usedPhysPercent / 5)) + ("-" * [math]::Round((100 - $usedPhysPercent) / 5)) + "]"
    $virtualProgressBar = "[" + ("█" * [math]::Round($usedVirtualPercent / 5)) + ("-" * [math]::Round((100 - $usedVirtualPercent) / 5)) + "]"

    Write-Host "==================== MEMORY INFORMATION ===================="
    Write-Host "Physical Memory:"
    Write-Host $physProgressBar -NoNewline
    Write-Host " $usedPhysPercent% ($usedPhysGB GB / $totalPhysGB GB)"
    Write-Host "└─ Available: $availPhysGB GB"
    Write-Host ""
    Write-Host "Virtual Memory (Including Page File):"
    Write-Host $virtualProgressBar -NoNewline
    Write-Host " $usedVirtualPercent% ($usedVirtualGB GB / $totalVirtualGB GB)"
    Write-Host "└─ Available: $availVirtualGB GB"
    Write-Host ""

    # Get Disk Information
    $disks = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3"
    Write-Host "==================== DISK INFORMATION ===================="
    foreach ($disk in $disks) {
        $totalGB = [math]::Round($disk.Size / 1GB, 2)
        $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
        $usedGB = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 2)
        $usedPercent = [math]::Round(($usedGB / $totalGB) * 100, 1)
        
        # Create progress bar (20 chars wide)
        $diskProgressBar = "[" + ("█" * [math]::Round($usedPercent / 5)) + ("-" * [math]::Round((100 - $usedPercent) / 5)) + "]"
        
        Write-Host "Drive $($disk.DeviceID) ($($disk.FileSystem)):"
        Write-Host $diskProgressBar -NoNewline
        Write-Host " $usedPercent% ($usedGB GB / $totalGB GB)"
        Write-Host "└─ Available: $freeGB GB"
        Write-Host ""
    }

    # Get Network Information
    $networkAdapters = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True"
    Write-Host "==================== NETWORK INFORMATION ===================="
    foreach ($adapter in $networkAdapters) {
        Write-Host "Adapter: $($adapter.Description)"
        Write-Host "IP Address: $($adapter.IPAddress -join ', ')"
        Write-Host "MAC Address: $($adapter.MACAddress)"
    }
    Write-Host ""

    # Get System Uptime
    $uptime = (Get-Date) - (gcim Win32_OperatingSystem).LastBootUpTime
    Write-Host "==================== SYSTEM UPTIME ===================="
    Write-Host "System Uptime: $([math]::round($uptime.TotalDays, 2)) days"
    Write-Host "========================================================"
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
    Select-Object -First 10 Name, @{Name = 'Memory (MB)'; Expression = { [math]::Round($_.WS / 1MB, 2) } } |
    Format-Table -AutoSize
}

# View disk usage
function disk {
    Get-Volume | 
    Where-Object { $_.DriveLetter } | 
    Select-Object DriveLetter, @{N = 'Size(GB)'; E = { [math]::Round($_.Size / 1GB, 2) } }, @{N = 'Free(GB)'; E = { [math]::Round($_.SizeRemaining / 1GB, 2) } }
}
