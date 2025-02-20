# Analyze-HaloAssets.ps1
# This script demonstrates complex asset management and reporting scenarios in Halo PSA.
# It includes warranty tracking, software license compliance, and asset lifecycle management.

param(
    [Parameter(Mandatory = $false)]
    [Int32]$ClientID,
    
    [Parameter(Mandatory = $false)]
    [Int32[]]$SiteIDs,
    
    [Parameter(Mandatory = $false)]
    [Switch]$IncludeWarrantyAlerts,
    
    [Parameter(Mandatory = $false)]
    [Switch]$CheckSoftwareLicenses,
    
    [Parameter(Mandatory = $false)]
    [Int32]$WarningDays = 30,
    
    [Parameter(Mandatory = $false)]
    [String]$ReportPath = "AssetReport.csv"
)

# Import required scripts
. "./Connect-To-HaloAPI.ps1"

function Get-AssetsByClient {
    param (
        [Parameter(Mandatory = $false)]
        [Int32]$ClientID,
        
        [Parameter(Mandatory = $false)]
        [Int32[]]$SiteIDs
    )
    
    $params = @{
        FullObjects = $true
    }
    
    if ($ClientID) {
        $params.Add("ClientID", $ClientID)
    }
    
    $assets = Get-HaloAsset @params
    
    if ($SiteIDs) {
        $assets = $assets | Where-Object { $_.site_id -in $SiteIDs }
    }
    
    return $assets
}

function Get-WarrantyStatus {
    param (
        [Parameter(Mandatory = $true)]
        [Object[]]$Assets,
        
        [Parameter(Mandatory = $true)]
        [Int32]$WarningDays
    )
    
    $today = Get-Date
    $warningDate = $today.AddDays($WarningDays)
    
    $warrantyStatus = @{
        Expired = @()
        ExpiringSoon = @()
        Valid = @()
        Unknown = @()
    }
    
    foreach ($asset in $Assets) {
        if (-not $asset.warranty_end) {
            $warrantyStatus.Unknown += $asset
            continue
        }
        
        $warrantyEnd = [DateTime]$asset.warranty_end
        
        if ($warrantyEnd -lt $today) {
            $warrantyStatus.Expired += $asset
        }
        elseif ($warrantyEnd -lt $warningDate) {
            $warrantyStatus.ExpiringSoon += $asset
        }
        else {
            $warrantyStatus.Valid += $asset
        }
    }
    
    return $warrantyStatus
}

function Get-SoftwareLicenseStatus {
    param (
        [Parameter(Mandatory = $true)]
        [Int32]$ClientID
    )
    
    $licenses = Get-HaloSoftwareLicence -ClientID $ClientID
    $installedSoftware = Get-HaloAsset -ClientID $ClientID | 
        Where-Object { $_.software_installations } |
        Select-Object -ExpandProperty software_installations
    
    $licenseStatus = @{}
    
    foreach ($license in $licenses) {
        $softwareName = $license.software_name
        $installed = ($installedSoftware | Where-Object { $_.name -eq $softwareName }).Count
        
        $licenseStatus[$softwareName] = @{
            Licensed = $license.quantity
            Installed = $installed
            Compliance = if ($installed -le $license.quantity) { "Compliant" } else { "Non-Compliant" }
            Difference = $license.quantity - $installed
        }
    }
    
    return $licenseStatus
}

function Get-AssetAgeAnalysis {
    param (
        [Parameter(Mandatory = $true)]
        [Object[]]$Assets
    )
    
    $today = Get-Date
    $ageGroups = @{
        "0-1 Year" = 0
        "1-2 Years" = 0
        "2-3 Years" = 0
        "3-4 Years" = 0
        "4-5 Years" = 0
        "5+ Years" = 0
        "Unknown" = 0
    }
    
    foreach ($asset in $Assets) {
        if (-not $asset.purchase_date) {
            $ageGroups["Unknown"]++
            continue
        }
        
        $age = ($today - [DateTime]$asset.purchase_date).TotalDays / 365
        
        switch ($age) {
            { $_ -lt 1 } { $ageGroups["0-1 Year"]++; break }
            { $_ -lt 2 } { $ageGroups["1-2 Years"]++; break }
            { $_ -lt 3 } { $ageGroups["2-3 Years"]++; break }
            { $_ -lt 4 } { $ageGroups["3-4 Years"]++; break }
            { $_ -lt 5 } { $ageGroups["4-5 Years"]++; break }
            default { $ageGroups["5+ Years"]++ }
        }
    }
    
    return $ageGroups
}

