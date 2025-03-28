# Requires running as Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as an Administrator"
    exit 1
}

# Enable verbose output
$VerbosePreference = "Continue"

# Install PSWindowsUpdate module if not present
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Verbose "Installing PSWindowsUpdate module..."
    Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -Verbose
}

# Import the module
Import-Module PSWindowsUpdate -Verbose

# Prevent automatic reboot by setting registry key
Write-Verbose "Configuring update settings to prevent immediate reboot..."
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
Set-ItemProperty -Path $regPath -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Force -Verbose

# Search for all available updates
Write-Verbose "Searching for available updates..."
$updates = Get-WindowsUpdate -MicrosoftUpdate -Verbose

# Display available updates
if ($updates) {
    Write-Verbose "Found $($updates.Count) updates available:"
    $updates | Format-Table -Property Title,KB,Size,LastDeploymentChangeTime -AutoSize
} else {
    Write-Verbose "No updates found."
    exit 0
}

# Download and install updates without reboot prompt
Write-Verbose "Downloading and installing updates..."
Install-WindowsUpdate -AcceptAll -Download -Install -IgnoreReboot -Confirm:$false -Verbose

# Check for firmware updates specifically
Write-Verbose "Checking for firmware updates..."
Get-WindowsUpdate -MicrosoftUpdate -Category "Firmware" -Verbose | 
    Install-WindowsUpdate -AcceptAll -Download -Install -IgnoreReboot -Confirm:$false -Verbose

# Verify installation status
Write-Verbose "Checking update installation status..."
Get-WUHistory -Last 10 | Format-Table -Property Title,Date,Result -AutoSize

# Clean up registry change
Write-Verbose "Cleaning up temporary settings..."
Remove-ItemProperty -Path $regPath -Name "NoAutoRebootWithLoggedOnUsers" -ErrorAction SilentlyContinue -Verbose

Write-Verbose "Update process completed! Note: Some updates may require a manual reboot later."