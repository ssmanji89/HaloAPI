<#
.SYNOPSIS
   Triages a new ticket's description and generates actionable next steps in JSON format.
.DESCRIPTION
   This script leverages the GPT-4O model via the PSOpenAI module to produce a structured JSON output containing actionable next steps based on the ticket description provided.
   The JSON output follows a predetermined structure that can be used to update tickets with clear, actionable items.
.PARAMETER TicketDescription
   A detailed description of the ticket issue.
.EXAMPLE
   .\Invoke-PSOpenAITriageTicket.ps1 -TicketDescription "The network is down and users cannot access resources."
.NOTES
   Ensure that the PSOpenAI module is installed and that the OPENAI_API_KEY environment variable is set.
   This script uses the GPT-4O model to generate a JSON formatted response.
#>

param (
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

# Define the prompt to generate actionable next steps in JSON format
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

# Invoke a natural language query using the PSOpenAI module with the GPT-4O model
try {
    $response = Invoke-PSOpenAI -Prompt $prompt -Model "gpt-4o" -MaxTokens 350
    Write-Output "Generated JSON Response:"
    Write-Output $response
} catch {
    Write-Error "An error occurred while invoking PSOpenAI: $_"
    exit 1
}
