# Analyze-HaloMetrics.ps1
# This script performs advanced analytics and trend analysis across Halo PSA data,
# identifying patterns, generating insights, and providing actionable recommendations.

param(
    [Parameter(Mandatory = $false)]
    [Int32]$DaysToAnalyze = 90,
    
    [Parameter(Mandatory = $false)]
    [Switch]$IncludeTicketMetrics,
    
    [Parameter(Mandatory = $false)]
    [Switch]$IncludeAssetMetrics,
    
    [Parameter(Mandatory = $false)]
    [Switch]$IncludeFinancialMetrics,
    
    [Parameter(Mandatory = $false)]
    [Switch]$GenerateReport,
    
    [Parameter(Mandatory = $false)]
    [String]$ReportPath = "HaloMetricsReport.html"
)

# Import required scripts
. "./Connect-To-HaloAPI.ps1"

function Get-TicketTrends {
    param (
        [Parameter(Mandatory = $true)]
        [Int32]$DaysToAnalyze
    )
    
    $startDate = (Get-Date).AddDays(-$DaysToAnalyze)
    $tickets = Get-HaloTicket -DateSearch "created" -StartDate $startDate.ToString("yyyy-MM-dd") -FullObjects
    
    $trends = @{
        VolumeByDay = @{}
        ResponseTimes = @{
            Average = 0
            Trend = @{}
        }
        ResolutionTimes = @{
            Average = 0
            Trend = @{}
        }
        Categories = @{}
        PriorityDistribution = @{}
        TopClients = @{}
        RecurringIssues = @{}
        SLAPerformance = @{
            Met = 0
            Breached = 0
            Trend = @{}
        }
        AgentPerformance = @{}
        CustomerSatisfaction = @{
            Average = 0
            Trend = @{}
        }
    }
    
    foreach ($ticket in $tickets) {
        $created = [DateTime]$ticket.created_date
        $dateKey = $created.ToString("yyyy-MM-dd")
        
        # Track daily volume
        if (-not $trends.VolumeByDay[$dateKey]) {
            $trends.VolumeByDay[$dateKey] = 0
        }
        $trends.VolumeByDay[$dateKey]++
        
        # Track categories
        $category = $ticket.category1_name
        if (-not $trends.Categories[$category]) {
            $trends.Categories[$category] = 0
        }
        $trends.Categories[$category]++
        
        # Track priorities
        $priority = $ticket.priority
        if (-not $trends.PriorityDistribution[$priority]) {
            $trends.PriorityDistribution[$priority] = 0
        }
        $trends.PriorityDistribution[$priority]++
        
        # Track clients
        if (-not $trends.TopClients[$ticket.client_name]) {
            $trends.TopClients[$ticket.client_name] = 0
        }
        $trends.TopClients[$ticket.client_name]++
        
        # Track recurring issues
        $issueKey = "$($ticket.category1_name):$($ticket.summary)"
        if (-not $trends.RecurringIssues[$issueKey]) {
            $trends.RecurringIssues[$issueKey] = 0
        }
        $trends.RecurringIssues[$issueKey]++
        
        # Track SLA performance
        if ($ticket.sla_timer) {
            if ($ticket.sla_timer.breached) {
                $trends.SLAPerformance.Breached++
            } else {
                $trends.SLAPerformance.Met++
            }
            
            if (-not $trends.SLAPerformance.Trend[$dateKey]) {
                $trends.SLAPerformance.Trend[$dateKey] = @{
                    Met = 0
                    Breached = 0
                }
            }
            if ($ticket.sla_timer.breached) {
                $trends.SLAPerformance.Trend[$dateKey].Breached++
            } else {
                $trends.SLAPerformance.Trend[$dateKey].Met++
            }
        }
        
        # Track agent performance
        if ($ticket.agent_name) {
            if (-not $trends.AgentPerformance[$ticket.agent_name]) {
                $trends.AgentPerformance[$ticket.agent_name] = @{
                    TicketsHandled = 0
                    AverageResolutionTime = 0
                    SLABreaches = 0
                    CustomerSatisfaction = 0
                    HighPriorityTickets = 0
                }
            }
            
            $trends.AgentPerformance[$ticket.agent_name].TicketsHandled++
            if ($ticket.sla_timer.breached) {
                $trends.AgentPerformance[$ticket.agent_name].SLABreaches++
            }
            if ($ticket.priority -eq 1) {
                $trends.AgentPerformance[$ticket.agent_name].HighPriorityTickets++
            }
        }
    }
    
    # Calculate averages and sort data
    $trends.TopClients = $trends.TopClients.GetEnumerator() | 
        Sort-Object -Property Value -Descending | 
        Select-Object -First 10 | 
        ForEach-Object { @{$_.Key = $_.Value} }
    
    $trends.RecurringIssues = $trends.RecurringIssues.GetEnumerator() | 
        Sort-Object -Property Value -Descending | 
        Select-Object -First 20 | 
        ForEach-Object { @{$_.Key = $_.Value} }
    
    return $trends
}

