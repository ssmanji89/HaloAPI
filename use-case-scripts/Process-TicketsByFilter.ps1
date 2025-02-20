<#
.SYNOPSIS
   Recursively processes and triages multiple tickets based on a Ticket ID filter.
.DESCRIPTION
   This script simulates retrieving a list of tickets and recursively processes each ticket whose Ticket ID matches the provided filter.
   For each matching ticket, it calls the triage workflow (Process-TicketTriageWorkflow.ps1) to generate actionable next steps using the GPT-4O model and update the ticket.
   In a real-world scenario, the ticket list might be retrieved from a database or an API. Here, a simulated in-memory list is used.
.PARAMETER TicketFilter
   A regex pattern to filter Ticket IDs. Only tickets whose IDs match this pattern will be processed.
.EXAMPLE
   .\Process-TicketsByFilter.ps1 -TicketFilter "^TICKET-.*"
.NOTES
   Ensure that the PSOpenAI module is installed and that the OPENAI_API_KEY environment variable is set.
   This script relies on the Process-TicketTriageWorkflow.ps1 script for the triage workflow.
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$TicketFilter
)

# Simulated list of tickets
$tickets = @(
    [PSCustomObject]@{ TicketId = "TICKET-101"; TicketDescription = "User unable to login due to authentication error." },
    [PSCustomObject]@{ TicketId = "TICKET-102"; TicketDescription = "Email service is down affecting all users." },
    [PSCustomObject]@{ TicketId = "INC-103"; TicketDescription = "Printer not responding on floor 3." },
    [PSCustomObject]@{ TicketId = "TICKET-104"; TicketDescription = "Network slowdown in building A." },
    [PSCustomObject]@{ TicketId = "SR-105"; TicketDescription = "Request for new workstation setup." }
)

# Filter tickets based on the provided TicketFilter pattern (regex match)
$filteredTickets = $tickets | Where-Object { $_.TicketId -match $TicketFilter }

if ($filteredTickets.Count -eq 0) {
    Write-Output "No tickets matched the filter '$TicketFilter'."
    exit 0
}

Write-Output "Processing the following tickets matching filter '$TicketFilter':"
$filteredTickets | ForEach-Object { Write-Output $_.TicketId }

# Recursively process each filtered ticket
foreach ($ticket in $filteredTickets) {
    Write-Output "---------------------------------------"
    Write-Output "Processing Ticket ID: $($ticket.TicketId)"
    
    # Invoke the triage workflow script for the current ticket
    $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Process-TicketTriageWorkflow.ps1"
    
    # Call the workflow script and capture the output
    try {
        $output = & $scriptPath -TicketId $ticket.TicketId -TicketDescription $ticket.TicketDescription
        Write-Output "Triage Output for $($ticket.TicketId):"
        Write-Output $output
    } catch {
        Write-Error "Error processing ticket $($ticket.TicketId): $_"
    }
}
