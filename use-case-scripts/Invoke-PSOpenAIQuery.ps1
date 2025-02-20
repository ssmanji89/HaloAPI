<#
.SYNOPSIS
   Demonstrates integration with the PSOpenAI PowerShell Module for executing natural language queries against HaloAPI data.
.DESCRIPTION
   This script imports the PSOpenAI module (available at https://github.com/mkht/PSOpenAI.git) and submits a query to OpenAI.
   It is designed to complement the existing HaloAPI codebase by enabling enhanced natural language processing capabilities.
.EXAMPLE
   .\Invoke-PSOpenAIQuery.ps1 -Query "Summarize the current HaloAPI metrics"
.NOTES
   Ensure that the PSOpenAI module is installed and that the OPENAI_API_KEY environment variable is set.
   This script can be expanded to integrate with various use-case scenarios, such as processing metrics or generating actionable insights.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Query
)

# Import the PSOpenAI module
try {
    Import-Module PSOpenAI -ErrorAction Stop
} catch {
    Write-Error "Failed to import PSOpenAI module. Please ensure it is installed."
    exit 1
}

# Check if the OpenAI API key is set
if (-not $env:OPENAI_API_KEY) {
    Write-Error "The environment variable OPENAI_API_KEY is not set. Please configure it before running this script."
    exit 1
}

# Invoke a natural language query using the PSOpenAI module
try {
    $response = Invoke-PSOpenAI -Prompt $Query -MaxTokens 150
    Write-Output "Response from OpenAI:"
    Write-Output $response
} catch {
    Write-Error "An error occurred while invoking PSOpenAI: $_"
}