function Get-AssetAnalytics {
    param (
        [Parameter(Mandatory = $true)]
        [Int32]$DaysToAnalyze
    )
    
    $assets = Get-HaloAsset -FullObjects
    
    $analytics = @{
        TotalAssets = $assets.Count
        AssetsByType = @{}
        AssetsByStatus = @{}
        AssetsByAge = @{
            "0-1 Year" = 0
            "1-2 Years" = 0
            "2-3 Years" = 0
            "3-5 Years" = 0
            "5+ Years" = 0
        }
        MaintenanceMetrics = @{
            RequiringMaintenance = 0
            RecentlyServiced = 0
            MaintenanceCosts = 0
        }
        PerformanceMetrics = @{
            HighPerforming = 0
            NeedsAttention = 0
            CriticalIssues = 0
        }
        ReplacementForecast = @{
            Next6Months = 0
            Next12Months = 0
            Next24Months = 0
            EstimatedCost = 0
        }
        ROIAnalysis = @{}
    }
    
    $today = Get-Date
    foreach ($asset in $assets) {
        # Asset type distribution
        if (-not $analytics.AssetsByType[$asset.type]) {
            $analytics.AssetsByType[$asset.type] = 0
        }
        $analytics.AssetsByType[$asset.type]++
        
        # Asset status distribution
        if (-not $analytics.AssetsByStatus[$asset.status]) {
            $analytics.AssetsByStatus[$asset.status] = 0
        }
        $analytics.AssetsByStatus[$asset.status]++
        
        # Age analysis
        if ($asset.purchase_date) {
            $age = ($today - [DateTime]$asset.purchase_date).TotalDays / 365
            switch ($age) {
                { $_ -lt 1 } { $analytics.AssetsByAge["0-1 Year"]++; break }
                { $_ -lt 2 } { $analytics.AssetsByAge["1-2 Years"]++; break }
                { $_ -lt 3 } { $analytics.AssetsByAge["2-3 Years"]++; break }
                { $_ -lt 5 } { $analytics.AssetsByAge["3-5 Years"]++; break }
                default { $analytics.AssetsByAge["5+ Years"]++ }
            }
            
            # Replacement forecasting
            $expectedLifespan = switch ($asset.type) {
                "Laptop" { 3 }
                "Desktop" { 4 }
                "Server" { 5 }
                "Network Device" { 5 }
                default { 4 }
            }
            
            $remainingLife = $expectedLifespan - $age
            if ($remainingLife -le 0.5) {
                $analytics.ReplacementForecast.Next6Months++
                $analytics.ReplacementForecast.EstimatedCost += $asset.value
            }
            elseif ($remainingLife -le 1) {
                $analytics.ReplacementForecast.Next12Months++
            }
            elseif ($remainingLife -le 2) {
                $analytics.ReplacementForecast.Next24Months++
            }
        }
        
        # Performance analysis
        if ($asset.custom_fields) {
            if ($asset.custom_fields.performance_score) {
                $score = [int]$asset.custom_fields.performance_score
                switch ($score) {
                    { $_ -ge 80 } { $analytics.PerformanceMetrics.HighPerforming++; break }
                    { $_ -ge 60 } { $analytics.PerformanceMetrics.NeedsAttention++; break }
                    default { $analytics.PerformanceMetrics.CriticalIssues++ }
                }
            }
            
            # Maintenance tracking
            if ($asset.custom_fields.last_maintenance) {
                $lastMaintenance = [DateTime]$asset.custom_fields.last_maintenance
                if (($today - $lastMaintenance).TotalDays -lt 30) {
                    $analytics.MaintenanceMetrics.RecentlyServiced++
                }
                if (($today - $lastMaintenance).TotalDays -gt 180) {
                    $analytics.MaintenanceMetrics.RequiringMaintenance++
                }
            }
        }
        
        # ROI Analysis
        if ($asset.value -and $asset.purchase_date) {
            $key = "$($asset.type)_ROI"
            if (-not $analytics.ROIAnalysis[$key]) {
                $analytics.ROIAnalysis[$key] = @{
                    TotalValue = 0
                    TotalCost = 0
                    AverageAge = 0
                    Count = 0
                }
            }
            $analytics.ROIAnalysis[$key].TotalValue += $asset.value
            $analytics.ROIAnalysis[$key].Count++
            $analytics.ROIAnalysis[$key].AverageAge += ($today - [DateTime]$asset.purchase_date).TotalDays / 365
        }
    }
    
    # Finalize ROI calculations
    foreach ($key in $analytics.ROIAnalysis.Keys) {
        $analytics.ROIAnalysis[$key].AverageAge = $analytics.ROIAnalysis[$key].AverageAge / $analytics.ROIAnalysis[$key].Count
    }
    
    return $analytics
}

