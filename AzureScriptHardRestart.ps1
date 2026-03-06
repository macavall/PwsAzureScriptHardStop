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

Write-Host "Starting Function App restart sequence..."
Write-Host "Target: $FunctionAppName in $ResourceGroupName"

# 1. Set proper context
try {
    Write-Host "Setting Azure context..."
    $null = Set-AzContext -SubscriptionId $SubscriptionId -TenantId $TenantId -ErrorAction Stop
}
catch {
    Write-Error "Failed to set context: $($_.Exception.Message)"
    exit 1
}

# 2. Get current access token
try {
    Write-Host "Acquiring access token..."
    $token = (Get-AzAccessToken -TenantId $TenantId -ResourceUrl "https://management.azure.com").Token
    if (-not $token) {
        throw "Could not acquire access token"
    }
}
catch {
    Write-Error "Failed to get access token: $($_.Exception.Message)"
    exit 1
}

# 3. Build resource ID (two common ways — both should work)
$resourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$FunctionAppName"

# Alternative (if you prefer using Get-AzWebApp):
# $app = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $FunctionAppName -ErrorAction SilentlyContinue
# if ($app) { $resourceId = $app.Id }

$apiVersion = "2024-04-01"
$uri = "https://management.azure.com$resourceId?api-version=$apiVersion"

# ───────────────────────────────────────────────
#   STOP the Function App
# ───────────────────────────────────────────────
Write-Host "`nSTOPPING Function App..." -ForegroundColor Cyan
Write-Host "Time: $([DateTime]::UtcNow -as [string]) UTC"

$stopBody = @{
    properties = @{
        state             = "Stopped"
        scmSiteAlsoStopped = $true
    }
} | ConvertTo-Json -Depth 5 -Compress

try {
    $response = Invoke-RestMethod -Uri $uri `
        -Method PATCH `
        -Headers @{ 
            Authorization  = "Bearer $token"
            'Content-Type' = 'application/json'
        } `
        -Body $stopBody `
        -ErrorAction Stop

    Write-Host "Stop request accepted" -ForegroundColor Green
}
catch {
    Write-Error "Failed to stop Function App: $($_.Exception.Message)"
    Write-Error $_.Exception.Response.Content
    exit 1
}

# Give Azure some time to actually stop the app
Start-Sleep -Seconds 30

# ───────────────────────────────────────────────
#   START the Function App again
# ───────────────────────────────────────────────
Write-Host "`nSTARTING Function App..." -ForegroundColor Cyan
Write-Host "Time: $([DateTime]::UtcNow -as [string]) UTC"

$startBody = @{
    properties = @{
        state             = "Running"
        scmSiteAlsoStopped = $false
    }
} | ConvertTo-Json -Depth 5 -Compress

try {
    $response = Invoke-RestMethod -Uri $uri `
        -Method PATCH `
        -Headers @{ 
            Authorization  = "Bearer $token"
            'Content-Type' = 'application/json'
        } `
        -Body $startBody `
        -ErrorAction Stop

    Write-Host "Start request accepted" -ForegroundColor Green
}
catch {
    Write-Error "Failed to start Function App: $($_.Exception.Message)"
    exit 1
}

Write-Host "`nRestart sequence completed" -ForegroundColor Green
Write-Host "Final time: $([DateTime]::UtcNow -as [string]) UTC"
Write-Host "DONE" -ForegroundColor Magenta
