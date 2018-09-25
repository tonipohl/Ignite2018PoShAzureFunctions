#-------------------------------------------
# RunStatistics.sp1
#-------------------------------------------
# reads all existing Office 365 groups and writes their main properties to a queue for further processing.
# September 2018, atwork.at. Script by Christoph Wilfing, Martina Grom, Toni Pohl

#-------------------------------------------
#region Define the queue to fill
#-------------------------------------------
$AZQueueName = "onegroup"

Write-Output "TenantID: $env:TenantID AppID: $env:AppID AppSecret: $($($env:AppSecret).length) characters"
#endregion

#-------------------------------------------
#region Authorization
#-------------------------------------------
function Initialize-Authorization {
    param
    (
        [string]
        $ResourceURL = 'https://graph.microsoft.com',
  
        [string]
        [parameter(Mandatory)]
        $TenantID,
      
        [string]
        [Parameter(Mandatory)]
        $ClientKey,
  
        [string]
        [Parameter(Mandatory)]
        $AppID
    )

    $Authority = "https://login.windows.net/$TenantID/oauth2/token"

    [Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
    $EncodedKey = [System.Web.HttpUtility]::UrlEncode($ClientKey)

    $body = "grant_type=client_credentials&client_id=$AppID&client_secret=$EncodedKey&resource=$ResourceUrl"

    # Request a Token from the graph api
    $result = Invoke-RestMethod -Method Post `
        -Uri $Authority `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body $body

    $script:APIHeader = @{'Authorization' = "Bearer $($result.access_token)" }
}

#-------------------------------------------
# Initialize Authorization
#-------------------------------------------
Initialize-AUthorization -TenantID $env:TenantID -ClientKey $env:AppSecret -AppID $env:AppID
#endregion

#-------------------------------------------
# clear the result table ith a Logic App
#-------------------------------------------
# T18: 
$uri = "[your logic app url in here]"
Write-Output "Clear: $($uri)"

$logicappresult = Invoke-RestMethod `
    -Method Post `
    -Uri $uri

#-------------------------------------------
#region get all groups
#-------------------------------------------
try {
    $uri = "https://graph.microsoft.com/v1.0/groups?`$filter=groupTypes/any(c:c eq 'Unified')"

    $result = Invoke-RestMethod `
        -Method Get `
        -Uri $uri `
        -ContentType 'application/json' `
        -Headers $script:APIHeader `

    Write-Output "Number groups received: $($result.value.count)"
}
catch [System.Net.WebException] {
    Write-Output "GetAllGroups: WebException: $($_.exception)"
    Write-Output "GetAllGroups: ErrorCode: [$($_.Exception.Response.StatusCode.value__)]"
}
catch {
    Write-Output "GetAllGroups: Another Exception caught: [$($_.Exception)]"
}

#-------------------------------------------
# Queue each group
#-------------------------------------------
# Queuing items manually as the output binding only allows to create exactly one item.
# So, we need to fill the queue with multiple items (groups) in code here.
Write-Host 'creating azure storage context'
$storeAuthContext = New-AzureStorageContext -ConnectionString $env:AzureWebJobsStorage  -ErrorAction SilentlyContinue
$outQueue = Get-AzureStorageQueue –Name $AZQueueName -Context $storeAuthContext -ErrorAction SilentlyContinue

if ($null -eq $outQueue) {
    Write-Host 'Creating queue as it seems it does already not exist.'
    $outQueue = New-AzureStorageQueue –Name $AZQueueName -Context $storeAuthContext
}

# each item in the result is a group which needs to be queued
foreach ($Group in $result.value) {
    $QueueItem = @{
        GroupDisplayName = $group.DisplayName
        GroupId          = $group.id
        GroupMail        = $group.mail
    }
    Write-Output "Creating queue message for: $($group.Displayname)"
    $QueueItemJson = $QueueItem | ConvertTo-Json -Compress
    $queueMessage = New-Object `
        -TypeName Microsoft.WindowsAzure.Storage.Queue.CloudQueueMessage `
        -ArgumentList ($QueueItemJson)

    try {
        $outQueue.CloudQueue.AddMessage($queueMessage)
    }
    catch {
        Write-Output "GetAllGroups: Another Exception caught: [$($_.Exception)]"
    }
}
#endregion
# Done. Now the OneGroup function can process each group.

