# Server Health Check Script
# Run with administrative privileges

function Write-Status {
    param($Message, $Status)
    switch ($Status) {
        "Success" { Write-Host $Message -ForegroundColor Green }
        "Warning" { Write-Host $Message -ForegroundColor Yellow }
        "Error" { Write-Host $Message -ForegroundColor Red }
        default { Write-Host $Message -ForegroundColor White }
    }
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$computerName = $env:COMPUTERNAME
$outputFile = "ServerHealthCheck_$computerName_$timestamp.txt"

"Server Health Check Report" | Out-File $outputFile
"Generated on: $timestamp" | Out-File $outputFile -Append
"Server Name: $computerName" | Out-File $outputFile -Append
"=====================================" | Out-File $outputFile -Append

# 1. System Information (unchanged)
Write-Status "Checking System Information..." "Default"
$os = Get-CimInstance Win32_OperatingSystem
$uptime = (Get-Date) - $os.LastBootUpTime
"System Information" | Out-File $outputFile -Append
"OS Name: $($os.Caption)" | Out-File $outputFile -Append
"OS Version: $($os.Version)" | Out-File $outputFile -Append
"Uptime: $($uptime.Days) days, $($uptime.Hours) hours" | Out-File $outputFile -Append
"" | Out-File $outputFile -Append

# 2. CPU Usage (unchanged)
Write-Status "Checking CPU Usage..." "Default"
$cpuUsage = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 2 -MaxSamples 3
$avgCpu = ($cpuUsage.CounterSamples.CookedValue | Measure-Object -Average).Average
"CPU Usage" | Out-File $outputFile -Append
"Average CPU Usage: $($avgCpu.ToString("F2"))%" | Out-File $outputFile -Append
if ($avgCpu -gt 80) { Write-Status "High CPU Usage Detected!" "Warning" }
"" | Out-File $outputFile -Append

# 3. Memory Usage (unchanged)
Write-Status "Checking Memory Usage..." "Default"
$memory = Get-CimInstance Win32_OperatingSystem
$totalMemory = $memory.TotalVisibleMemorySize / 1MB
$freeMemory = $memory.FreePhysicalMemory / 1MB
$usedMemory = $totalMemory - $freeMemory
$memoryPercent = ($usedMemory / $totalMemory) * 100
"Memory Usage" | Out-File $outputFile -Append
"Total Memory: $($totalMemory.ToString("F2")) GB" | Out-File $outputFile -Append
"Used Memory: $($usedMemory.ToString("F2")) GB" | Out-File $outputFile -Append
"Free Memory: $($freeMemory.ToString("F2")) GB" | Out-File $outputFile -Append
"Memory Usage: $($memoryPercent.ToString("F2"))%" | Out-File $outputFile -Append
if ($memoryPercent -gt 90) { Write-Status "Low Memory Warning!" "Warning" }
"" | Out-File $outputFile -Append

# 4. Disk Space (unchanged)
Write-Status "Checking Disk Space..." "Default"
$disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
"Disk Space" | Out-File $outputFile -Append
foreach ($disk in $disks) {
    $sizeGB = $disk.Size / 1GB
    $freeGB = $disk.FreeSpace / 1GB
    $usedGB = $sizeGB - $freeGB
    $percentFree = ($freeGB / $sizeGB) * 100
    "Drive $($disk.DeviceID)" | Out-File $outputFile -Append
    "Total Size: $($sizeGB.ToString("F2")) GB" | Out-File $outputFile -Append
    "Used Space: $($usedGB.ToString("F2")) GB" | Out-File $outputFile -Append
    "Free Space: $($freeGB.ToString("F2")) GB" | Out-File $outputFile -Append
    "Free Space %: $($percentFree.ToString("F2"))%" | Out-File $outputFile -Append
    if ($percentFree -lt 10) { Write-Status "Low Disk Space on $($disk.DeviceID)!" "Warning" }
    "" | Out-File $outputFile -Append
}

# 5. Critical Services Check (unchanged)
Write-Status "Checking Critical Services..." "Default"
$servicesToCheck = @("Dnscache", "Netlogon", "Spooler", "EventLog")
"Critical Services Status" | Out-File $outputFile -Append
foreach ($service in $servicesToCheck) {
    $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
    if ($svc) {
        "Service: $($svc.DisplayName) - Status: $($svc.Status)" | Out-File $outputFile -Append
        if ($svc.Status -ne "Running") { Write-Status "$service is not running!" "Error" }
    } else {
        "Service: $service - Not Found" | Out-File $outputFile -Append
    }
}
"" | Out-File $outputFile -Append

# 6. Event Log Check (corrected version)
Write-Status "Checking Event Logs..." "Default"
$timeLimit = (Get-Date).AddHours(-24)
$eventErrors = Get-WinEvent -LogName "System" -MaxEvents 100 | 
    Where-Object { $_.LevelDisplayName -eq "Error" -and $_.TimeCreated -ge $timeLimit }
"System Event Log Errors (Last 24 Hours)" | Out-File $outputFile -Append
"Total Errors: $($eventErrors.Count)" | Out-File $outputFile -Append
foreach ($evt in $eventErrors | Select-Object -First 5) {
    "Time: $($evt.TimeCreated)" | Out-File $outputFile -Append
    "Message: $($evt.Message)" | Out-File $outputFile -Append
    "" | Out-File $outputFile -Append
}
"" | Out-File $outputFile -Append

# 7. Network Connectivity (unchanged)
Write-Status "Checking Network Connectivity..." "Default"
$networkAdapters = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled }
"Network Status" | Out-File $outputFile -Append
foreach ($adapter in $networkAdapters) {
    "Adapter: $($adapter.Description)" | Out-File $outputFile -Append
    "IP Address: $($adapter.IPAddress -join ', ')" | Out-File $outputFile -Append
    "Default Gateway: $($adapter.DefaultIPGateway -join ', ')" | Out-File $outputFile -Append
    $ping = Test-Connection "google.com" -Count 4 -ErrorAction SilentlyContinue
    if ($ping) {
        $avgLatency = ($ping | Measure-Object ResponseTime -Average).Average
        "Internet Connectivity: OK (Avg Latency: $($avgLatency)ms)" | Out-File $outputFile -Append
    } else {
        Write-Status "Internet Connectivity Failed!" "Error"
        "Internet Connectivity: Failed" | Out-File $outputFile -Append
    }
    "" | Out-File $outputFile -Append
}

