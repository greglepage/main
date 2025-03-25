# Comprehensive Server Performance Analysis Script with HTML Output
# Created on March 25, 2025
# Analyzes CPU, memory, disk, network, services, and event logs, outputs to a styled HTML report

# Function to calculate average performance counter value
function Get-AverageCounter {
    param (
        [string]$CounterPath,
        [int]$Samples = 6,
        [int]$IntervalSeconds = 10
    )
    $values = @()
    for ($i = 0; $i -lt $Samples; $i++) {
        $value = (Get-Counter -Counter $CounterPath -ErrorAction SilentlyContinue).CounterSamples.CookedValue
        $values += $value
        if ($i -lt $Samples - 1) { Start-Sleep -Seconds $IntervalSeconds }
    }
    return [math]::Round(($values | Measure-Object -Average).Average, 2)
}

# Function to calculate average counter values for multiple instances
function Get-AverageCounterInstances {
    param (
        [string]$CounterPath,
        [int]$Samples = 6,
        [int]$IntervalSeconds = 10
    )
    $results = @{}
    for ($i = 0; $i -lt $Samples; $i++) {
        $counters = Get-Counter -Counter $CounterPath -ErrorAction SilentlyContinue
        foreach ($sample in $counters.CounterSamples) {
            $instance = $sample.Path.Split('\')[-1].Trim(')')
            if (-not $results[$instance]) { $results[$instance] = @() }
            $results[$instance] += $sample.CookedValue
        }
        if ($i -lt $Samples - 1) { Start-Sleep -Seconds $IntervalSeconds }
    }
    foreach ($instance in $results.Keys) {
        $results[$instance] = [math]::Round(($results[$instance] | Measure-Object -Average).Average, 2)
    }
    return $results
}

# HTML Header with CSS Styling
$htmlHeader = @"
<!DOCTYPE html>
<html lang='en'>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>Server Performance Report - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            background-color: #f4f4f4;
            color: #333;
        }
        h1 {
            color: #2c3e50;
            text-align: center;
        }
        h2 {
            color: #34495e;
            border-bottom: 2px solid #3498db;
            padding-bottom: 5px;
        }
        .section {
            background-color: #fff;
            padding: 15px;
            margin-bottom: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
        }
        th, td {
            padding: 10px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #3498db;
            color: white;
        }
        tr:nth-child(even) {
            background-color: #f9f9f9;
        }
        .warning {
            color: #e74c3c;
            font-weight: bold;
        }
        .summary {
            font-size: 1.1em;
            padding: 10px;
            background-color: #ecf0f1;
            border-left: 5px solid #e74c3c;
        }
        .no-issues {
            color: #27ae60;
        }
    </style>
</head>
<body>
    <h1>Server Performance Report</h1>
"@

# Initialize HTML content and issues array
$htmlContent = @()
$potentialIssues = @()

# System Information
$htmlContent += "<div class='section'><h2>System Information</h2>"
$htmlContent += "<p><strong>Server Name:</strong> $env:COMPUTERNAME</p>"
$os = Get-WmiObject Win32_OperatingSystem
$htmlContent += "<p><strong>Operating System:</strong> $($os.Version)</p>"
$uptime = (Get-Date) - $os.LastBootUpTime
$htmlContent += "<p><strong>Uptime:</strong> $($uptime.Days) days $($uptime.Hours) hours</p>"
$htmlContent += "</div>"

