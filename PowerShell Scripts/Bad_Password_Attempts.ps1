# Import Active Directory module
Import-Module ActiveDirectory

# Get all enabled AD users
$users = Get-ADUser -Filter {Enabled -eq $True} -Properties LastBadPasswordAttempt

# Create an array to store results
$results = @()

# Loop through each user
foreach ($user in $users) {
    $results += [PSCustomObject]@{
        UserName = $user.SamAccountName
        DisplayName = $user.Name
        LastBadPasswordAttempt = $user.LastBadPasswordAttempt
    }
}

# Sort results by LastBadPasswordAttempt (newest first) and display
$results | Sort-Object LastBadPasswordAttempt -Descending | 
    Format-Table -AutoSize

# Optionally, export to CSV
# $results | Export-Csv -Path "LastBadPasswordAttempts.csv" -NoTypeInformation