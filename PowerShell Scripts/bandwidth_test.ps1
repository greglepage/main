# SpeedTest Logger (CSV) - Runs Ookla Speedtest CLI every 5 minutes, logs to CSV in C:\Temp\

# Includes ping test to 8.8.8.8 with status and per-ping count/details summary

# Updated ping detection to use ResponseTime presence for more reliable success counting
 
$LogDir = "C:\Temp"
 
$LogFile = "$LogDir\SpeedTestLog_$(Get-Date -Format 'yyyy-MM-dd').csv"
 
$IntervalMinutes = 5
 
$DownloadDir = "C:\Temp\SpeedTestCLI"
 
$ZipFile = "$DownloadDir\speedtest.zip"
 
$ExePath = "$DownloadDir\speedtest.exe"
 
$DownloadUrl = "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-win64.zip"  # Update from https://www.speedtest.net/apps/cli if newer version available
 
# Create directories if missing

if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }

if (-not (Test-Path $DownloadDir)) { New-Item -Path $DownloadDir -ItemType Directory -Force | Out-Null }
 
# Install CLI if missing

if (-not (Test-Path $ExePath)) {

    Write-Host "Downloading and extracting Ookla Speedtest CLI..."

    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipFile

    Expand-Archive -Path $ZipFile -DestinationPath $DownloadDir -Force

    Remove-Item $ZipFile -Force

    if (-not (Test-Path $ExePath)) {

        Write-Error "Failed to extract speedtest.exe - check URL/permissions or download manually from https://www.speedtest.net/apps/cli"

        exit

    }

    # Accept license once
& $ExePath --accept-license --accept-gdpr > $null 2>&1

}
 
# Write CSV header if file doesn't exist

if (-not (Test-Path $LogFile)) {

    "Timestamp,DownloadMbps,UploadMbps,LatencyMs,JitterMs,PacketLossPercent,PingToGoogleAvgMs,PingToGoogleLossPercent,PingStatus,PingDetails" | 

        Out-File -FilePath $LogFile -Encoding utf8

}
 
Write-Host "Starting speed test loop every $IntervalMinutes minutes. Logging CSV to: $LogFile"

Write-Host "Press Ctrl+C to stop."
 
while ($true) {

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Run ping test to 8.8.8.8 (4 pings) - improved reliability using ResponseTime check

    $pingSuccessCount = 0

    $pingTimes = @()

    $pingAvg = $null

    $pingLoss = $null

    $pingStatus = $null

    $pingDetails = $null
 
    try {

        $pingResults = Test-Connection -ComputerName 8.8.8.8 -Count 4 -ErrorAction Stop

        foreach ($result in $pingResults) {

            if ($null -ne $result.ResponseTime -and $result.ResponseTime -gt 0) {

                $pingTimes += $result.ResponseTime

                $pingSuccessCount++

            }

        }

    }

    catch {

        $pingAvg     = "ERROR"

        $pingLoss    = "ERROR"

        $pingStatus  = "ERROR"

        $pingDetails = "ERROR"

    }
 
    if ($null -eq $pingAvg) {  # Not set to ERROR from catch block

        $pingAvg   = if ($pingSuccessCount -gt 0) { [math]::Round(($pingTimes | Measure-Object -Average).Average, 0) } else { "N/A" }

        $pingLoss  = [math]::Round((4 - $pingSuccessCount) / 4 * 100, 2)

        # Build PingDetails (e.g., 4/4 @14ms, 3/4 @25ms, 2/4, 0/4)

        if ($pingSuccessCount -eq 0) {

            $pingDetails = "0/4"

        } elseif ($pingSuccessCount -le 1) {

            $pingDetails = "$pingSuccessCount/4"

        } else {

            $pingDetails = "$pingSuccessCount/4 @$pingAvg ms"

        }

        # Determine PingStatus

        if ($pingSuccessCount -eq 0) {

            $pingStatus = "HIGH_LOSS"

        } elseif ($pingLoss -ge 50) {

            $pingStatus = "HIGH_LOSS"

        } elseif ($pingLoss -gt 0) {

            $pingStatus = "PARTIAL_LOSS"

        } elseif ($pingAvg -gt 100) {

            $pingStatus = "HIGH_LATENCY"

        } else {

            $pingStatus = "OK"

        }

    }

    # Run speedtest with JSON output

    $resultJson = & $ExePath --format=json --accept-license --accept-gdpr 2>$null

    if ($resultJson) {

        $json = $resultJson | ConvertFrom-Json

        $downloadMbps = [math]::Round($json.download.bandwidth / 125000, 2)  # bytes/sec -> Mbps

        $uploadMbps   = [math]::Round($json.upload.bandwidth / 125000, 2)

        $latency      = [math]::Round($json.ping.latency, 2)

        $jitter       = [math]::Round($json.ping.jitter, 2)

        $packetLoss   = if ($json.packetLoss -ne $null) { [math]::Round($json.packetLoss, 2) } else { "N/A" }

        $csvLine = "$timestamp,$downloadMbps,$uploadMbps,$latency,$jitter,$packetLoss,$pingAvg,$pingLoss,$pingStatus,$pingDetails"

    } else {

        $csvLine = "$timestamp,ERROR,ERROR,ERROR,ERROR,ERROR,$pingAvg,$pingLoss,$pingStatus,$pingDetails"

    }

    $csvLine | Out-File -FilePath $LogFile -Append -Encoding utf8

    Write-Host $csvLine  # Console feedback

    Start-Sleep -Seconds ($IntervalMinutes * 60)

}
 
