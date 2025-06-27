# Script to monitor Wi-Fi SSID signal strength
$intervalSeconds = 5  # Time between checks (adjust as needed)
$logFile = "$env:USERPROFILE\Documents\WiFiSignalLog.csv"  # Log file path

# Function to get signal quality description
function Get-SignalQuality {
    param ($SignalPercentage)
    $percentage = [int]($SignalPercentage -replace "%","")
    if ($percentage -gt 80) { return "Excellent" }
    elseif ($percentage -ge 60) { return "Good" }
    else { return "Poor" }
}

# Function to get SSID and signal strength
function Get-WiFiSignalStrength {
    try {
        # Retrieve Wi-Fi interface details
        $netshOutput = netsh wlan show interfaces
        $ssidLine = $netshOutput | Select-String "SSID" | Where-Object { $_ -notmatch "BSSID" } | Select-Object -First 1
        $signalLine = $netshOutput | Select-String "Signal" | Select-Object -First 1

        # Extract SSID and signal strength
        $ssid = if ($ssidLine) { $ssidLine -replace ".*SSID\s*:\s*","" } else { $null }
        $signal = if ($signalLine) { $signalLine -replace ".*Signal\s*:\s*","" } else { $null }

        # Check if SSID and signal strength are available
        if ($ssid -and $signal) {
            $signalValue = $signal.Trim()
            $ssidValue = $ssid.Trim()
            if ($signalValue -match "\d+%") {
                $quality = Get-SignalQuality -SignalPercentage $signalValue
                $logEntry = [PSCustomObject]@{
                    Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                    SSID = $ssidValue
                    SignalStrength = $signalValue
                    Quality = $quality
                }
                Write-Host "Time: $($logEntry.Timestamp) | SSID: $ssidValue | Signal Strength: $signalValue | Quality: $quality"
                # Append to CSV log file
                if (-not (Test-Path $logFile)) {
                    $logEntry | Export-Csv -Path $logFile -NoTypeInformation
                } else {
                    $logEntry | Export-Csv -Path $logFile -NoTypeInformation -Append
                }
            } else {
                Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | SSID: $ssidValue | Signal Strength: Not available"
            }
        } else {
            Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | No active Wi-Fi connection detected."
        }
    } catch {
        Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Error retrieving Wi-Fi data: $($_.Exception.Message)"
    }
}

# Check if Wi-Fi adapter is available
$wifiAdapter = Get-NetAdapter | Where-Object { $_.Name -eq "Wi-Fi" -and $_.Status -eq "Up" }
if (-not $wifiAdapter) {
    Write-Host "No active Wi-Fi adapter found. Please ensure the Wi-Fi adapter is enabled and connected."
    exit
}

# Main loop to monitor signal strength
Write-Host "Monitoring Wi-Fi signal strength for the connected SSID (Press Ctrl+C to stop)..."
Write-Host "Logging data to: $logFile"
try {
    while ($true) {
        Get-WiFiSignalStrength
        Start-Sleep -Seconds $intervalSeconds
    }
} catch {
    Write-Host "Monitoring stopped."
}