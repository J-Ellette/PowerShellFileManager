#Requires -Version 7.0

# Performance Monitoring Module
# Tracks operation times, memory usage, and cache hit rates

# Module-level metrics storage
$script:PerformanceMetrics = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
$script:OperationStats = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()

function Start-PerformanceTracking {
    <#
    .SYNOPSIS
        Starts performance tracking for an operation
    .DESCRIPTION
        Initializes performance tracking and returns a tracker object
    .PARAMETER Operation
        Name of the operation being tracked
    .EXAMPLE
        $tracker = Start-PerformanceTracking -Operation "FileCopy"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Operation
    )
    
    $tracker = [PSCustomObject]@{
        Operation = $Operation
        StartTime = Get-Date
        StartMemory = [System.GC]::GetTotalMemory($false)
        ProcessId = $PID
        ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
    }
    
    return $tracker
}

function Stop-PerformanceTracking {
    <#
    .SYNOPSIS
        Stops performance tracking and records metrics
    .DESCRIPTION
        Completes performance tracking, calculates metrics, and stores results
    .PARAMETER Tracker
        Tracker object from Start-PerformanceTracking
    .PARAMETER ItemsProcessed
        Number of items processed
    .EXAMPLE
        Stop-PerformanceTracking -Tracker $tracker -ItemsProcessed 100
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $Tracker,
        
        [Parameter(Mandatory=$false)]
        [int]$ItemsProcessed = 1
    )
    
    $endTime = Get-Date
    $endMemory = [System.GC]::GetTotalMemory($false)
    
    $metric = [PSCustomObject]@{
        Operation = $Tracker.Operation
        StartTime = $Tracker.StartTime
        EndTime = $endTime
        DurationMs = ($endTime - $Tracker.StartTime).TotalMilliseconds
        ItemsProcessed = $ItemsProcessed
        MemoryUsedBytes = $endMemory - $Tracker.StartMemory
        ItemsPerSecond = if (($endTime - $Tracker.StartTime).TotalSeconds -gt 0) {
            $ItemsProcessed / ($endTime - $Tracker.StartTime).TotalSeconds
        } else { 0 }
    }
    
    # Store metric
    $key = "$($Tracker.Operation)_$($Tracker.StartTime.Ticks)"
    $script:PerformanceMetrics[$key] = $metric
    
    # Update operation statistics
    Update-OperationStatistics -Operation $Tracker.Operation -Metric $metric
    
    return $metric
}

function Update-OperationStatistics {
    param($Operation, $Metric)
    
    if (-not $script:OperationStats.ContainsKey($Operation)) {
        $script:OperationStats[$Operation] = [PSCustomObject]@{
            Operation = $Operation
            TotalExecutions = 0
            TotalDurationMs = 0
            TotalItemsProcessed = 0
            TotalMemoryUsed = 0
            AverageDurationMs = 0
            MinDurationMs = [double]::MaxValue
            MaxDurationMs = 0
            LastExecuted = $null
        }
    }
    
    $stats = $script:OperationStats[$Operation]
    
    $stats.TotalExecutions++
    $stats.TotalDurationMs += $Metric.DurationMs
    $stats.TotalItemsProcessed += $Metric.ItemsProcessed
    $stats.TotalMemoryUsed += $Metric.MemoryUsedBytes
    $stats.AverageDurationMs = $stats.TotalDurationMs / $stats.TotalExecutions
    $stats.MinDurationMs = [Math]::Min($stats.MinDurationMs, $Metric.DurationMs)
    $stats.MaxDurationMs = [Math]::Max($stats.MaxDurationMs, $Metric.DurationMs)
    $stats.LastExecuted = $Metric.EndTime
}

function Get-FileManagerMetrics {
    <#
    .SYNOPSIS
        Returns performance metrics for File Manager operations
    .DESCRIPTION
        Retrieves operation times, memory usage, and cache hit rates
    .PARAMETER Operation
        Filter by specific operation name
    .PARAMETER Last
        Return only last N metrics
    .PARAMETER Since
        Return metrics since specified date
    .EXAMPLE
        Get-FileManagerMetrics -Operation "FileCopy" -Last 10
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Operation,
        
        [Parameter(Mandatory=$false)]
        [int]$Last,
        
        [Parameter(Mandatory=$false)]
        [datetime]$Since
    )
    
    $metrics = $script:PerformanceMetrics.Values | Sort-Object StartTime -Descending
    
    if ($Operation) {
        $metrics = $metrics | Where-Object { $_.Operation -eq $Operation }
    }
    
    if ($Since) {
        $metrics = $metrics | Where-Object { $_.StartTime -gt $Since }
    }
    
    if ($Last) {
        $metrics = $metrics | Select-Object -First $Last
    }
    
    return $metrics
}

function Get-OperationStatistics {
    <#
    .SYNOPSIS
        Gets aggregated statistics for operations
    .DESCRIPTION
        Returns most used operations, file type statistics, and performance data
    .PARAMETER Operation
        Filter by specific operation
    .EXAMPLE
        Get-OperationStatistics
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Operation
    )
    
    if ($Operation) {
        if ($script:OperationStats.ContainsKey($Operation)) {
            return $script:OperationStats[$Operation]
        }
        else {
            Write-Warning "No statistics found for operation: $Operation"
            return $null
        }
    }
    else {
        return $script:OperationStats.Values | Sort-Object TotalExecutions -Descending
    }
}

