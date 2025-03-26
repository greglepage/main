# Define parameters for the reboot time
$date = "2025-03-30"  # Format: YYYY-MM-DD
$time = "23:30"       # Format: HH:MM (24-hour)

# Combine date and time into a single datetime string
$rebootTime = "$date $time"

# Create the scheduled task action (reboot command)
$action = New-ScheduledTaskAction -Execute "shutdown.exe" -Argument "/r /t 0"

# Create the trigger for the specified date and time
$trigger = New-ScheduledTaskTrigger -Once -At $rebootTime

# Register the scheduled task
$taskName = "ScheduledReboot"
Register-ScheduledTask -TaskName $taskName `
                      -Action $action `
                      -Trigger $trigger `
                      -Description "Scheduled server reboot" `
                      -User "SYSTEM" `
                      -RunLevel Highest `
                      -Force

# Verify the task was created successfully
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($task) {
    Write-Host "Reboot successfully scheduled for $rebootTime"
    Write-Host "Task Details:"
    Write-Host "Task Name: $($task.TaskName)"
    Write-Host "Trigger: $($task.Triggers[0].StartBoundary)"
    Write-Host "Action: $($task.Actions[0].Execute) $($task.Actions[0].Arguments)"
} else {
    Write-Host "Failed to schedule reboot. Please check permissions and try again."
}