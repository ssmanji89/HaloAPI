# Process-HaloWorkflows.ps1
# This script demonstrates complex business workflows integrating tickets, assets, and clients.
# It includes automated ticket creation based on asset status, client contract validation,
# and workflow automation for common business processes.

param(
    [Parameter(Mandatory = $false)]
    [Int32]$ClientID,
    
    [Parameter(Mandatory = $false)]
    [Int32[]]$AssetTypes,
    
    [Parameter(Mandatory = $false)]
    [Switch]$CreateMaintenanceTickets,
    
    [Parameter(Mandatory = $false)]
    [Switch]$ValidateContracts,
    
    [Parameter(Mandatory = $false)]
    [Int32]$DefaultAgentID,
    
    [Parameter(Mandatory = $false)]
    [Int32]$DefaultTeamID
)

# Import required scripts
. "./Connect-To-HaloAPI.ps1"

function Get-MaintenanceRequirements {
    param (
        [Parameter(Mandatory = $true)]
        [Object[]]$Assets
    )
    
    $requirements = @{
        Immediate = @()
        Upcoming = @()
        Current = @()
    }
    
    $today = Get-Date
    foreach ($asset in $Assets) {
        # Check last maintenance date
        if ($asset.custom_fields -and $asset.custom_fields.last_maintenance) {
            $lastMaintenance = [DateTime]$asset.custom_fields.last_maintenance
            $daysSinceLastMaintenance = ($today - $lastMaintenance).Days
            
            # Categorize based on maintenance schedule
            switch ($daysSinceLastMaintenance) {
                { $_ -gt 180 } { 
                    $requirements.Immediate += @{
                        Asset = $asset
                        DaysOverdue = $_
                        Priority = 1  # High priority
                    }
                    break
                }
                { $_ -gt 150 } { 
                    $requirements.Upcoming += @{
                        Asset = $asset
                        DaysUntilDue = 180 - $_
                        Priority = 2  # Medium priority
                    }
                    break
                }
                default {
                    $requirements.Current += @{
                        Asset = $asset
                        DaysUntilDue = 180 - $_
                        Priority = 3  # Low priority
                    }
                }
            }
        }
        else {
            # No maintenance record found
            $requirements.Immediate += @{
                Asset = $asset
                DaysOverdue = 999  # High number to indicate unknown
                Priority = 1  # High priority
            }
        }
    }
    
    return $requirements
}

function Get-ContractStatus {
    param (
        [Parameter(Mandatory = $true)]
        [Int32]$ClientID
    )
    
    $contracts = Get-HaloContract -ClientID $ClientID
    $today = Get-Date
    $client = Get-HaloClient -ClientID $ClientID
    
    $status = @{
        Active = @()
        Expiring = @()
        Expired = @()
        Coverage = @{}
        UncoveredAssets = @()
        RenewalValue = 0
        ClientInfo = $client
        ContractSummary = @{
            TotalValue = 0
            ExpiringValue = 0
            RenewalPriority = "Low"
            RecommendedAction = "Monitor"
        }
    }
    
    # Get all client assets for coverage analysis
    $allAssets = Get-HaloAsset -ClientID $ClientID -FullObjects
    $assetsByType = $allAssets | Group-Object -Property type
    
    foreach ($contract in $contracts) {
        if ($contract.end_date) {
            $endDate = [DateTime]$contract.end_date
            $daysUntilExpiry = ($endDate - $today).Days
            $contractValue = if ($contract.value) { $contract.value } else { 0 }
            $status.ContractSummary.TotalValue += $contractValue
            
            # Enhanced contract categorization
            $contractInfo = @{
                Contract = $contract
                DaysUntilExpiry = $daysUntilExpiry
                Value = $contractValue
                CoveredAssets = @()
                CoverageGaps = @()
                RenewalRisk = "Low"
            }
            
            if ($daysUntilExpiry -lt 0) {
                $contractInfo.RenewalRisk = "Critical"
                $status.Expired += $contractInfo
                $status.ContractSummary.RenewalPriority = "Critical"
                $status.ContractSummary.RecommendedAction = "Immediate Renewal Required"
            }
            elseif ($daysUntilExpiry -lt 30) {
                $contractInfo.RenewalRisk = "High"
                $status.Expiring += $contractInfo
                $status.ContractSummary.ExpiringValue += $contractValue
                if ($status.ContractSummary.RenewalPriority -ne "Critical") {
                    $status.ContractSummary.RenewalPriority = "High"
                    $status.ContractSummary.RecommendedAction = "Schedule Renewal Discussion"
                }
            }
            else {
                $status.Active += $contractInfo
            }
            
            # Enhanced coverage mapping
            foreach ($item in $contract.items) {
                $status.Coverage[$item.type] = @{
                    Contract = $contract
                    ExpiryDate = $endDate
                    DaysRemaining = $daysUntilExpiry
                    AssetsAffected = ($assetsByType | Where-Object { $_.Name -eq $item.type }).Count
                }
                
                # Track covered assets
                $coveredAssets = $allAssets | Where-Object { $_.type -eq $item.type }
                $contractInfo.CoveredAssets += $coveredAssets
            }
        }
    }
    
    # Identify uncovered assets
    $coveredTypes = $status.Coverage.Keys
    $uncoveredAssets = $allAssets | Where-Object { $_.type -notin $coveredTypes }
    $status.UncoveredAssets = $uncoveredAssets | Group-Object -Property type | ForEach-Object {
        @{
            AssetType = $_.Name
            Count = $_.Count
            Assets = $_.Group
            EstimatedValue = ($_.Group | Measure-Object -Property value -Sum).Sum
        }
    }
    
    # Calculate renewal value and priority
    $status.RenewalValue = $status.ContractSummary.ExpiringValue
    if ($status.UncoveredAssets) {
        $status.ContractSummary.RecommendedAction += "`nConsider coverage for $(($status.UncoveredAssets | Measure-Object).Count) uncovered asset types"
    }
    
    return $status
}

