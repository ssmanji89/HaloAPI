# Manage-HaloTickets.ps1
# This script demonstrates complex ticket management scenarios in Halo PSA.
# It includes SLA monitoring, ticket assignment, and automated actions based on conditions.

param(
    [Parameter(Mandatory = $false)]
    [Int32]$ClientID,
    
    [Parameter(Mandatory = $false)]
    [Int32[]]$AgentIDs,
    
    [Parameter(Mandatory = $false)]
    [Int32[]]$TeamIDs,
    
    [Parameter(Mandatory = $false)]
    [Switch]$IncludeSLAMonitoring,
    
    [Parameter(Mandatory = $false)]
    [Switch]$AutoAssign,
    
    [Parameter(Mandatory = $false)]
    [Int32]$DaysToLookBack = 7
)

# Import required scripts
. "./Connect-To-HaloAPI.ps1"

function Get-OverdueTickets {
    param (
        [Parameter(Mandatory = $false)]
        [Int32]$ClientID
    )
    
    $params = @{
        OpenOnly = $true
        IncludeSLATimer = $true
        IncludeDetails = $true
    }
    
    if ($ClientID) {
        $params.Add("ClientID", $ClientID)
    }
    
    $tickets = Get-HaloTicket @params
    
    # Filter for overdue tickets based on SLA
    $overdueTickets = $tickets | Where-Object {
        $_.sla_timer -and [DateTime]$_.sla_timer.next_breach_time -lt (Get-Date)
    }
    
    return $overdueTickets
}

function Get-UnassignedTickets {
    param (
        [Parameter(Mandatory = $false)]
        [Int32]$ClientID
    )
    
    $params = @{
        OpenOnly = $true
        AgentID = 0  # Unassigned tickets
    }
    
    if ($ClientID) {
        $params.Add("ClientID", $ClientID)
    }
    
    return Get-HaloTicket @params
}

function Get-AgentWorkload {
    param (
        [Parameter(Mandatory = $true)]
        [Int32[]]$AgentIDs
    )
    
    $workload = @{}
    
    foreach ($agentId in $AgentIDs) {
        $tickets = Get-HaloTicket -AgentID $agentId -OpenOnly
        $workload[$agentId] = @{
            OpenTickets = $tickets.Count
            HighPriority = ($tickets | Where-Object { $_.priority -eq 1 }).Count
            MediumPriority = ($tickets | Where-Object { $_.priority -eq 2 }).Count
            LowPriority = ($tickets | Where-Object { $_.priority -eq 3 }).Count
        }
    }
    
    return $workload
}

function Find-OptimalAgent {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$AgentWorkloads,
        
        [Parameter(Mandatory = $true)]
        [Int32]$TicketPriority
    )
    
    # Consider both total workload and priority distribution
    $scores = @{}
    
    foreach ($agentId in $AgentWorkloads.Keys) {
        $workload = $AgentWorkloads[$agentId]
        
        # Calculate weighted score (lower is better)
        $scores[$agentId] = @{
            Score = ($workload.OpenTickets * 1) +
                   ($workload.HighPriority * 3) +
                   ($workload.MediumPriority * 2) +
                   ($workload.LowPriority * 1)
            CurrentLoad = $workload
        }
    }
    
    # Return agent with lowest score
    $optimalAgent = $scores.GetEnumerator() | Sort-Object { $_.Value.Score } | Select-Object -First 1
    return $optimalAgent.Key
}

function Update-TicketAssignments {
    param (
        [Parameter(Mandatory = $true)]
        [Object[]]$UnassignedTickets,
        
        [Parameter(Mandatory = $true)]
        [Int32[]]$AgentIDs
    )
    
    $agentWorkloads = Get-AgentWorkload -AgentIDs $AgentIDs
    
    foreach ($ticket in $UnassignedTickets) {
        $optimalAgentId = Find-OptimalAgent -AgentWorkloads $agentWorkloads -TicketPriority $ticket.priority
        
        try {
            # Update ticket assignment
            Set-HaloTicket -TicketID $ticket.id -AgentID $optimalAgentId
            
            # Update local workload tracking
            $agentWorkloads[$optimalAgentId].OpenTickets++
            switch ($ticket.priority) {
                1 { $agentWorkloads[$optimalAgentId].HighPriority++ }
                2 { $agentWorkloads[$optimalAgentId].MediumPriority++ }
                3 { $agentWorkloads[$optimalAgentId].LowPriority++ }
            }
            
            Write-Host "Assigned ticket $($ticket.id) to agent $optimalAgentId"
        }
        catch {
            Write-Error "Failed to assign ticket $($ticket.id): $_"
        }
    }
}

