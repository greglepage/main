# Get Computer System Info
$computerInfo = Get-CimInstance -ClassName Win32_ComputerSystem
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$cpuInfo = Get-CimInstance -ClassName Win32_Processor
$memoryInfo = Get-CimInstance -ClassName Win32_PhysicalMemory
$diskInfo = Get-CimInstance -ClassName Win32_DiskDrive
$videoInfo = Get-CimInstance -ClassName Win32_VideoController
$usbDevices = Get-CimInstance -ClassName Win32_PnPEntity | Where-Object { $_.Service -like "usb*" -or $_.PNPClass -eq "USB" }
$printerInfo = Get-CimInstance -ClassName Win32_Printer
$monitorInfo = Get-CimInstance -ClassName Win32_DesktopMonitor
$networkInfo = Get-CimInstance -ClassName Win32_NetworkAdapter | Where-Object { $_.PhysicalAdapter -eq $true }
$keyboardInfo = Get-CimInstance -ClassName Win32_Keyboard
$pointingDeviceInfo = Get-CimInstance -ClassName Win32_PointingDevice

# Helper function to handle null/empty values and limit list length
function Format-ListOutput {
    param ($Items)
    if (-not $Items) { return "None detected" }
    $list = $Items | ForEach-Object { $_ } | Select-Object -First 5  # Limit to 5 items
    return ($list -join ", ")
}

# Create a custom object to store the inventory
$inventory = [PSCustomObject]@{
    "Computer Name"         = $computerInfo.Name
    "Manufacturer"          = $computerInfo.Manufacturer
    "Model"                 = $computerInfo.Model
    "OS Name"               = $osInfo.Caption
    "OS Version"            = $osInfo.Version
    "CPU"                   = $cpuInfo.Name
    "CPU Cores"             = $cpuInfo.NumberOfCores
    "Total RAM (GB)"        = "{0:N2}" -f ($computerInfo.TotalPhysicalMemory / 1GB)
    "Memory Modules"        = Format-ListOutput ($memoryInfo | ForEach-Object { "$($_.Capacity / 1GB) GB" })
    "Disks"                 = Format-ListOutput ($diskInfo | ForEach-Object { "$($_.Model) ($("{0:N2}" -f ($_.Size / 1GB)) GB)" })
    "Graphics Card"         = Format-ListOutput $videoInfo.Name
    "USB Devices"           = Format-ListOutput ($usbDevices | ForEach-Object { $_.Name })
    "Printers"              = Format-ListOutput ($printerInfo | ForEach-Object { $_.Name })
    "Monitors"              = Format-ListOutput ($monitorInfo | ForEach-Object { $_.Description })
    "Network Adapters"      = Format-ListOutput ($networkInfo | ForEach-Object { $_.Name })
    "Keyboards"             = Format-ListOutput ($keyboardInfo | ForEach-Object { $_.Description })
    "Pointing Devices"      = Format-ListOutput ($pointingDeviceInfo | ForEach-Object { $_.Description })
}

# Display a clean header
Write-Host "=== Hardware Inventory ===" -ForegroundColor Cyan
Write-Host "Generated on: $(Get-Date)" -ForegroundColor Gray
Write-Host "==========================" -ForegroundColor Cyan
Write-Host ""

# Display the inventory in a simpler, reliable format
$inventory.PSObject.Properties | ForEach-Object {
    Write-Host "$($_.Name): " -ForegroundColor Yellow -NoNewline
    Write-Host "$($_.Value)" -ForegroundColor White
}

# Optionally, save to a file (commented out by default)
# $inventory | Export-Csv -Path "FullHardwareInventory.csv" -NoTypeInformation
# Write-Host "Inventory saved to FullHardwareInventory.csv" -ForegroundColor Green
Write-Host "`nTo save this to a CSV file, uncomment the Export-Csv lines at the bottom of the script." -ForegroundColor Gray