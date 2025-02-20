# Connect-To-HaloAPI.ps1
# This script demonstrates how to establish a connection to the Halo API.

# Parameters
param(
    [Parameter(Mandatory = $true)]
    [Uri]$URL,
    
    [Parameter(Mandatory = $true)]
    [String]$ClientID,
    
    [Parameter(Mandatory = $true)]
    [String]$ClientSecret,
    
    [Parameter(Mandatory = $false)]
    [String[]]$Scopes = "all",
    
    [Parameter(Mandatory = $false)]
    [String]$Tenant
)

try {
    Write-Host "Attempting to connect to Halo API at $URL..."
    
    # Build connection parameters
    $connectionParams = @{
        URL = $URL
        ClientID = $ClientID
        ClientSecret = $ClientSecret
        Scopes = $Scopes
    }
    
    # Add tenant if specified
    if ($Tenant) {
        $connectionParams.Add("Tenant", $Tenant)
        Write-Host "Using tenant: $Tenant"
    }
    
    # Attempt connection
    Connect-HaloAPI @connectionParams
    
    Write-Host "Successfully connected to Halo API!" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to connect to Halo API: $_"
    exit 1
}
