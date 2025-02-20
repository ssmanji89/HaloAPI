<#
.SYNOPSIS
   Retrieves tickets using the Get-HaloTicket CMDLET, filters them by a Ticket ID pattern, and processes each ticket using the triage workflow.
.DESCRIPTION
   This script calls the Get-HaloTicket CMDLET to retrieve all open tickets (using appropriate parameters) from the Halo Ticket records endpoint.
   It then filters the retrieved tickets based on a provided regex TicketFilter. For each matching ticket, it calls the triage workflow script
   (Process-TicketTriageWorkflow.ps1) to generate actionable next steps using the GPT-4O model and simulate updating the ticket.
.PARAMETER TicketFilter
   A regex pattern used to filter Ticket IDs. Only tickets whose TicketId property matches this pattern will be processed.
.EXAMPLE
   .\Process-RetrievedTicketsByFilter.ps1 -TicketFilter "^TICKET-.*"
.NOTES
   Ensure that the PSOpenAI module is installed and the OPENAI_API_KEY environment variable is set.
   The Get-HaloTicket CMDLET must be available and properly configured to retrieve ticket data.
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$TicketFilter
)

# Retrieve all open tickets using the Get-HaloTicket CMDLET.
# The parameters used here are examples. Adjust according to your environment and requirements.
try {
    Write-Output "Retrieving tickets using Get-HaloTicket..."
    # Example: Retrieve tickets with only ID fields and open tickets only.
    $tickets = Get-HaloTicket -ticketidonly $true -open_only $true
} catch {
    Write-Error "Error retrieving tickets: $_"
    exit 1
}

if (-not $tickets) {
    Write-Output "No tickets were retrieved."
    exit 0
}

Write-Output "Total tickets retrieved: $($tickets.Count)"

# Filter tickets based on the provided TicketFilter regex on the TicketId property.
$filteredTickets = $tickets | Where-Object { $_.TicketId -match $TicketFilter }

if ($filteredTickets.Count -eq 0) {
    Write-Output "No tickets matched the filter '$TicketFilter'."
    exit 0
}

Write-Output "Processing the following tickets matching filter '$TicketFilter':"
$filteredTickets | ForEach-Object { Write-Output $_.TicketId }

# Resolve the workflow script path (Process-TicketTriageWorkflow.ps1 must exist in the same directory)
$workflowScript = Join-Path -Path $PSScriptRoot -ChildPath "Process-TicketTriageWorkflow.ps1"

# Process each filtered ticket. For each ticket, use a descriptive field if available; otherwise, provide a placeholder.
foreach ($ticket in $filteredTickets) {
    Write-Output "---------------------------------------"
    Write-Output "Processing Ticket ID: $($ticket.TicketId)"
    
    # Prepare a ticket description.
    # Here we attempt to use the 'Summary' property if it exists; otherwise, use a default message.
    $ticketDescription = $ticket.Summary
    if (-not $ticketDescription) {
        $ticketDescription = "No detailed description available for ticket $($ticket.TicketId)."
    }
    
    Write-Output "Using Ticket Description: $ticketDescription"
    
    try {
        $output = & $workflowScript -TicketId $ticket.TicketId -TicketDescription $ticketDescription
        Write-Output "Triage Output for $($ticket.TicketId):"
        Write-Output $output
    } catch {
        Write-Error "Error processing ticket $($ticket.TicketId): $_"
    }
}
