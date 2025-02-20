# Demo-HaloClientScenario.ps1
# This script demonstrates a complete use case scenario of connecting to the Halo API
# and retrieving client information.

# Import required scripts
. "./Connect-To-HaloAPI.ps1"
. "./Get-HaloClientInfo.ps1"

# Example configuration - Replace these with actual values
$config = @{
    URL = "https://example.halopsa.com"
    ClientID = "your-client-id"
    ClientSecret = "your-client-secret"
    Tenant = "your-tenant-name" # Optional
}

try {
    # Step 1: Connect to the Halo API
    Write-Host "`n=== Connecting to Halo API ===" -ForegroundColor Cyan
    Connect-To-HaloAPI -URL $config.URL -ClientID $config.ClientID -ClientSecret $config.ClientSecret -Tenant $config.Tenant

    # Step 2: Demonstrate different client retrieval scenarios
    Write-Host "`n=== Demonstrating Client Retrieval Scenarios ===" -ForegroundColor Cyan

    # Scenario 1: Get a specific client by ID
    Write-Host "`nScenario 1: Retrieving a specific client" -ForegroundColor Yellow
    Write-Host "Getting client with ID 1..."
    $client = Get-HaloClientInfo -ClientID 1 -IncludeDetails
    Write-Host "Client details:"
    $client | Format-List

    # Scenario 2: Search for clients
    Write-Host "`nScenario 2: Searching for clients" -ForegroundColor Yellow
    Write-Host "Searching for clients with 'Tech' in their name..."
    $searchResults = Get-HaloClientInfo -Search "Tech"
    Write-Host "Found $($searchResults.Count) clients:"
    $searchResults | Format-Table -AutoSize

    # Scenario 3: Paginated client list
    Write-Host "`nScenario 3: Retrieving paginated client list" -ForegroundColor Yellow
    Write-Host "Getting first page of clients (10 per page)..."
    $paginatedClients = Get-HaloClientInfo -Paginate -PageSize 10 -PageNo 1
    Write-Host "First page of clients:"
    $paginatedClients | Format-Table -AutoSize

} catch {
    Write-Error "An error occurred during the demo: $_"
    exit 1
} finally {
    Write-Host "`n=== Demo Complete ===" -ForegroundColor Cyan
}

<#
.SYNOPSIS
    Demonstrates various scenarios for working with the Halo API and client information.

.DESCRIPTION
    This script showcases three main scenarios:
    1. Retrieving a specific client by ID with detailed information
    2. Searching for clients using a search term
    3. Retrieving a paginated list of clients

.NOTES
    Before running this script:
    1. Ensure you have the HaloAPI module installed
    2. Update the $config hashtable with your actual Halo API credentials
    3. Ensure Connect-To-HaloAPI.ps1 and Get-HaloClientInfo.ps1 are in the same directory

.EXAMPLE
    ./Demo-HaloClientScenario.ps1
    Runs the complete demo scenario
#>
