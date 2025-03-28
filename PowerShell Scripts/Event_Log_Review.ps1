# Define the time span for events (last 24 hours)
$startTime = (Get-Date).AddDays(-1)

# Get events from System and Application logs separately, including Critical
$systemEvents = Get-WinEvent -LogName "System" -MaxEvents 1000 | 
    Where-Object { $_.TimeCreated -ge $startTime -and 
                  ($_.LevelDisplayName -eq "Error" -or 
                   $_.LevelDisplayName -eq "Warning" -or 
                   $_.LevelDisplayName -eq "Critical") }
$applicationEvents = Get-WinEvent -LogName "Application" -MaxEvents 1000 | 
    Where-Object { $_.TimeCreated -ge $startTime -and 
                  ($_.LevelDisplayName -eq "Error" -or 
                   $_.LevelDisplayName -eq "Warning" -or 
                   $_.LevelDisplayName -eq "Critical") }

# Create HTML header with styling
$htmlHeader = @"
<!DOCTYPE html>
<html>
<head>
<title>Event Log Report - $(Get-Date)</title>
<style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    table { border-collapse: collapse; width: 100%; margin-bottom: 30px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #4CAF50; color: white; }
    h3 { color: #333; }
    .error { background-color: #ffcccc; }
    .warning { background-color: #fff3cd; }
    .critical { background-color: #f8d7da; }
</style>
</head>
<body>
<h2>Event Log Report</h2>
<p>Generated on: $(Get-Date)</p>
<p>Showing Critical, Error, and Warning events from last 24 hours</p>
"@

# Function to create table HTML for a set of events
function Create-EventTable($events, $title) {
    $html = "<h3>$title</h3>"
    $html += "<table>"
    $html += "<tr><th>Time</th><th>Level</th><th>Event ID</th><th>Provider</th><th>Message</th></tr>"
    
    if ($events) {
        foreach ($event in $events) {
            $class = switch ($event.LevelDisplayName) {
                "Error" { "error" }
                "Warning" { "warning" }
                "Critical" { "critical" }
                default { "" }
            }
            
            $html += "<tr class='$class'>"
            $html += "<td>$($event.TimeCreated)</td>"
            $html += "<td>$($event.LevelDisplayName)</td>"
            $html += "<td>$($event.Id)</td>"
            $html += "<td>$($event.ProviderName)</td>"
            $html += "<td>$($event.Message -replace '\r\n','<br>')</td>"
            $html += "</tr>"
        }
    } else {
        $html += "<tr><td colspan='5'>No events found for this period</td></tr>"
    }
    
    $html += "</table>"
    return $html
}

# Create separate tables for System and Application events
$systemTable = Create-EventTable $systemEvents "System Events"
$applicationTable = Create-EventTable $applicationEvents "Application Events"

# Combine all HTML parts
$htmlBody = $systemTable + $applicationTable
$htmlFooter = "</body></html>"
$htmlContent = $htmlHeader + $htmlBody + $htmlFooter

# Save to file
$outputFile = "EventLogReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
$htmlContent | Out-File $outputFile

# Open the report
Invoke-Item $outputFile