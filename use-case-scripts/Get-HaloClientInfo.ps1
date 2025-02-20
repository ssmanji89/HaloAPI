# Get-HaloClientInfo.ps1
# This script demonstrates how to retrieve client information from the Halo API.

# Parameters
param(
    [Parameter(Mandatory = $false)]
    [Int64]$ClientID,
    
    [Parameter(Mandatory = $false)]
    [String]$Search,
    
    [Parameter(Mandatory = $false)]
    [Switch]$Paginate,
    
    [Parameter(Mandatory = $false)]
    [Int32]$PageSize = 50,
    
    [Parameter(Mandatory = $false)]
    [Int32]$PageNo = 1,
    
    [Parameter(Mandatory = $false)]
    [Switch]$IncludeDetails,
    
    [Parameter(Mandatory = $false)]
    [Switch]$IncludeActivity
)

try {
    # If a specific ClientID is provided, get that client
    if ($ClientID) {
        Write-Host "Retrieving client with ID: $ClientID..."
        
        $params = @{
            ClientID = $ClientID
        }
        
        if ($IncludeDetails) {
            $params.Add("IncludeDetails", $true)
        }
        
        if ($IncludeActivity) {
            $params.Add("IncludeActivity", $true)
        }
        
        $client = Get-HaloClient @params
        return $client
    }
    # Otherwise, search for clients based on provided parameters
    else {
        Write-Host "Searching for clients..."
        
        $params = @{}
        
        if ($Search) {
            $params.Add("Search", $Search)
            Write-Host "Using search term: $Search"
        }
        
        if ($Paginate) {
            $params.Add("Paginate", $true)
            $params.Add("PageSize", $PageSize)
            $params.Add("PageNo", $PageNo)
            Write-Host "Using pagination: Page $PageNo, $PageSize items per page"
        }
        
        $clients = Get-HaloClient @params
        return $clients
    }
    
} catch {
    Write-Error "Failed to retrieve client information: $_"
    exit 1
}