function Export-AssetReport {
    param (
        [Parameter(Mandatory = $true)]
        [Object[]]$Assets,
        
        [Parameter(Mandatory = $true)]
        [String]$ReportPath
    )
    
    $reportData = $Assets | Select-Object `
        id, 
        name, 
        asset_tag, 
        type, 
        status,
        client_name,
        site_name,
        purchase_date,
        warranty_end,
        @{Name="Age(Days)"; Expression={(Get-Date) - [DateTime]$_.purchase_date}},
        last_seen,
        ip_address
    
    $reportData | Export-Csv -Path $ReportPath -NoTypeInformation
    Write-Host "Asset report exported to: $ReportPath"
}

# Main script execution
try {
    Write-Host "`n=== Starting Asset Analysis Process ===" -ForegroundColor Cyan
    
    # Get assets
    Write-Host "`nRetrieving assets..." -ForegroundColor Yellow
    $assets = Get-AssetsByClient -ClientID $ClientID -SiteIDs $SiteIDs
    
    if (-not $assets) {
        Write-Host "No assets found for the specified criteria." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "Found $($assets.Count) assets." -ForegroundColor Green
    
    # Analyze warranty status if requested
    if ($IncludeWarrantyAlerts) {
        Write-Host "`n=== Warranty Status Analysis ===" -ForegroundColor Cyan
        $warrantyStatus = Get-WarrantyStatus -Assets $assets -WarningDays $WarningDays
        
        Write-Host "`nExpired Warranties: $($warrantyStatus.Expired.Count)" -ForegroundColor Red
        Write-Host "Expiring Soon: $($warrantyStatus.ExpiringSoon.Count)" -ForegroundColor Yellow
        Write-Host "Valid Warranties: $($warrantyStatus.Valid.Count)" -ForegroundColor Green
        Write-Host "Unknown Status: $($warrantyStatus.Unknown.Count)" -ForegroundColor Gray
        
        if ($warrantyStatus.Expired -or $warrantyStatus.ExpiringSoon) {
            Write-Host "`nAssets Requiring Attention:" -ForegroundColor Yellow
            $warrantyStatus.Expired | ForEach-Object {
                Write-Host "EXPIRED: $($_.name) - Warranty ended: $($_.warranty_end)" -ForegroundColor Red
            }
            $warrantyStatus.ExpiringSoon | ForEach-Object {
                Write-Host "EXPIRING: $($_.name) - Warranty ends: $($_.warranty_end)" -ForegroundColor Yellow
            }
        }
    }
    
    # Check software license compliance if requested
    if ($CheckSoftwareLicenses -and $ClientID) {
        Write-Host "`n=== Software License Compliance ===" -ForegroundColor Cyan
        $licenseStatus = Get-SoftwareLicenseStatus -ClientID $ClientID
        
        foreach ($software in $licenseStatus.Keys) {
            $status = $licenseStatus[$software]
            $color = if ($status.Compliance -eq "Compliant") { "Green" } else { "Red" }
            
            Write-Host "`nSoftware: $software" -ForegroundColor $color
            Write-Host "Licensed: $($status.Licensed)"
            Write-Host "Installed: $($status.Installed)"
            Write-Host "Status: $($status.Compliance)"
            Write-Host "Difference: $($status.Difference)"
        }
    }
    
    # Analyze asset age distribution
    Write-Host "`n=== Asset Age Distribution ===" -ForegroundColor Cyan
    $ageAnalysis = Get-AssetAgeAnalysis -Assets $assets
    
    foreach ($group in $ageAnalysis.Keys) {
        Write-Host "$group : $($ageAnalysis[$group]) assets"
    }
    
    # Export detailed report
    Write-Host "`n=== Generating Asset Report ===" -ForegroundColor Cyan
    Export-AssetReport -Assets $assets -ReportPath $ReportPath
    
}
catch {
    Write-Error "An error occurred during asset analysis: $_"
    exit 1
}
finally {
    Write-Host "`n=== Asset Analysis Process Complete ===" -ForegroundColor Cyan
}

<#
.SYNOPSIS
    Advanced asset management and analysis script demonstrating complex scenarios.

.DESCRIPTION
    This script provides comprehensive asset management functionality including:
    - Warranty tracking and alerting
    - Software license compliance checking
    - Asset age analysis and reporting
    - Detailed CSV report generation

.PARAMETER ClientID
    Optional. Filter operations to assets for a specific client.

.PARAMETER SiteIDs
    Optional. Array of site IDs to filter assets by location.

.PARAMETER IncludeWarrantyAlerts
    Switch to enable warranty status checking and alerting.

.PARAMETER CheckSoftwareLicenses
    Switch to enable software license compliance checking.

.PARAMETER WarningDays
    Number of days before warranty expiration to trigger warnings. Default is 30 days.

.PARAMETER ReportPath
    Path where the detailed CSV report should be saved. Default is "AssetReport.csv".

.EXAMPLE
    ./Analyze-HaloAssets.ps1 -ClientID 123 -IncludeWarrantyAlerts -CheckSoftwareLicenses
    Analyzes assets for client 123, including warranty and license compliance checks.

.NOTES
    This script requires:
    1. Active connection to Halo API (use Connect-To-HaloAPI.ps1 first)
    2. Appropriate permissions for asset management
    3. Valid client and site IDs if filtering is desired
#>
