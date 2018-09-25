#-------------------------------------------
# CreateTeam.ps1
#-------------------------------------------
# provisions a Team out of an Office 365 Group
# September 2018, atwork.at. Script by Christoph Wilfing, Martina Grom, Toni Pohl

$TeamInfo = Get-Content $createteam -Raw | ConvertFrom-Json

# Create the Team and use Teams Powershell
$secpasswd = ConvertTo-SecureString $env:pass -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ($env:admin, $secpasswd)

# Important: The use who performs this operation must be OWNER of that group!
Connect-MicrosoftTeams -TenantId $env:TenantID -Credential $mycreds
New-Team -Group $TeamInfo.groupid

# Done.