function Clear-PerformanceMetrics {
    <#
    .SYNOPSIS
        Clears stored performance metrics
    .DESCRIPTION
        Removes all or filtered performance metrics from memory
    .PARAMETER Operation
        Clear only metrics for specific operation
    .EXAMPLE
        Clear-PerformanceMetrics -Operation "FileCopy"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Operation
    )
    
    if ($Operation) {
        if ($PSCmdlet.ShouldProcess($Operation, "Clear performance metrics")) {
            $keysToRemove = $script:PerformanceMetrics.Keys | Where-Object { $_ -like "$Operation*" }
            foreach ($key in $keysToRemove) {
                $script:PerformanceMetrics.TryRemove($key, [ref]$null) | Out-Null
            }
            
            $script:OperationStats.TryRemove($Operation, [ref]$null) | Out-Null
            
            Write-Host "✓ Cleared metrics for: $Operation" -ForegroundColor Green
        }
    }
    else {
        if ($PSCmdlet.ShouldProcess("All metrics", "Clear")) {
            $script:PerformanceMetrics.Clear()
            $script:OperationStats.Clear()
            Write-Host "✓ Cleared all performance metrics" -ForegroundColor Green
        }
    }
}

function Export-PerformanceReport {
    <#
    .SYNOPSIS
        Exports performance metrics to a report file
    .DESCRIPTION
        Generates a detailed performance report in JSON or CSV format
    .PARAMETER OutputPath
        Path to save the report
    .PARAMETER Format
        Report format (JSON or CSV)
    .EXAMPLE
        Export-PerformanceReport -OutputPath "C:\Reports\performance.json" -Format JSON
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('JSON', 'CSV')]
        [string]$Format = 'JSON'
    )
    
    try {
        $report = [PSCustomObject]@{
            GeneratedDate = Get-Date
            TotalOperations = $script:OperationStats.Count
            TotalMetrics = $script:PerformanceMetrics.Count
            Statistics = $script:OperationStats.Values
            RecentMetrics = ($script:PerformanceMetrics.Values | Sort-Object StartTime -Descending | Select-Object -First 100)
        }
        
        switch ($Format) {
            'JSON' {
                $report | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8
            }
            'CSV' {
                $report.RecentMetrics | Export-Csv -Path $OutputPath -NoTypeInformation
            }
        }
        
        Write-Host "✓ Performance report exported: $OutputPath" -ForegroundColor Green
        
        return [PSCustomObject]@{
            Success = $true
            OutputPath = $OutputPath
            Format = $Format
            OperationCount = $report.TotalOperations
            MetricCount = $report.TotalMetrics
        }
    }
    catch {
        Write-Error "Failed to export performance report: $_"
        return [PSCustomObject]@{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Show-PerformanceSummary {
    <#
    .SYNOPSIS
        Displays a summary of performance metrics
    .DESCRIPTION
        Shows a formatted summary of operation statistics and performance
    .EXAMPLE
        Show-PerformanceSummary
    #>
    [CmdletBinding()]
    param()
    
    Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "   File Manager Performance Summary" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
    
    $stats = $script:OperationStats.Values | Sort-Object TotalExecutions -Descending
    
    if ($stats.Count -eq 0) {
        Write-Host "`nNo performance data available" -ForegroundColor Yellow
        return
    }
    
    Write-Host "`nTop Operations by Execution Count:" -ForegroundColor Green
    Write-Host ("{0,-30} {1,10} {2,15} {3,15}" -f "Operation", "Count", "Avg Time (ms)", "Total Items") -ForegroundColor Gray
    Write-Host ("-" * 70) -ForegroundColor Gray
    
    foreach ($stat in ($stats | Select-Object -First 10)) {
        Write-Host ("{0,-30} {1,10} {2,15:N2} {3,15}" -f 
            $stat.Operation,
            $stat.TotalExecutions,
            $stat.AverageDurationMs,
            $stat.TotalItemsProcessed
        )
    }
    
    Write-Host "`nPerformance Summary:" -ForegroundColor Green
    Write-Host "  Total Operations: $($stats.Count)" -ForegroundColor Gray
    Write-Host "  Total Metrics: $($script:PerformanceMetrics.Count)" -ForegroundColor Gray
    
    $totalMemory = ($stats | Measure-Object -Property TotalMemoryUsed -Sum).Sum
    Write-Host "  Total Memory Used: $([Math]::Round($totalMemory / 1MB, 2)) MB" -ForegroundColor Gray
    
    $totalItems = ($stats | Measure-Object -Property TotalItemsProcessed -Sum).Sum
    Write-Host "  Total Items Processed: $totalItems" -ForegroundColor Gray
    
    Write-Host "`n═══════════════════════════════════════════════════`n" -ForegroundColor Cyan
}

Export-ModuleMember -Function Start-PerformanceTracking, Stop-PerformanceTracking, Get-FileManagerMetrics, Get-OperationStatistics, Clear-PerformanceMetrics, Export-PerformanceReport, Show-PerformanceSummary