function New-MaintenanceTicket {
    param (
        [Parameter(Mandatory = $true)]
        [Object]$Asset,
        
        [Parameter(Mandatory = $true)]
        [Int32]$Priority,
        
        [Parameter(Mandatory = $false)]
        [Int32]$AgentID,
        
        [Parameter(Mandatory = $false)]
        [Int32]$TeamID
    )
    
    $ticketParams = @{
        Summary = "Scheduled Maintenance Required - $($Asset.name)"
        Details = @"
Asset Details:
- Name: $($Asset.name)
- Type: $($Asset.type)
- Location: $($Asset.site_name)
- Last Maintenance: $($Asset.custom_fields.last_maintenance)

Maintenance Requirements:
1. Physical inspection
2. Performance testing
3. Software updates
4. Security compliance check
5. Documentation update
"@
        ClientID = $Asset.client_id
        SiteID = $Asset.site_id
        Priority = $Priority
        AssetID = $Asset.id
    }
    
    if ($AgentID) {
        $ticketParams.Add("AgentID", $AgentID)
    }
    
    if ($TeamID) {
        $ticketParams.Add("TeamID", $TeamID)
    }
    
    try {
        $ticket = New-HaloTicket @ticketParams
        Write-Host "Created maintenance ticket $($ticket.id) for asset $($Asset.name)" -ForegroundColor Green
        return $ticket
    }
    catch {
        Write-Error "Failed to create maintenance ticket for asset $($Asset.name): $_"
        return $null
    }
}

function Update-AssetContractStatus {
    param (
        [Parameter(Mandatory = $true)]
        [Object[]]$Assets,
        
        [Parameter(Mandatory = $true)]
        [Hashtable]$ContractStatus
    )
    
    $updateSummary = @{
        Updated = 0
        Failed = 0
        CoverageChanges = @()
        RiskAssessment = @{
            HighRisk = @()
            MediumRisk = @()
            LowRisk = @()
        }
    }
    
    foreach ($asset in $Assets) {
        $covered = $false
        $contractInfo = ""
        $riskLevel = "High"  # Default to high risk if not covered
        
        # Check if asset type is covered by any contract
        if ($ContractStatus.Coverage[$asset.type]) {
            $coverage = $ContractStatus.Coverage[$asset.type]
            $covered = $true
            $contractInfo = "Covered by contract #$($coverage.Contract.id) until $($coverage.ExpiryDate)"
            
            # Assess risk based on contract status and asset value
            switch ($coverage.DaysRemaining) {
                { $_ -lt 0 } { $riskLevel = "High" }
                { $_ -lt 30 } { $riskLevel = "Medium" }
                default { $riskLevel = "Low" }
            }
            
            # Add asset value consideration
            if ($asset.value -gt 10000) {  # High-value asset threshold
                $riskLevel = if ($riskLevel -eq "Low") { "Medium" } else { "High" }
            }
        }
        else {
            $contractInfo = "No active contract coverage - ATTENTION REQUIRED"
            $updateSummary.CoverageChanges += @{
                Asset = $asset
                Status = "Uncovered"
                RecommendedAction = "Evaluate coverage requirements"
                Priority = if ($asset.value -gt 10000) { "High" } else { "Medium" }
            }
        }
        
        try {
            # Update asset custom fields with enhanced contract information
            Set-HaloAsset -AssetID $asset.id -CustomFields @{
                contract_status = $contractInfo
                is_covered = $covered
                last_contract_check = (Get-Date).ToString("yyyy-MM-dd")
                coverage_risk_level = $riskLevel
                next_review_date = if ($covered) { 
                    $ContractStatus.Coverage[$asset.type].ExpiryDate.AddDays(-30).ToString("yyyy-MM-dd")
                } else {
                    (Get-Date).AddDays(7).ToString("yyyy-MM-dd")  # Urgent review for uncovered assets
                }
            }
            
            $updateSummary.Updated++
            
            # Track risk levels
            switch ($riskLevel) {
                "High" { $updateSummary.RiskAssessment.HighRisk += $asset }
                "Medium" { $updateSummary.RiskAssessment.MediumRisk += $asset }
                "Low" { $updateSummary.RiskAssessment.LowRisk += $asset }
            }
            
            Write-Host "Updated contract status for asset $($asset.name) - Risk Level: $riskLevel" -ForegroundColor $(
                switch ($riskLevel) {
                    "High" { "Red" }
                    "Medium" { "Yellow" }
                    "Low" { "Green" }
                }
            )
        }
        catch {
            Write-Error "Failed to update contract status for asset $($asset.name): $_"
            $updateSummary.Failed++
        }
    }
    
    return $updateSummary
}