# 8. Windows Update Status
Write-Status "Checking Windows Update Status..." "Default"
"Windows Update Status" | Out-File $outputFile -Append
$lastUpdate = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1
if ($lastUpdate) {
    "Last Update Installed: $($lastUpdate.InstalledOn)" | Out-File $outputFile -Append
    "Description: $($lastUpdate.Description)" | Out-File $outputFile -Append
    $daysSinceUpdate = ((Get-Date) - $lastUpdate.InstalledOn).Days
    if ($daysSinceUpdate -gt 90) { Write-Status "No recent updates (over 90 days)!" "Warning" }
} else {
    Write-Status "Unable to determine last update!" "Warning"
    "Last Update: Unknown" | Out-File $outputFile -Append
}
"" | Out-File $outputFile -Append

# 9. Pending Reboot Check
Write-Status "Checking for Pending Reboots..." "Default"
"Pending Reboot Status" | Out-File $outputFile -Append
$pendingReboot = $false
if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue) {
    $pendingReboot = $true
}
if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue) {
    $pendingReboot = $true
}
if ($pendingReboot) {
    Write-Status "Pending Reboot Detected!" "Warning"
    "Status: Reboot Required" | Out-File $outputFile -Append
} else {
    "Status: No Reboot Required" | Out-File $outputFile -Append
}
"" | Out-File $outputFile -Append

# 10. Firewall Status
Write-Status "Checking Firewall Status..." "Default"
"Firewall Status" | Out-File $outputFile -Append
$firewallProfiles = Get-NetFirewallProfile
foreach ($profile in $firewallProfiles) {
    "Profile: $($profile.Name)" | Out-File $outputFile -Append
    "Enabled: $($profile.Enabled)" | Out-File $outputFile -Append
    if (-not $profile.Enabled) { Write-Status "$($profile.Name) Firewall is Disabled!" "Warning" }
    "" | Out-File $outputFile -Append
}

# 11. Top Resource-Consuming Processes
Write-Status "Checking Top Processes..." "Default"
"Top 5 Processes by CPU Usage" | Out-File $outputFile -Append
Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | 
    ForEach-Object { 
        "Name: $($_.ProcessName), CPU: $($_.CPU.ToString("F2")), Memory: $($_.WorkingSet/1MB.ToString("F2")) MB" | Out-File $outputFile -Append
    }
"" | Out-File $outputFile -Append

# 12. Temperature Check (requires hardware support)
Write-Status "Checking System Temperature..." "Default"
"Temperature Status" | Out-File $outputFile -Append
try {
    $temp = Get-CimInstance -Namespace "root\WMI" -ClassName "MSAcpi_ThermalZoneTemperature" -ErrorAction Stop
    if ($temp) {
        $tempCelsius = ($temp.CurrentTemperature / 10) - 273.15
        "Current Temperature: $($tempCelsius.ToString("F2"))°C" | Out-File $outputFile -Append
        if ($tempCelsius -gt 70) { Write-Status "High Temperature Detected!" "Warning" }
    } else {
        "Temperature: Not Available" | Out-File $outputFile -Append
    }
} catch {
    "Temperature: Monitoring not supported on this hardware" | Out-File $outputFile -Append
}
"" | Out-File $outputFile -Append

Write-Status "Server health check completed. Results saved to $outputFile" "Success"
"Check completed at: $(Get-Date)" | Out-File $outputFile -Append
Invoke-Item $outputFile