# CPU Performance
$htmlContent += "<div class='section'><h2>CPU Performance</h2>"
$cpuCount = (Get-WmiObject Win32_Processor).Count
$htmlContent += "<p><strong>Number of CPUs:</strong> $cpuCount</p>"
$cpuUsage = Get-AverageCounter -CounterPath "\Processor(_Total)\% Processor Time"
$cpuClass = if ($cpuUsage -gt 80) { "warning" } else { "" }
$htmlContent += "<p><strong>Average CPU Usage:</strong> <span class='$cpuClass'>$cpuUsage%</span></p>"
if ($cpuUsage -gt 80) { $potentialIssues += "High CPU usage" }
$topCpuProcesses = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 -Property Name, @{Name='CPU%';Expression={[math]::Round($_.CPU / (Get-Date).Subtract($_.StartTime).TotalSeconds * 100 / $cpuCount, 2)}}
$htmlContent += "<table><tr><th>Process Name</th><th>CPU %</th></tr>"
foreach ($proc in $topCpuProcesses) {
    $htmlContent += "<tr><td>$($proc.Name)</td><td>$($proc.'CPU%')</td></tr>"
}
$htmlContent += "</table></div>"

# Memory Performance
$htmlContent += "<div class='section'><h2>Memory Performance</h2>"
$computer = Get-WmiObject Win32_ComputerSystem
$totalMemory = [math]::Round($computer.TotalPhysicalMemory / 1MB, 0)
$freeMemory = [math]::Round($os.FreePhysicalMemory / 1024, 0)
$usedMemoryPercent = [math]::Round((($totalMemory - $freeMemory) / $totalMemory) * 100, 2)
$memClass = if ($usedMemoryPercent -gt 90) { "warning" } else { "" }
$htmlContent += "<p><strong>Total Memory:</strong> $totalMemory MB</p>"
$htmlContent += "<p><strong>Free Memory:</strong> <span class='$memClass'>$freeMemory MB ($usedMemoryPercent% used)</span></p>"
if ($usedMemoryPercent -gt 90) { $potentialIssues += "Low memory" }
$pageFile = Get-WmiObject Win32_PageFileUsage
$htmlContent += "<p><strong>Page File Usage:</strong> $($pageFile.CurrentUsage) MB</p>"
$topMemProcesses = Get-Process | Sort-Object WS -Descending | Select-Object -First 5 -Property Name, @{Name='MemoryMB';Expression={[math]::Round($_.WS / 1MB, 2)}}
$htmlContent += "<table><tr><th>Process Name</th><th>Memory (MB)</th></tr>"
foreach ($proc in $topMemProcesses) {
    $htmlContent += "<tr><td>$($proc.Name)</td><td>$($proc.MemoryMB)</td></tr>"
}
$htmlContent += "</table></div>"

# Disk Performance
$htmlContent += "<div class='section'><h2>Disk Performance</h2>"
$disks = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
$htmlContent += "<table><tr><th>Drive</th><th>Total (GB)</th><th>Free (GB)</th><th>Usage %</th></tr>"
foreach ($disk in $disks) {
    $totalSpace = [math]::Round($disk.Size / 1GB, 2)
    $freeSpace = [math]::Round($disk.FreeSpace / 1GB, 2)
    $usedPercent = [math]::Round((($totalSpace - $freeSpace) / $totalSpace) * 100, 2)
    $diskClass = if ($usedPercent -gt 80) { "warning" } else { "" }
    $htmlContent += "<tr><td>$($disk.DeviceID)</td><td>$totalSpace</td><td>$freeSpace</td><td class='$diskClass'>$usedPercent</td></tr>"
    if ($usedPercent -gt 80) { $potentialIssues += "High disk usage on $($disk.DeviceID)" }
}
$htmlContent += "</table>"
$queueLengths = Get-AverageCounterInstances -CounterPath "\PhysicalDisk(*)\Avg. Disk Queue Length"
$htmlContent += "<h3>Average Disk Queue Length</h3><table><tr><th>Disk</th><th>Queue Length</th></tr>"
foreach ($instance in $queueLengths.Keys) {
    $queueClass = if ($queueLengths[$instance] -gt 2) { "warning" } else { "" }
    $htmlContent += "<tr><td>$instance</td><td class='$queueClass'>$($queueLengths[$instance])</td></tr>"
    if ($queueLengths[$instance] -gt 2) { $potentialIssues += "High queue length on $instance" }
}
$htmlContent += "</table>"
$diskTimes = Get-AverageCounterInstances -CounterPath "\PhysicalDisk(*)\% Disk Time"
$htmlContent += "<h3>Average Disk Time (%)</h3><table><tr><th>Disk</th><th>Disk Time %</th></tr>"
foreach ($instance in $diskTimes.Keys) {
    $diskTimeClass = if ($diskTimes[$instance] -gt 50) { "warning" } else { "" }
    $htmlContent += "<tr><td>$instance</td><td class='$diskTimeClass'>$($diskTimes[$instance])</td></tr>"
    if ($diskTimes[$instance] -gt 50) { $potentialIssues += "High disk time on $instance" }
}
$htmlContent += "</table></div>"

