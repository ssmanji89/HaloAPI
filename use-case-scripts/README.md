# Halo API Use Case Scenarios

This directory contains a collection of PowerShell scripts demonstrating both common and advanced use case scenarios for the Halo API. These scripts illustrate how to connect to the API, retrieve and manage client information, handle tickets, track assets, perform analytics, and automate business workflows. Each script is designed to showcase specified functionalities and to serve as a robust example for integrating with Halo PSA.

---

## Scripts Overview

### 1. Connect-To-HaloAPI.ps1

Establishes a connection to the Halo API.

**Parameters:**

- **-URL** (Required): The Halo API endpoint.
- **-ClientID** (Required): The client ID used for authentication.
- **-ClientSecret** (Required): The corresponding client secret.
- **-Scopes** (Optional): API scopes to request (default: "all").
- **-Tenant** (Optional): Tenant name if required.

**Usage Example:**

```powershell
./Connect-To-HaloAPI.ps1 -URL "https://example.halopsa.com" -ClientID "your-client-id" -ClientSecret "your-client-secret" -Tenant "your-tenant"
```

---

### 2. Get-HaloClientInfo.ps1

Retrieves client information from the Halo API.

**Parameters:**

- **-ClientID**: Retrieve a specific client by ID.
- **-Search**: Search clients by a search term.
- **-Paginate**: Use pagination in results.
- **-PageSize**: Number of results per page (default: 50).
- **-PageNo**: Page number to retrieve (default: 1).
- **-IncludeDetails**: Include detailed client information.
- **-IncludeActivity**: Retrieve additional client activity data.

**Usage Examples:**

```powershell
# Retrieve a specific client with details
./Get-HaloClientInfo.ps1 -ClientID 1 -IncludeDetails

# Search clients with the term "Tech"
./Get-HaloClientInfo.ps1 -Search "Tech"

# Get paginated results
./Get-HaloClientInfo.ps1 -Paginate -PageSize 10 -PageNo 1
```

---

### 3. Demo-HaloClientScenario.ps1

Demonstrates complete client scenario workflows by combining connection and client information retrieval.

**Features:**

- Connects to the Halo API using provided credentials.
- Retrieves a specific client by ID.
- Searches for clients by keyword.
- Provides paginated client listings.

**Usage:**

1. Update the `$config` hashtable with your actual Halo API credentials.
2. Run the script:

   ```powershell
   ./Demo-HaloClientScenario.ps1
   ```

---

### 4. Manage-HaloTickets.ps1

Handles advanced ticket management scenarios.

**Features:**

- Monitors SLA and detects breaches.
- Automatically assigns tickets based on agent workload.
- Adds warning notes for overdue tickets.
- Provides detailed reporting of agent workloads.

**Parameters:**

- **-ClientID**: Filter ticket operations for a specific client.
- **-AgentIDs**: Array of agent IDs for assignment.
- **-TeamIDs**: Array of team IDs for filtering.
- **-IncludeSLAMonitoring**: Enable SLA monitoring.
- **-AutoAssign**: Enable automatic ticket assignment.
- **-DaysToLookBack**: Time window for analysis (default: 7 days).

**Usage Example:**

```powershell
./Manage-HaloTickets.ps1 -ClientID 123 -AutoAssign -AgentIDs @(1,2,3)
```

---

### 5. Analyze-HaloAssets.ps1

Provides comprehensive asset management and analysis.

**Features:**

- Tracks warranty status and alerts.
- Checks software license compliance.
- Analyzes asset age distribution.
- Generates detailed CSV asset reports.

**Parameters:**

- **-ClientID**: Filter assets for a specific client.
- **-SiteIDs**: Array of site IDs to filter assets.
- **-IncludeWarrantyAlerts**: Enable warranty status checking.
- **-CheckSoftwareLicenses**: Enable license compliance checking.
- **-WarningDays**: Pre-warning period for warranty expiration (default: 30 days).
- **-ReportPath**: Path for CSV report output (default: "AssetReport.csv").

**Usage Example:**

```powershell
./Analyze-HaloAssets.ps1 -ClientID 123 -IncludeWarrantyAlerts -CheckSoftwareLicenses
```

---

### 6. Process-HaloWorkflows.ps1

Automates complex business workflows integrating assets, tickets, and contract management.

**Features:**

- Automates maintenance ticket creation based on asset status.
- Validates contract coverage and identifies gaps.
- Generates alerts for contract expiration.
- Integrates various Halo modules for end-to-end workflow automation.

**Parameters:**

- **-ClientID**: Process workflows for a specific client.
- **-AssetTypes**: Array of asset types to include.
- **-CreateMaintenanceTickets**: Enable automatic creation of maintenance tickets.
- **-ValidateContracts**: Enable contract validation.
- **-DefaultAgentID**: Default agent ID for created tickets.
- **-DefaultTeamID**: Default team ID for created tickets.

**Usage Example:**

```powershell
./Process-HaloWorkflows.ps1 -ClientID 123 -CreateMaintenanceTickets -ValidateContracts -DefaultAgentID 1
```

---

### 7. Analyze-HaloMetrics.ps1

