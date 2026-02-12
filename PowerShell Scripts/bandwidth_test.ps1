# SpeedTest Logger (CSV) - Runs Ookla Speedtest CLI every 10 minutes, logs to CSV in C:\Temp
 
# Run as Admin first time for download/extraction

$LogDir = "C:\Temp"
 
$LogFile = "$LogDir\SpeedTestLog_$(Get-Date -Format 'yyyy-MM-dd').csv"
 
$IntervalMinutes = 5
 
$DownloadDir = "C:\Temp\SpeedTestCLI"
 
$ZipFile = "$DownloadDir\speedtest.zip"
 
$ExePath = "$DownloadDir\speedtest.exe"
 
$DownloadUrl = "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-win64.zip"  # Latest as of recent checks; update if needed from https://www.speedtest.net/apps/cli

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
 
    "Timestamp,DownloadMbps,UploadMbps,LatencyMs,JitterMs,PacketLossPercent" | Out-File -FilePath $LogFile -Encoding utf8
 
}

Write-Host "Starting speed test loop every $IntervalMinutes minutes. Logging CSV to: $LogFile"
 
Write-Host "Press Ctrl+C to stop."

while ($true) {
 
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
 
    # Run test with JSON output
 
    $resultJson = & $ExePath --format=json --accept-license --accept-gdpr 2>$null
 
    if ($resultJson) {
 
        $json = $resultJson | ConvertFrom-Json
 
        $downloadMbps = [math]::Round($json.download.bandwidth / 125000, 2)  # bytes/sec -> Mbps
 
        $uploadMbps   = [math]::Round($json.upload.bandwidth / 125000, 2)
 
        $latency      = [math]::Round($json.ping.latency, 2)
 
        $jitter       = [math]::Round($json.ping.jitter, 2)
 
        $packetLoss   = if ($json.packetLoss -ne $null) { [math]::Round($json.packetLoss, 2) } else { "N/A" }
 
        $csvLine = "$timestamp,$downloadMbps,$uploadMbps,$latency,$jitter,$packetLoss"
 
    } else {
 
        $csvLine = "$timestamp,ERROR,ERROR,ERROR,ERROR,ERROR"
 
    }
 
    $csvLine | Out-File -FilePath $LogFile -Append -Encoding utf8
 
    Write-Host $csvLine  # Console feedback
 
    Start-Sleep -Seconds ($IntervalMinutes * 60)
 
}

 