# Network Performance
$htmlContent += "<div class='section'><h2>Network Performance</h2>"
$adapters = Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.NetConnectionStatus -eq 2 }
$htmlContent += "<table><tr><th>Adapter</th><th>Speed (Mbps)</th><th>Status</th></tr>"
foreach ($adapter in $adapters) {
    $htmlContent += "<tr><td>$($adapter.NetConnectionID)</td><td>$($adapter.Speed / 1000000)</td><td>Connected</td></tr>"
}
$htmlContent += "</table>"
$networkTraffic = Get-AverageCounterInstances -CounterPath "\Network Interface(*)\Bytes Total/sec"
$htmlContent += "<h3>Average Network Traffic (KB/s)</h3><table><tr><th>Interface</th><th>Traffic (KB/s)</th></tr>"
foreach ($interface in $networkTraffic.Keys) {
    $trafficKB = [math]::Round($networkTraffic[$interface] / 1024, 2)
    $htmlContent += "<tr><td>$interface</td><td>$trafficKB</td></tr>"
}
$htmlContent += "</table></div>"

# Services
$htmlContent += "<div class='section'><h2>Services</h2>"
$stoppedServices = Get-Service | Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -ne 'Running' }
if ($stoppedServices) {
    $htmlContent += "<p>The following services are not running:</p>"
    $htmlContent += "<table><tr><th>Service Name</th><th>Display Name</th></tr>"
    foreach ($service in $stoppedServices) {
        $htmlContent += "<tr><td>$($service.Name)</td><td class='warning'>$($service.DisplayName)</td></tr>"
        $potentialIssues += "Service not running: $($service.DisplayName)"
    }
    $htmlContent += "</table>"
} else {
    $htmlContent += "<p>All automatic services are running.</p>"
}
$htmlContent += "</div>"

# Event Logs
$htmlContent += "<div class='section'><h2>Event Logs</h2>"
$eventLogs = @("System", "Application")
foreach ($log in $eventLogs) {
    $errors = Get-EventLog -LogName $log -EntryType Error -Newest 10 -ErrorAction SilentlyContinue
    if ($errors) {
        $htmlContent += "<h3>Latest $log Error Events</h3>"
        $htmlContent += "<table><tr><th>Time</th><th>Source</th><th>Message</th></tr>"
        foreach ($error in $errors) {
            $htmlContent += "<tr><td>$($error.TimeGenerated)</td><td>$($error.Source)</td><td class='warning'>$($error.Message)</td></tr>"
            $potentialIssues += "$log error: $($error.Message)"
        }
        $htmlContent += "</table>"
    }
}
$htmlContent += "</div>"

# Summary
$htmlContent += "<div class='section'><h2>Summary</h2>"
if ($potentialIssues) {
    $htmlContent += "<p class='summary'><strong>Potential issues that may be affecting performance:</strong><br>$($potentialIssues -join ', ')</p>"
} else {
    $htmlContent += "<p class='summary no-issues'><strong>No significant performance issues detected.</strong></p>"
}
$htmlContent += "</div>"

# HTML Footer
$htmlFooter = "</body></html>"

# Combine and Output to File
$htmlReport = $htmlHeader + $htmlContent + $htmlFooter
$htmlReport | Out-File "ServerPerformanceReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"

# Optionally open the report in the default browser
Invoke-Item "ServerPerformanceReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"