function Get-FinancialMetrics {
    param (
        [Parameter(Mandatory = $true)]
        [Int32]$DaysToAnalyze
    )
    
    $startDate = (Get-Date).AddDays(-$DaysToAnalyze)
    
    $metrics = @{
        Revenue = @{
            Total = 0
            ByClient = @{}
            ByService = @{}
            Trend = @{}
        }
        Contracts = @{
            Active = 0
            Value = 0
            RenewalRate = 0
            ByType = @{}
        }
        ProjectedRevenue = @{
            Next30Days = 0
            Next90Days = 0
            Next180Days = 0
        }
        ServiceUtilization = @{
            ByService = @{}
            TopServices = @()
        }
        ClientMetrics = @{
            TotalClients = 0
            NewClients = 0
            ChurnRate = 0
            AverageRevenue = 0
        }
    }
    
    # Get invoices
    $invoices = Get-HaloInvoice -DateSearch "created" -StartDate $startDate.ToString("yyyy-MM-dd")
    foreach ($invoice in $invoices) {
        $dateKey = ([DateTime]$invoice.created_date).ToString("yyyy-MM-dd")
        
        # Track revenue
        if (-not $metrics.Revenue.Trend[$dateKey]) {
            $metrics.Revenue.Trend[$dateKey] = 0
        }
        $metrics.Revenue.Trend[$dateKey] += $invoice.total
        $metrics.Revenue.Total += $invoice.total
        
        # Track by client
        if (-not $metrics.Revenue.ByClient[$invoice.client_name]) {
            $metrics.Revenue.ByClient[$invoice.client_name] = 0
        }
        $metrics.Revenue.ByClient[$invoice.client_name] += $invoice.total
    }
    
    # Get contracts
    $contracts = Get-HaloContract
    foreach ($contract in $contracts) {
        if ($contract.status -eq "Active") {
            $metrics.Contracts.Active++
            $metrics.Contracts.Value += $contract.value
            
            if (-not $metrics.Contracts.ByType[$contract.type]) {
                $metrics.Contracts.ByType[$contract.type] = @{
                    Count = 0
                    Value = 0
                }
            }
            $metrics.Contracts.ByType[$contract.type].Count++
            $metrics.Contracts.ByType[$contract.type].Value += $contract.value
        }
    }
    
    # Get services
    $services = Get-HaloService
    foreach ($service in $services) {
        $metrics.ServiceUtilization.ByService[$service.name] = @{
            Usage = 0
            Revenue = 0
        }
    }
    
    # Calculate averages and trends
    $metrics.ClientMetrics.AverageRevenue = $metrics.Revenue.Total / ($metrics.Revenue.ByClient.Keys.Count)
    $metrics.ServiceUtilization.TopServices = $metrics.ServiceUtilization.ByService.GetEnumerator() | 
        Sort-Object { $_.Value.Revenue } -Descending | 
        Select-Object -First 10
    
    return $metrics
}

