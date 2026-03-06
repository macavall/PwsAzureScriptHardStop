<#
.SYNOPSIS
    Stops and then restarts an Azure Function App using the Azure REST API.

.DESCRIPTION
    Temporarily stops a Function App (including SCM site), waits, then starts it again.
    Uses direct REST API call instead of Stop-AzWebApp / Start-AzWebApp.

.PARAMETER SubscriptionId
    Azure Subscription ID

.PARAMETER TenantId
    Azure AD Tenant ID (usually not required if you're already authenticated in the right tenant)

.PARAMETER ResourceGroupName
    Name of the resource group containing the Function App

.PARAMETER FunctionAppName
    Name of the Function App to restart

.PARAMETER WaitSeconds
    How long to keep the app stopped before starting it again (default: 30)

.PARAMETER ApiVersion
    Azure Resource Manager API version to use (default: 2024-04-01)

.EXAMPLE
    Restart-AzFunctionAppWithStop -SubscriptionId "12345678-..." `
                                 -ResourceGroupName "rg-myapp" `
                                 -FunctionAppName "func-myfunction" `
                                 -WaitSeconds 45

.EXAMPLE
    Restart-AzFunctionAppWithStop -sub "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -rg "prod-rg" -func "api-prod"
#>
function Restart-AzFunctionAppWithStop {

    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias("sub")]
        [string] $SubscriptionId,

        [Parameter(Mandatory = $false)]
        [Alias("tenant")]
        [string] $TenantId = "",

        [Parameter(Mandatory = $true)]
        [Alias("rg")]
        [string] $ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [Alias("func", "FunctionName")]
        [string] $FunctionAppName,

        [Parameter(Mandatory = $false)]
        [int] $WaitSeconds = 30,

        [Parameter(Mandatory = $false)]
        [string] $ApiVersion = "2024-04-01"
    )

    begin {
        Write-Verbose "Setting Azure context..."
        $null = Set-AzContext -SubscriptionId $SubscriptionId -TenantId $TenantId -ErrorAction Stop -WarningAction SilentlyContinue

        Write-Verbose "Getting access token..."
        $token = (Get-AzAccessToken -TenantId $TenantId -ErrorAction Stop).Token

        # Build resource ID
        $resourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$FunctionAppName"

        $managementUrl = "https://management.azure.com$resourceId`?api-version=$ApiVersion"

        Write-Host "Target Function App resource ID:" -ForegroundColor Cyan
        Write-Host $resourceId -ForegroundColor White
        Write-Host ""
    }

    process {
        if ($PSCmdlet.ShouldProcess($FunctionAppName, "Stop → wait $WaitSeconds sec → Start")) {

            # ── STOP ────────────────────────────────────────────────
            $stopBody = @{
                properties = @{
                    state              = "Stopped"
                    scmSiteAlsoStopped = $true
                }
            } | ConvertTo-Json -Depth 5 -Compress

            Write-Host "Stopping Function App..." -ForegroundColor Yellow
            Write-Host "UTC: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor DarkGray

            try {
                $null = Invoke-RestMethod -Uri $managementUrl `
                    -Method PATCH `
                    -Body $stopBody `
                    -ContentType "application/json" `
                    -Headers @{ Authorization = "Bearer $token" } `
                    -ErrorAction Stop

                Write-Host "Stop request accepted" -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to stop Function App: $_"
                return
            }

            # ── WAIT ────────────────────────────────────────────────
            Write-Host "Waiting $WaitSeconds seconds..." -ForegroundColor Cyan
            Start-Sleep -Seconds $WaitSeconds

            # ── START ───────────────────────────────────────────────
            $startBody = @{
                properties = @{
                    state              = "Running"
                    scmSiteAlsoStopped = $false
                }
            } | ConvertTo-Json -Depth 5 -Compress

            Write-Host "Starting Function App..." -ForegroundColor Yellow
            Write-Host "UTC: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor DarkGray

            try {
                $null = Invoke-RestMethod -Uri $managementUrl `
                    -Method PATCH `
                    -Body $startBody `
                    -ContentType "application/json" `
                    -Headers @{ Authorization = "Bearer $token" } `
                    -ErrorAction Stop

                Write-Host "Start request accepted" -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to start Function App: $_"
                return
            }

            Write-Host ""
            Write-Host "Restart sequence completed" -ForegroundColor Green
            Write-Host "Function App: $FunctionAppName" -ForegroundColor White
            Write-Host "Done at: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')) UTC" -ForegroundColor Cyan
        }
    }
}
