# === Bidirectional Robocopy SMB Throughput Test (both directions per run) ===
# Run in elevated PowerShell on DON-SAGE300-01
# Ctrl+C to quit

Write-Host "=== Bidirectional SMB Throughput Test ===" -ForegroundColor Cyan
Write-Host "Server→WS (download) + WS→Server (upload) — 5 runs each`nCtrl+C to quit`n" -ForegroundColor Yellow

while ($true) {
    $ws = (Read-Host "Enter workstation hostname").Trim()
    if ($ws -eq '') { continue }

    $testFolder = "\\$ws\C$\SpeedTest"
    if (-not (Test-Path $testFolder)) { New-Item $testFolder -ItemType Directory -Force | Out-Null }

    $runs = 5
    $downSpeeds = @()
    $upSpeeds   = @()

    Write-Host "Testing $ws (both directions)..." -ForegroundColor Cyan

    for ($i = 1; $i -le $runs; $i++) {
        $unique = "test-$(Get-Date -Format 'HHmmssfff')-$i.bin"
        $localFile = "$env:TEMP\$unique"

        # Create fresh 1GB file on server
        $fs = [IO.File]::Create($localFile); $fs.SetLength(1GB); $fs.Close()

        # === Server → WS (Download from workstation perspective) ===
        Write-Host "  Run $i - Down (Server→WS): " -NoNewline
        $timeDown = (Measure-Command { robocopy $env:TEMP $testFolder $unique /J /MT:8 /NP /R:1 /W:1 /IS | Out-Null }).TotalSeconds
        $downSpeed = [math]::Round(1024 / $timeDown, 2)
        $downSpeeds += $downSpeed
        Write-Host "$downSpeed MB/s" -ForegroundColor Green

        # === WS → Server (Upload from workstation perspective) ===
        Write-Host "  Run $i - Up   (WS→Server): " -NoNewline
        $timeUp = (Measure-Command { robocopy $testFolder $env:TEMP $unique /J /MT:8 /NP /R:1 /W:1 /IS /MOVE | Out-Null }).TotalSeconds
        $upSpeed = [math]::Round(1024 / $timeUp, 2)
        $upSpeeds += $upSpeed
        Write-Host "$upSpeed MB/s" -ForegroundColor Green

        Remove-Item $localFile -Force -EA SilentlyContinue
    }

    $avgDown = [math]::Round(($downSpeeds | Measure-Object -Average).Average, 2)
    $avgUp   = [math]::Round(($upSpeeds   | Measure-Object -Average).Average, 2)

    Write-Host "`n--- Summary for $ws ---" -ForegroundColor Cyan
    Write-Host "Avg Download (Server→WS): $avgDown MB/s" -ForegroundColor Green
    Write-Host "Avg Upload   (WS→Server): $avgUp MB/s" -ForegroundColor Green
    Write-Host "`n"
}