Performs advanced analytics and trend analysis across Halo PSA data.

**Features:**

- Analyzes ticket trends and SLA performance.
- Evaluates asset health and lifecycle metrics.
- Provides financial performance metrics and forecasting.
- Generates an interactive HTML report for analytics insights.

**Parameters:**

- **-DaysToAnalyze**: Historical data period (default: 90 days).
- **-IncludeTicketMetrics**: Enable ticket trend analysis.
- **-IncludeAssetMetrics**: Enable asset health analysis.
- **-IncludeFinancialMetrics**: Enable financial performance analysis.
- **-GenerateReport**: Generate an HTML report.
- **-ReportPath**: Custom path for the HTML report (default: "HaloMetricsReport.html").

**Usage Example:**

```powershell
./Analyze-HaloMetrics.ps1 -DaysToAnalyze 180 -IncludeTicketMetrics -IncludeAssetMetrics -IncludeFinancialMetrics -GenerateReport
```

---

### 8. Invoke-PSOpenAIQuery.ps1

Demonstrates integration with the PSOpenAI module to execute natural language queries against Halo API data.

**Usage Example:**

```powershell
./Invoke-PSOpenAIQuery.ps1 -Query "Summarize the current HaloAPI metrics"
```

---

### 9. Invoke-PSOpenAITriageTicket.ps1

Analyzes and triages a ticket description to generate actionable next steps in JSON format using GPT-4O.

**Usage Example:**

```powershell
./Invoke-PSOpenAITriageTicket.ps1 -TicketDescription "Network downtime affecting user connectivity."
```

---

### 10. Process-TicketTriageWorkflow.ps1

Processes ticket triage by generating actionable next steps in a JSON format and simulates updating the ticket.

**Usage Example:**

```powershell
./Process-TicketTriageWorkflow.ps1 -TicketId "TICKET-123" -TicketDescription "Users cannot access email."
```

---

### 11. Process-RetrievedTicketsByFilter.ps1

Retrieves open tickets, filters them by a regex Ticket ID pattern, and processes each ticket using the triage workflow.

**Parameters:**

- **-TicketFilter**: Regex pattern to filter Ticket IDs.

**Usage Example:**

```powershell
./Process-RetrievedTicketsByFilter.ps1 -TicketFilter "^TICKET-.*"
```

---

### 12. Process-RetrievedTicketsProduction.ps1

A production-ready script that retrieves, filters, triages, and simulates updating tickets with iterative enhancements and logging.

**Parameters:**

- **-TicketFilter**: Regex pattern to filter Ticket IDs.
- **-PageSize**: Number of tickets per page (default: 100).
- **-MaxRetries**: Maximum retry attempts for processing a ticket (default: 0).

**Usage Example:**

```powershell
./Process-RetrievedTicketsProduction.ps1 -TicketFilter "^TICKET-.*" -PageSize 100 -MaxRetries 2
```

---

### 13. Process-TicketsByFilter.ps1

Recursively processes and triages multiple tickets based on a Ticket ID filter using simulated ticket data.

**Parameters:**

- **-TicketFilter**: Regex pattern to filter Ticket IDs.

**Usage Example:**

```powershell
./Process-TicketsByFilter.ps1 -TicketFilter "^TICKET-.*"
```

---

### 14. Update-TicketWithTriage.ps1

Simulates updating a ticket with a JSON formatted triage comment generated by the PSOpenAI triage ticket script.

**Parameters:**

- **-TicketId**: Identifier of the ticket to update.
- **-TriageCommentJson**: A JSON formatted string with triage details.

**Usage Example:**

```powershell
./Update-TicketWithTriage.ps1 -TicketId "TICKET-123" -TriageCommentJson '{"ticketId": "TICKET-123", "priority": "high", "actionableSteps": ["Restart network interface", "Notify IT support"], "comments": "Immediate action required due to network outage."}'
```

---

## Prerequisites

- **PowerShell 5.1 or later**
- **HaloAPI PowerShell Module**: Ensure this module is installed and accessible.
- **API Credentials**: Valid Halo API credentials (URL, Client ID, and Client Secret).
- **Permissions**: Appropriate permissions for client, ticket, asset management, and report generation.
- **PSOpenAI Module**: Required for scripts integrating with GPT-4O based processing (e.g., triage workflows). Also, ensure the `OPENAI_API_KEY` environment variable is set.

---

## Setup

1. Place all the above scripts in the same directory.
2. Update any configuration details (e.g., API credentials in Demo-HaloClientScenario.ps1).
3. Execute the required script based on your intended operation.

---

## Error Handling

- Each script is designed with error handling mechanisms.
- Informative error messages are displayed.
- Scripts exit with a non-zero status code upon encountering errors.
- Logs are maintained (especially in production scripts) to aid in troubleshooting.

---

## Notes

- These scripts serve as detailed examples and may need modifications to fit specific production environments.
- Secure your API credentials and ensure they are not exposed in version control.
- Additional logging, error handling, or custom logic may be added for production use.
- The comprehensive scenarios demonstrate advanced capabilities including automated assignments, SLA monitoring, predictive analytics, and integrated business processes.
