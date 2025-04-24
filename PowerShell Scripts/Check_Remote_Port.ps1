$server = Read-Host "Enter the server name or IP address"
$port = Read-Host "Enter the port number to test"
$timeout = 1000 # Timeout in milliseconds

try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $result = $tcp.ConnectAsync($server, $port).Wait($timeout)
    
    if ($result) {
        Write-Host "Port $port is open on $server" -ForegroundColor Green
    } else {
        Write-Host "Port $port is closed or unreachable on $server" -ForegroundColor Red
    }
} catch {
    Write-Host "Error connecting to $server on port $port : $_" -ForegroundColor Red
} finally {
    if ($tcp) { $tcp.Close(); $tcp.Dispose() }
}