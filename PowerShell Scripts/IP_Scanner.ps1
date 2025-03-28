function Scan-Network {
    # Get current computer's IP address
    $currentIP = (Get-NetIPAddress -AddressFamily IPv4 | 
                 Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -notlike "169.*" } | 
                 Select-Object -First 1).IPAddress
    
    Write-Host "Current computer IP: $currentIP" -ForegroundColor Magenta
    Write-Host "Example input: 192.168.1.0/24 (for 192.168.1.0-255)" -ForegroundColor Gray
    
    # Prompt user for network to scan
    $inputRange = Read-Host "Enter network to scan (e.g., $currentIP/24) or press Enter for default ($currentIP/24)"
    
    # Use current IP with /24 as default if no input
    if ([string]::IsNullOrEmpty($inputRange)) {
        $inputRange = "$currentIP/24"
    }

    # Parse network and subnet mask
    if ($inputRange -match "^(\d+\.\d+\.\d+\.\d+)/(\d+)$") {
        $Network = $Matches[1]
        $SubnetMask = [int]$Matches[2]
    } else {
        Write-Error "Invalid format. Please use format like '192.168.1.0/24'"
        return
    }

    # Calculate IP range from network and subnet mask
    $ipBase = $Network.Split('.')[0..2] -join '.'
    $startIP = 1
    $endIP = [math]::Pow(2, (32 - $SubnetMask)) - 2

    Write-Host "Scanning network: $Network/$SubnetMask" -ForegroundColor Cyan
    Write-Host ("-" * 60) -ForegroundColor Cyan
    Write-Host ("{0,-15} {1,-20} {2,-25}" -f "IP Address", "MAC Address", "Hostname") -ForegroundColor Yellow
    Write-Host ("-" * 60) -ForegroundColor Cyan

    # Create a runspace pool for parallel processing
    $runspacePool = [RunspaceFactory]::CreateRunspacePool(1, 20) # Max 20 concurrent threads
    $runspacePool.Open()
    $jobs = @()
    $activeDevices = [System.Collections.Concurrent.ConcurrentBag[PSObject]]::new()

    # Script block for scanning each IP
    $scriptBlock = {
        param($ip)
        $result = Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($result) {
            try {
                $arpResult = arp -a $ip | Where-Object { $_ -match $ip }
                $macAddress = if ($arpResult) { ($arpResult -split "\s+")[2] } else { "Not Found" }
                $hostname = try { [System.Net.Dns]::GetHostEntry($ip).HostName } catch { "Unknown" }
                [PSCustomObject]@{
                    IP       = $ip
                    MAC      = $macAddress
                    Hostname = $hostname
                }
            } catch {
                $null  # Skip errors silently for speed
            }
        }
    }

    # Queue all IPs for parallel processing
    1..$endIP | ForEach-Object {
        $currentIP = "$ipBase.$_"
        $powershell = [PowerShell]::Create().AddScript($scriptBlock).AddArgument($currentIP)
        $powershell.RunspacePool = $runspacePool
        $jobs += [PSCustomObject]@{
            PowerShell = $powershell
            Handle     = $powershell.BeginInvoke()
        }
    }

    # Collect results
    foreach ($job in $jobs) {
        $result = $job.PowerShell.EndInvoke($job.Handle)
        if ($result) {
            $activeDevices.Add($result)
            Write-Host ("{0,-15} {1,-20} {2,-25}" -f $result.IP, $result.MAC, $result.Hostname)
        }
        $job.PowerShell.Dispose()
    }

    # Cleanup
    $runspacePool.Close()
    $runspacePool.Dispose()

    Write-Host ("-" * 60) -ForegroundColor Cyan
    Write-Host "Found $($activeDevices.Count) active devices" -ForegroundColor Green
    
    return $activeDevices.ToArray()
}

# Run the scanner
Scan-Network