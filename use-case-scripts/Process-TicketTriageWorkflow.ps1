<#
.SYNOPSIS
   Processes ticket triage by generating actionable next steps and updating the ticket.
.DESCRIPTION
   This script integrates the triage and update workflow. It accepts a ticket identifier and a ticket description,
   then leverages the GPT-4O model via the PSOpenAI module to generate a JSON formatted actionable triage comment.
   Finally, it simulates updating a ticket with the generated triage details.
.PARAMETER TicketId
   The unique identifier for the ticket to be processed.
.PARAMETER TicketDescription
   A detailed description of the ticket issue.
.EXAMPLE
   .\Process-TicketTriageWorkflow.ps1 -TicketId "TICKET-123" -TicketDescription "Users are unable to access the network."
.NOTES
   Ensure that the PSOpenAI module is installed and that the OPENAI_API_KEY environment variable is set.
   This script relies on the GPT-4O model to generate structured JSON responses.
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$TicketId,

    [Parameter(Mandatory=$true)]
    [string]$TicketDescription
)

# Import the PSOpenAI module
try {
    Import-Module PSOpenAI -ErrorAction Stop
} catch {
    Write-Error "Failed to import PSOpenAI module. Please ensure it is installed."
    exit 1
}

# Ensure the OpenAI API Key is set
if (-not $env:OPENAI_API_KEY) {
    Write-Error "The OPENAI_API_KEY environment variable is not set. Please configure it before running this script."
    exit 1
}

# Define the prompt for generating actionable next steps in JSON format
$prompt = @"
Triaging Ticket:
$TicketDescription

Please generate actionable next steps in JSON format using the following structure:
{
    "ticketId": "<ticket identifier if available>",
    "priority": "<low|medium|high>",
    "actionableSteps": [
        "Step 1",
        "Step 2"
    ],
    "comments": "<additional commentary if any>"
}

Return only the JSON with no additional text or explanation.
"@

# Invoke the PSOpenAI module with the GPT-4O model to generate triage details
try {
    $triageResponse = Invoke-PSOpenAI -Prompt $prompt -Model "gpt-4o" -MaxTokens 350
    Write-Output "Generated Triage JSON:"
    Write-Output $triageResponse
} catch {
    Write-Error "An error occurred while generating triage details: $_"
    exit 1
}

# Validate the generated triage JSON
try {
    $triageJson = $triageResponse | ConvertFrom-Json
} catch {
    Write-Error "The generated triage response is not valid JSON."
    exit 1
}

# Simulate updating the ticket with the generated triage details
function Update-TicketComment {
    param (
        [string]$TicketId,
        [string]$CommentJson
    )

    Write-Output "Updating ticket with ID: $TicketId"
    Write-Output "The following triage comment will be added:"
    Write-Output $CommentJson

    # Simulate API update delay
    Start-Sleep -Seconds 2

    Write-Output "Ticket $TicketId successfully updated with the triage comment."
}

# Update the ticket using the generated triage JSON
Update-TicketComment -TicketId $TicketId -CommentJson $triageResponse