# Main script execution
try {
    Write-Host "`n=== Starting Workflow Processing ===" -ForegroundColor Cyan
    
    # Get assets for the specified client
    Write-Host "`nRetrieving assets..." -ForegroundColor Yellow
    $assetParams = @{
        FullObjects = $true
    }
    
    if ($ClientID) {
        $assetParams.Add("ClientID", $ClientID)
    }
    
    $assets = Get-HaloAsset @assetParams
    
    if ($AssetTypes) {
        $assets = $assets | Where-Object { $_.type -in $AssetTypes }
    }
    
    if (-not $assets) {
        Write-Host "No assets found for the specified criteria." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "Found $($assets.Count) assets to process." -ForegroundColor Green
    
    # Process maintenance requirements
    if ($CreateMaintenanceTickets) {
        Write-Host "`n=== Processing Maintenance Requirements ===" -ForegroundColor Cyan
        $maintenance = Get-MaintenanceRequirements -Assets $assets
        
        # Create tickets for immediate maintenance
        if ($maintenance.Immediate) {
            Write-Host "`nCreating tickets for $($maintenance.Immediate.Count) assets requiring immediate maintenance..."
            foreach ($item in $maintenance.Immediate) {
                New-MaintenanceTicket -Asset $item.Asset -Priority $item.Priority -AgentID $DefaultAgentID -TeamID $DefaultTeamID
            }
        }
        
        # Report on upcoming maintenance
        if ($maintenance.Upcoming) {
            Write-Host "`nAssets requiring maintenance soon: $($maintenance.Upcoming.Count)" -ForegroundColor Yellow
            foreach ($item in $maintenance.Upcoming) {
                Write-Host "$($item.Asset.name) - Due in $($item.DaysUntilDue) days"
            }
        }
    }
    
    # Validate contract coverage
    if ($ValidateContracts -and $ClientID) {
        Write-Host "`n=== Validating Contract Coverage ===" -ForegroundColor Cyan
        $contractStatus = Get-ContractStatus -ClientID $ClientID
        
        # Enhanced contract status reporting
        Write-Host "`n=== Contract Analysis Summary ===" -ForegroundColor Cyan
        Write-Host "`nClient: $($contractStatus.ClientInfo.name)"
        Write-Host "Total Contract Value: $($contractStatus.ContractSummary.TotalValue)"
        Write-Host "Expiring Contract Value: $($contractStatus.ContractSummary.ExpiringValue)"
        Write-Host "Renewal Priority: $($contractStatus.ContractSummary.RenewalPriority)" -ForegroundColor $(
            switch ($contractStatus.ContractSummary.RenewalPriority) {
                "Critical" { "Red" }
                "High" { "Yellow" }
                default { "Green" }
            }
        )
        
        Write-Host "`nContract Status Breakdown:"
        Write-Host "Active Contracts: $($contractStatus.Active.Count)" -ForegroundColor Green
        Write-Host "Expiring Soon: $($contractStatus.Expiring.Count)" -ForegroundColor Yellow
        Write-Host "Expired: $($contractStatus.Expired.Count)" -ForegroundColor Red
        
        # Report on uncovered assets
        if ($contractStatus.UncoveredAssets) {
            Write-Host "`n!!! ATTENTION: Uncovered Assets !!!" -ForegroundColor Red
            foreach ($uncovered in $contractStatus.UncoveredAssets) {
                Write-Host "Type: $($uncovered.AssetType) - Count: $($uncovered.Count) - Est. Value: $($uncovered.EstimatedValue)"
            }
        }
        
        Write-Host "`nRecommended Actions:" -ForegroundColor Cyan
        Write-Host $contractStatus.ContractSummary.RecommendedAction
        
        # Update assets with enhanced contract information
        Write-Host "`n=== Updating Asset Contract Status ===" -ForegroundColor Cyan
        $updateSummary = Update-AssetContractStatus -Assets $assets -ContractStatus $contractStatus
        
        # Report on update results
        Write-Host "`nUpdate Summary:"
        Write-Host "Successfully Updated: $($updateSummary.Updated)" -ForegroundColor Green
        Write-Host "Failed Updates: $($updateSummary.Failed)" -ForegroundColor Red
        
        Write-Host "`nRisk Assessment:"
        Write-Host "High Risk Assets: $($updateSummary.RiskAssessment.HighRisk.Count)" -ForegroundColor Red
        Write-Host "Medium Risk Assets: $($updateSummary.RiskAssessment.MediumRisk.Count)" -ForegroundColor Yellow
        Write-Host "Low Risk Assets: $($updateSummary.RiskAssessment.LowRisk.Count)" -ForegroundColor Green
        
        if ($updateSummary.CoverageChanges) {
            Write-Host "`nCoverage Changes Requiring Attention:" -ForegroundColor Yellow
            foreach ($change in $updateSummary.CoverageChanges) {
                Write-Host "Asset: $($change.Asset.name) - $($change.Status)" -ForegroundColor $(
                    if ($change.Priority -eq "High") { "Red" } else { "Yellow" }
                )
                Write-Host "Recommended Action: $($change.RecommendedAction)"
            }
        }
        
        # Create alerts for expiring contracts
        if ($contractStatus.Expiring) {
            Write-Host "`nCreating alerts for expiring contracts..." -ForegroundColor Yellow
            foreach ($contract in $contractStatus.Expiring) {
                $ticketParams = @{
                    Summary = "Contract Expiring Soon - #$($contract.id)"
                    Details = @"
Contract #$($contract.id) is expiring on $($contract.end_date)

Covered Items:
$($contract.items | ForEach-Object { "- $_" } | Out-String)

Action Required:
1. Review contract terms
2. Contact client for renewal
3. Update coverage details
"@
                    ClientID = $ClientID
                    Priority = 2  # Medium priority
                }
                
                if ($DefaultAgentID) {
                    $ticketParams.Add("AgentID", $DefaultAgentID)
                }
                
                try {
                    $ticket = New-HaloTicket @ticketParams
                    Write-Host "Created contract expiry alert ticket: $($ticket.id)" -ForegroundColor Green
                }
                catch {
                    Write-Error "Failed to create contract expiry alert: $_"
                }
            }
        }
    }
}
catch {
    Write-Error "An error occurred during workflow processing: $_"
    exit 1
}
finally {
    Write-Host "`n=== Workflow Processing Complete ===" -ForegroundColor Cyan
}

<#
.SYNOPSIS
    Complex workflow automation script integrating tickets, assets, and contracts.

.DESCRIPTION
    This script demonstrates advanced business process automation including:
    - Automated maintenance ticket creation based on asset status
    - Contract validation and coverage tracking
    - Integration between assets, tickets, and contracts
    - Automated alerts for contract expiration

.PARAMETER ClientID
    Optional. Process workflows for a specific client.

.PARAMETER AssetTypes
    Optional. Array of asset types to include in processing.

.PARAMETER CreateMaintenanceTickets
    Switch to enable automatic maintenance ticket creation.

.PARAMETER ValidateContracts
    Switch to enable contract validation and tracking.

.PARAMETER DefaultAgentID
    Default agent ID for created tickets.

.PARAMETER DefaultTeamID
    Default team ID for created tickets.

.EXAMPLE
    ./Process-HaloWorkflows.ps1 -ClientID 123 -CreateMaintenanceTickets -ValidateContracts -DefaultAgentID 1

.NOTES
    This script requires:
    1. Active connection to Halo API (use Connect-To-HaloAPI.ps1 first)
    2. Appropriate permissions for ticket, asset, and contract management
    3. Valid agent and team IDs if specified
#>
