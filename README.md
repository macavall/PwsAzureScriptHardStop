# Azure PowerShell Script - Hard Stop of Azure App Services (PaaS) (*includes Function Apps*)

<br />

Utilize this script to ensure the Kudu site and the Main site are completely shutdown.  When restarting, which can be done from the Azure Portal, the Kudu process will start a new process and build the environment from scratch in the same way a new worker added to the App Service Plan would be initialized.

<br />

## PowerShell Script

```PowerShell
$subId = ""
$TenId = ""

Set-AzContext -SubscriptionId $subId -TenantId $TenId

$accessToken = (Get-AzAccessToken -TenantId $TenId).Token

$plainTextToken = $accessToken | ConvertFrom-SecureString -AsPlainText

$resourceGroupName = ""
$functionAppName = ""
$apiVersion = "2024-04-01"

# Get the Function App resource
$functionApp = Get-AzWebApp -ResourceGroupName $resourceGroupName -Name $functionAppName

$temp = "/subscriptions/" + $subId + "/resourcegroups/" + $resourceGroupName + "/providers/Microsoft.Web/sites/" + $functionAppName

# Retrieve the Resource ID
$resourceId = $functionApp.Id

# Construct the URL
$managementUrl = "https://management.azure.com" + $resourceId + "?api-version=$apiVersion"

# Stop the Function App (State = "Stopped")
$stopBody = @{
    properties = @{
        state = "Stopped"
        scmSiteAlsoStopped = "True"
    }
} | ConvertTo-Json -Depth 3

Write-Host Start-Request
Write-Host ([DateTime]::UtcNow)
Invoke-RestMethod -Uri $managementUrl -Method PATCH -Body $stopBody -ContentType "application/json" -Headers @{ Authorization = "Bearer $plainTextToken" }
Write-Host Complete-Request
Write-Host ([DateTime]::UtcNow)

sleep 30

# Stop the Function App (State = "Stopped")
$stopBody = @{
    properties = @{
        state = "Running"
        scmSiteAlsoStopped = "False"
    }
} | ConvertTo-Json -Depth 3

Write-Host Start-Request
Write-Host ([DateTime]::UtcNow)
Invoke-RestMethod -Uri $managementUrl -Method PATCH -Body $stopBody -ContentType "application/json" -Headers @{ Authorization = "Bearer $plainTextToken" }
Write-Host Complete-Request
Write-Host ([DateTime]::UtcNow)