function Add-TicketNote {
    param (
        [Parameter(Mandatory = $true)]
        [Int64]$TicketID,
        
        [Parameter(Mandatory = $true)]
        [String]$Note
    )
    
    try {
        New-HaloAction -TicketID $TicketID -Details $Note -ActionType "note"
        Write-Host "Added note to ticket $TicketID"
    }
    catch {
        Write-Error "Failed to add note to ticket $TicketID: $_"
    }
}

# Main script execution
try {
    Write-Host "`n=== Starting Ticket Management Process ===" -ForegroundColor Cyan
    
    # Get overdue tickets
    Write-Host "`nChecking for overdue tickets..." -ForegroundColor Yellow
    $overdueTickets = Get-OverdueTickets -ClientID $ClientID
    
    if ($overdueTickets) {
        Write-Host "Found $($overdueTickets.Count) overdue tickets:" -ForegroundColor Red
        foreach ($ticket in $overdueTickets) {
            Write-Host "Ticket ID: $($ticket.id) - SLA Breach in: $($ticket.sla_timer.next_breach_time)"
            
            # Add warning note
            $note = "WARNING: This ticket is approaching or has breached its SLA. Immediate attention required."
            Add-TicketNote -TicketID $ticket.id -Note $note
        }
    }
    else {
        Write-Host "No overdue tickets found." -ForegroundColor Green
    }
    
    # Handle unassigned tickets if AutoAssign is enabled
    if ($AutoAssign -and $AgentIDs) {
        Write-Host "`nChecking for unassigned tickets..." -ForegroundColor Yellow
        $unassignedTickets = Get-UnassignedTickets -ClientID $ClientID
        
        if ($unassignedTickets) {
            Write-Host "Found $($unassignedTickets.Count) unassigned tickets. Assigning based on agent workload..."
            Update-TicketAssignments -UnassignedTickets $unassignedTickets -AgentIDs $AgentIDs
        }
        else {
            Write-Host "No unassigned tickets found." -ForegroundColor Green
        }
    }
    
    # Generate workload report
    if ($AgentIDs) {
        Write-Host "`n=== Agent Workload Report ===" -ForegroundColor Cyan
        $workloadReport = Get-AgentWorkload -AgentIDs $AgentIDs
        
        foreach ($agentId in $workloadReport.Keys) {
            $agent = Get-HaloAgent -AgentID $agentId
            Write-Host "`nAgent: $($agent.name)"
            Write-Host "Open Tickets: $($workloadReport[$agentId].OpenTickets)"
            Write-Host "High Priority: $($workloadReport[$agentId].HighPriority)"
            Write-Host "Medium Priority: $($workloadReport[$agentId].MediumPriority)"
            Write-Host "Low Priority: $($workloadReport[$agentId].LowPriority)"
        }
    }
    
}
catch {
    Write-Error "An error occurred during ticket management: $_"
    exit 1
}
finally {
    Write-Host "`n=== Ticket Management Process Complete ===" -ForegroundColor Cyan
}

<#
.SYNOPSIS
    Advanced ticket management script demonstrating complex scenarios and automation.

.DESCRIPTION
    This script provides comprehensive ticket management functionality including:
    - SLA monitoring and breach detection
    - Intelligent ticket assignment based on agent workload
    - Automated note addition for overdue tickets
    - Detailed agent workload reporting

.PARAMETER ClientID
    Optional. Filter operations to tickets for a specific client.

.PARAMETER AgentIDs
    Array of agent IDs to consider for ticket assignment and workload reporting.

.PARAMETER TeamIDs
    Array of team IDs to filter tickets by team.

.PARAMETER IncludeSLAMonitoring
    Switch to enable SLA monitoring and alerts.

.PARAMETER AutoAssign
    Switch to enable automatic ticket assignment based on agent workload.

.PARAMETER DaysToLookBack
    Number of days to look back for ticket analysis. Default is 7 days.

.EXAMPLE
    ./Manage-HaloTickets.ps1 -ClientID 123 -AutoAssign -AgentIDs @(1,2,3)
    Manages tickets for client 123, automatically assigning tickets to the specified agents.

.NOTES
    This script requires:
    1. Active connection to Halo API (use Connect-To-HaloAPI.ps1 first)
    2. Appropriate permissions for ticket management
    3. Valid agent and team IDs for assignment
#>
