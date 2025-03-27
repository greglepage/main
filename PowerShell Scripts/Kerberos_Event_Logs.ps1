# Define the event ID and log name

$eventId = 4768

$logName = "Security"
 
# Get events with Event ID 4768

$events = Get-WinEvent -LogName $logName -FilterXPath "*[System[EventID=$eventId]]" -ErrorAction SilentlyContinue
 
# Process events to extract failures

$failureData = $events | ForEach-Object {

    $xmlData = [xml]$_.ToXml()

    $resultCode = $xmlData.Event.EventData.Data | Where-Object { $_.Name -eq "Status" } | Select-Object -ExpandProperty "#text"

    $user = $xmlData.Event.EventData.Data | Where-Object { $_.Name -eq "TargetUserName" } | Select-Object -ExpandProperty "#text"

    $clientIp = $xmlData.Event.EventData.Data | Where-Object { $_.Name -eq "IpAddress" } | Select-Object -ExpandProperty "#text"
 
    # Filter for failures (Result Code 0x6)

    if ($resultCode -eq "0x6") {

        [PSCustomObject]@{

            UserName   = $user

            ClientIP   = $clientIp

            TimeStamp  = $_.TimeCreated

            ResultCode = $resultCode

        }

    }

}
 
# Group and count failures by user and IP

$summary = $failureData | Group-Object -Property UserName, ClientIP | ForEach-Object {

    [PSCustomObject]@{

        UserName     = $_.Group[0].UserName

        ClientIP     = $_.Group[0].ClientIP

        FailureCount = $_.Count

        LastAttempt  = ($_.Group | Sort-Object TimeStamp -Descending | Select-Object -First 1).TimeStamp

    }

}
 
# HTML styling

$htmlHeader = @"
<!DOCTYPE html>
<html lang='en'>
<head>
<meta charset='UTF-8'>
<title>Kerberos TGT Failure Report (Event ID 4768)</title>
<style>

        body { font-family: Arial, sans-serif; background-color: #f4f4f4; margin: 20px; }

        h1 { color: #333; text-align: center; }

        table { width: 80%; margin: 20px auto; border-collapse: collapse; background-color: #fff; box-shadow: 0 0 10px rgba(0,0,0,0.1); }

        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }

        th { background-color: #4CAF50; color: white; }

        tr:nth-child(even) { background-color: #f2f2f2; }

        tr:hover { background-color: #ddd; }

        .footer { text-align: center; font-size: 12px; color: #777; margin-top: 20px; }
</style>
</head>
<body>
<h1>Kerberos TGT Failure Report (Event ID 4768)</h1>

"@
 
$htmlFooter = @"
<div class='footer'>Generated on $(Get-Date) by Grok 3 (xAI)</div>
</body>
</html>

"@
 
# Build HTML table

$htmlTable = "<table><tr><th>User Name</th><th>Client IP</th><th>Failure Count</th><th>Last Attempt</th></tr>"

foreach ($item in $summary) {

    $htmlTable += "<tr><td>$($item.UserName)</td><td>$($item.ClientIP)</td><td>$($item.FailureCount)</td><td>$($item.LastAttempt)</td></tr>"

}

$htmlTable += "</table>"
 
# Combine all parts into full HTML

$htmlContent = $htmlHeader + $htmlTable + $htmlFooter
 
# Save to file

$outputPath = "$env:USERPROFILE\Desktop\KerberosFailureReport.html"

$htmlContent | Out-File -FilePath $outputPath -Encoding UTF8
 
# Open the HTML file in the default browser

Invoke-Item $outputPath
 
# Display summary in console (optional)

$summary | Format-Table -AutoSize
 