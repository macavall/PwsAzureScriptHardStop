# Azure PowerShell Script - Hard Stop of Azure App Services (PaaS) (*includes Function Apps*)

1. Open the Azure Portal and open the Azure Cloud Shell

<img width="1917" height="241" alt="image" src="https://github.com/user-attachments/assets/99faebc6-b72a-4044-a329-c5f49e4c3485" />

<br />

2. **Copy and Paste** the command below

```plain
iwr "https://raw.githubusercontent.com/macavall/PwsAzureScriptHardStop/refs/heads/master/AzureScriptHardRestart2.ps1"  -OutFile AzureScriptHardRestart2.ps1 && . ./AzureScriptHardRestart2.ps1
```

<img width="1900" height="319" alt="image" src="https://github.com/user-attachments/assets/0be91709-146d-433a-9d14-e7bd398b4458" />

<br />

3. Provide the **SubscriptionID, TenantID, ResourceGroupName, and FunctionName** as shown below

<img width="1915" height="301" alt="image" src="https://github.com/user-attachments/assets/abd06c26-4bbf-4698-8e20-92d29c5a72a0" />

---

Utilize this script to ensure the Kudu site and the Main site are completely shutdown.  When restarting, which can be done from the Azure Portal, the Kudu process will start a new process and build the environment from scratch in the same way a new worker added to the App Service Plan would be initialized.

<br />

https://github.com/user-attachments/assets/665af668-a261-4bc7-a46a-8bfb337e25fe

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

# Wait 30 seconds
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
Write-Host DONE!!!
