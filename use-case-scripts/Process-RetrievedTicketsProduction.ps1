<#
.SYNOPSIS
   Production-ready script to retrieve, filter, triage, and update tickets with iterative enhancements.
.DESCRIPTION
   This script enhances earlier implementations by:
   - Retrieving tickets using the Get-HaloTicket cmdlet with pagination support.
   - Filtering tickets based on a provided Ticket ID regex pattern.
   - For each matching ticket, it invokes the triage workflow (Process-TicketTriageWorkflow.ps1) to generate actionable next steps using the GPT-4O model, and simulates updating the ticket.
   - Implements robust logging, processing metrics, and an optional retry mechanism for failed ticket processing.
   - At the end, outputs summary statistics of the processing run.
.PARAMETER TicketFilter
   A regex pattern to filter Ticket IDs. Only tickets whose IDs match this pattern will be processed.
.PARAMETER PageSize
   Optional. The number of tickets to retrieve per page. Default is 100.
.PARAMETER MaxRetries
   Optional. The maximum number of times to retry processing a ticket if an error occurs. Default is 0 (no retries).
.EXAMPLE
   .\Process-RetrievedTicketsProduction.ps1 -TicketFilter "^TICKET-.*" -PageSize 100 -MaxRetries 2
.NOTES
   Ensure that the PSOpenAI module is installed and the OPENAI_API_KEY environment variable is set.
   The Get-HaloTicket cmdlet must be available and configured to retrieve ticket data.
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$TicketFilter,
    
    [Parameter(Mandatory=$false)]
    [int]$PageSize = 100,
    
    [Parameter(Mandatory=$false)]
    [int]$MaxRetries = 0
)

# Setup logging
$LogDir = Join-Path -Path $PSScriptRoot -ChildPath "logs"
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory | Out-Null
}
$LogFile = Join-Path -Path $LogDir -ChildPath ("TicketProcessing_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "$timestamp - $Message"
    Write-Output $logLine
    Add-Content -Path $LogFile -Value $logLine
}

Write-Log "Production ticket processing started."
$totalTicketsRetrieved = 0
$allTickets = @()
$pageNo = 1

# Retrieve tickets using pagination
while ($true) {
    Write-Log "Retrieving page $pageNo with page size $PageSize..."
    try {
        # Retrieve tickets using Get-HaloTicket. Adjust parameters as needed.
        $ticketsPage = Get-HaloTicket -open_only $true -page_no $pageNo -page_size $PageSize -ticketidonly $true
    }
    catch {
        Write-Log "Error retrieving tickets on page $pageNo: $_"
        break
    }
    
    if (-not $ticketsPage -or $ticketsPage.Count -eq 0) {
        Write-Log "No more tickets returned on page $pageNo. Ending pagination."
        break
    }
    
    Write-Log "Retrieved $($ticketsPage.Count) tickets on page $pageNo."
    $allTickets += $ticketsPage
    $totalTicketsRetrieved += $ticketsPage.Count
    if ($ticketsPage.Count -lt $PageSize) { break }
    $pageNo++
}

if (-not $allTickets -or $allTickets.Count -eq 0) {
    Write-Log "No tickets were retrieved."
    exit 0
}

Write-Log "Total tickets retrieved: $totalTicketsRetrieved"

# Filter tickets based on the provided TicketFilter regex on the TicketId property.
$filteredTickets = $allTickets | Where-Object { $_.TicketId -match $TicketFilter }

if ($filteredTickets.Count -eq 0) {
    Write-Log "No tickets matched the filter '$TicketFilter'."
    exit 0
}

Write-Log "Processing the following tickets matching filter '$TicketFilter':"
$filteredTickets | ForEach-Object { Write-Log "Ticket ID: $($_.TicketId)" }

# Resolve the workflow script path (Process-TicketTriageWorkflow.ps1 must exist in the same directory)
$workflowScript = Join-Path -Path $PSScriptRoot -ChildPath "Process-TicketTriageWorkflow.ps1"

# Processing counters
$processedCount = 0
$successCount = 0
$errorCount = 0
$failedTickets = @()

# Process each filtered ticket with retry mechanism
foreach ($ticket in $filteredTickets) {
    Write-Log "---------------------------------------"
    Write-Log "Processing Ticket ID: $($ticket.TicketId)"
    
    # Prepare ticket description.
    $ticketDescription = $ticket.Summary
    if (-not $ticketDescription) {
        $ticketDescription = "No detailed description available for ticket $($ticket.TicketId)."
    }
    
    Write-Log "Using Ticket Description: $ticketDescription"
    
    $attempt = 0
    $processed = $false
    do {
        try {
            $attempt++
            Write-Log "Attempt $attempt for ticket $($ticket.TicketId)."
            $output = & $workflowScript -TicketId $ticket.TicketId -TicketDescription $ticketDescription 2>&1
            Write-Log "Triage output for $($ticket.TicketId): $output"
            $processed = $true
        }
        catch {
            Write-Log "Error processing ticket $($ticket.TicketId) on attempt $attempt: $_"
            Start-Sleep -Seconds 2
        }
    }
    while (-not $processed -and $attempt -le $MaxRetries)
    
    if ($processed) {
        $successCount++
    }
    else {
        $errorCount++
        $failedTickets += $ticket.TicketId
    }
    $processedCount++
}

# Log summary statistics
Write-Log "---------------------------------------"
Write-Log "Processing Summary:"
Write-Log "Total tickets processed: $processedCount"
Write-Log "Successful processing: $successCount"
Write-Log "Failed processing: $errorCount"
if ($failedTickets.Count -gt 0) {
    Write-Log "Failed Ticket IDs: $($failedTickets -join ', ')"
}
Write-Log "Production ticket processing completed."