function New-HTMLReport {
    param (
        [Parameter(Mandatory = $true)]
        [Object]$TicketTrends,
        
        [Parameter(Mandatory = $true)]
        [Object]$AssetAnalytics,
        
        [Parameter(Mandatory = $true)]
        [Object]$FinancialMetrics,
        
        [Parameter(Mandatory = $true)]
        [String]$ReportPath
    )
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Halo PSA Analytics Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .section { margin: 20px 0; padding: 20px; border: 1px solid #ddd; }
        .metric { margin: 10px 0; }
        .chart { width: 100%; height: 300px; margin: 20px 0; }
        .warning { color: red; }
        .success { color: green; }
    </style>
    <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
</head>
<body>
    <h1>Halo PSA Analytics Report</h1>
    <div class="section">
        <h2>Executive Summary</h2>
        <div class="metric">
            <p>Total Tickets: $($TicketTrends.VolumeByDay.Values | Measure-Object -Sum | Select-Object -ExpandProperty Sum)</p>
            <p>Total Assets: $($AssetAnalytics.TotalAssets)</p>
            <p>Total Revenue: $($FinancialMetrics.Revenue.Total)</p>
        </div>
    </div>
    
    <div class="section">
        <h2>Ticket Analysis</h2>
        <div class="metric">
            <h3>SLA Performance</h3>
            <p>Met: $($TicketTrends.SLAPerformance.Met)</p>
            <p>Breached: $($TicketTrends.SLAPerformance.Breached)</p>
        </div>
        <div class="metric">
            <h3>Top Issues</h3>
            <ul>
                $(foreach ($issue in ($TicketTrends.RecurringIssues.GetEnumerator() | Select-Object -First 5)) {
                    "<li>$($issue.Key): $($issue.Value) occurrences</li>"
                })
            </ul>
        </div>
    </div>
    
    <div class="section">
        <h2>Asset Health</h2>
        <div class="metric">
            <h3>Replacement Forecast</h3>
            <p>Next 6 Months: $($AssetAnalytics.ReplacementForecast.Next6Months)</p>
            <p>Estimated Cost: $($AssetAnalytics.ReplacementForecast.EstimatedCost)</p>
        </div>
        <div class="metric">
            <h3>Performance</h3>
            <p>High Performing: $($AssetAnalytics.PerformanceMetrics.HighPerforming)</p>
            <p>Needs Attention: $($AssetAnalytics.PerformanceMetrics.NeedsAttention)</p>
            <p>Critical Issues: $($AssetAnalytics.PerformanceMetrics.CriticalIssues)</p>
        </div>
    </div>
    
    <div class="section">
        <h2>Financial Overview</h2>
        <div class="metric">
            <h3>Contract Value</h3>
            <p>Active Contracts: $($FinancialMetrics.Contracts.Active)</p>
            <p>Total Value: $($FinancialMetrics.Contracts.Value)</p>
        </div>
        <div class="metric">
            <h3>Top Revenue Sources</h3>
            <ul>
                $(foreach ($client in ($FinancialMetrics.Revenue.ByClient.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5)) {
                    "<li>$($client.Key): $($client.Value)</li>"
                })
            </ul>
        </div>
    </div>
</body>
</html>
"@
    
    $html | Out-File -FilePath $ReportPath -Encoding UTF8
    Write-Host "Report generated: $ReportPath"
}

# Main script execution
try {
    Write-Host "`n=== Starting Halo Analytics Processing ===" -ForegroundColor Cyan
    
    $results = @{}
    
    # Process ticket metrics
    if ($IncludeTicketMetrics) {
        Write-Host "`nAnalyzing ticket trends..." -ForegroundColor Yellow
        $results.TicketTrends = Get-TicketTrends -DaysToAnalyze $DaysToAnalyze
        
        Write-Host "`n=== Ticket Analysis Summary ===" -ForegroundColor Cyan
        Write-Host "Total Tickets: $($results.TicketTrends.VolumeByDay.Values | Measure-Object -Sum | Select-Object -ExpandProperty Sum)"
        Write-Host "SLA Performance:"
        Write-Host "  Met: $($results.TicketTrends.SLAPerformance.Met)" -ForegroundColor Green
        Write-Host "  Breached: $($results.TicketTrends.SLAPerformance.Breached)" -ForegroundColor Red
        
        Write-Host "`nTop 5 Recurring Issues:"
        $results.TicketTrends.RecurringIssues.GetEnumerator() | 
            Sort-Object Value -Descending | 
            Select-Object -First 5 | 
            ForEach-Object {
                Write-Host "  $($_.Key): $($_.Value) occurrences"
            }
    }
    
    # Process asset metrics
    if ($IncludeAssetMetrics) {
        Write-Host "`nAnalyzing asset metrics..." -ForegroundColor Yellow
        $results.AssetAnalytics = Get-AssetAnalytics -DaysToAnalyze $DaysToAnalyze
        
        Write-Host "`n=== Asset Analysis Summary ===" -ForegroundColor Cyan
        Write-Host "Total Assets: $($results.AssetAnalytics.TotalAssets)"
        Write-Host "`nReplacement Forecast:"
        Write-Host "  Next 6 Months: $($results.AssetAnalytics.ReplacementForecast.Next6Months)" -ForegroundColor $(
            if ($results.AssetAnalytics.ReplacementForecast.Next6Months -gt 10) { "Red" } else { "Yellow" }
        )
        Write-Host "  Estimated Cost: $($results.AssetAnalytics.ReplacementForecast.EstimatedCost)"
        
        Write-Host "`nPerformance Metrics:"
        Write-Host "  High Performing: $($results.AssetAnalytics.PerformanceMetrics.HighPerforming)" -ForegroundColor Green
        Write-Host "  Needs Attention: $($results.AssetAnalytics.PerformanceMetrics.NeedsAttention)" -ForegroundColor Yellow
        Write-Host "  Critical Issues: $($results.AssetAnalytics.PerformanceMetrics.CriticalIssues)" -ForegroundColor Red
    }
    
    # Process financial metrics
    if ($IncludeFinancialMetrics) {
        Write-Host "`nAnalyzing financial metrics..." -ForegroundColor Yellow
        $results.FinancialMetrics = Get-FinancialMetrics -DaysToAnalyze $DaysToAnalyze
        
        Write-Host "`n=== Financial Analysis Summary ===" -ForegroundColor Cyan
        Write-Host "Total Revenue: $($results.FinancialMetrics.Revenue.Total)"
        Write-Host "Active Contracts: $($results.FinancialMetrics.Contracts.Active)"
        Write-Host "Contract Value: $($results.FinancialMetrics.Contracts.Value)"
        
        Write-Host "`nTop 5 Revenue Sources:"
        $results.FinancialMetrics.Revenue.ByClient.GetEnumerator() | 
            Sort-Object Value -Descending | 
            Select-Object -First 5 | 
            ForEach-Object {
                Write-Host "  $($_.Key): $($_.Value)"
            }
    }
    
    # Generate HTML report if requested
    if ($GenerateReport) {
        Write-Host "`nGenerating HTML report..." -ForegroundColor Yellow
        New-HTMLReport `
            -TicketTrends $results.TicketTrends `
            -AssetAnalytics $results.AssetAnalytics `
            -FinancialMetrics $results.FinancialMetrics `
            -ReportPath $ReportPath
    }
}
catch {
    Write-Error "An error occurred during analytics processing: $_"
    exit 1
}
finally {
    Write-Host "`n=== Analytics Processing Complete ===" -ForegroundColor Cyan
}

<#
.SYNOPSIS
    Advanced analytics and trend analysis script for Halo PSA data.

.DESCRIPTION
    This script provides comprehensive analytics including:
    - Ticket trend analysis and SLA performance
    - Asset health and lifecycle metrics
    - Financial performance and forecasting
    - Detailed HTML report generation

.PARAMETER DaysToAnalyze
    Number of days of historical data to analyze. Default is 90 days.

.PARAMETER IncludeTicketMetrics
    Switch to enable ticket metrics analysis.

.PARAMETER IncludeAssetMetrics
    Switch to enable asset metrics analysis.

.PARAMETER IncludeFinancialMetrics
    Switch to enable financial metrics analysis.

.PARAMETER GenerateReport
    Switch to enable HTML report generation.

.PARAMETER ReportPath
    Path where the HTML report should be saved. Default is "HaloMetricsReport.html".

.EXAMPLE
    ./Analyze-HaloMetrics.ps1 -DaysToAnalyze 180 -IncludeTicketMetrics -IncludeAssetMetrics -IncludeFinancialMetrics -GenerateReport

.NOTES
    This script requires:
    1. Active connection to Halo API (use Connect-To-HaloAPI.ps1 first)
    2. Appropriate permissions for data access
    3. Modern web browser for viewing the HTML report
#>
