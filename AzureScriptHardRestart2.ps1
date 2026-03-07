<#
.SYNOPSIS
    Stops and then immediately restarts an Azure Function App using direct REST API (bypassing some Az module quirks)

.PARAMETER SubscriptionId
    Azure Subscription ID

.PARAMETER TenantId
    Azure AD Tenant ID

.PARAMETER ResourceGroupName
    Resource Group containing the Function App

.PARAMETER FunctionAppName
    Name of the Function App to restart

.EXAMPLE
    .\Restart-FunctionAppViaApi.ps1 -SubscriptionId "00000000-..." -TenantId "11111111-..." -ResourceGroupName "rg-myapp" -FunctionAppName "func-myfunction"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$FunctionAppName
)

# -------------------------------
#  Main logic
# -------------------------------

Set-AzContext -SubscriptionId $SubscriptionId -TenantId $TenantId

$accessToken = (Get-AzAccessToken -TenantId $TenantId).Token

$plainTextToken = $accessToken | ConvertFrom-SecureString -AsPlainText

$apiVersion = "2024-04-01"

# Get the Function App resource
$functionApp = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $FunctionAppName

$temp = "/subscriptions/" + $SubscriptionId + "/resourcegroups/" + $ResourceGroupName + "/providers/Microsoft.Web/sites/" + $FunctionAppName

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
