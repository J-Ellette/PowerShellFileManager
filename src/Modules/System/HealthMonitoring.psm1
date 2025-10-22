#Requires -Version 7.0

# Health Monitoring and Diagnostics Module
# Provides system health checks and diagnostic data collection

function Get-FileManagerHealth {
    <#
    .SYNOPSIS
        Performs health checks on File Manager
    .DESCRIPTION
        Checks system resource availability, module load status, cache health, and background operations
    .EXAMPLE
        Get-FileManagerHealth
    #>
    [CmdletBinding()]
    param()
    
    $healthReport = [PSCustomObject]@{
        Timestamp = Get-Date
        OverallStatus = "Unknown"
        SystemResources = $null
        ModuleStatus = $null
        CacheHealth = $null
        BackgroundOperations = $null
        DiskSpace = $null
        Warnings = @()
        Errors = @()
    }
    
    try {
        # Check system resources
        Write-Verbose "Checking system resources..."
        $memoryUsage = [System.GC]::GetTotalMemory($false)
        $memoryMB = [Math]::Round($memoryUsage / 1MB, 2)
        
        $healthReport.SystemResources = [PSCustomObject]@{
            MemoryUsageMB = $memoryMB
            ProcessId = $PID
            ProcessName = (Get-Process -Id $PID).ProcessName
            WorkingSet = [Math]::Round((Get-Process -Id $PID).WorkingSet64 / 1MB, 2)
            ThreadCount = (Get-Process -Id $PID).Threads.Count
        }
        
        if ($memoryMB -gt 500) {
            $healthReport.Warnings += "High memory usage: $memoryMB MB"
        }
        
        # Check module status
        Write-Verbose "Checking module status..."
        $loadedModules = Get-Module | Where-Object { $_.Path -like "*PowerShellFileManager*" }
        $healthReport.ModuleStatus = [PSCustomObject]@{
            LoadedModules = $loadedModules.Count
            ModuleNames = $loadedModules.Name
            AllModulesLoaded = $loadedModules.Count -gt 0
        }
        
        if ($loadedModules.Count -eq 0) {
            $healthReport.Errors += "No File Manager modules loaded"
        }
        
        # Check disk space for critical paths
        Write-Verbose "Checking disk space..."
        $diskWarnings = @()
        
        if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
            $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $null -ne $_.Used }
            foreach ($drive in $drives) {
                $freeSpaceGB = [Math]::Round($drive.Free / 1GB, 2)
                $percentFree = [Math]::Round(($drive.Free / ($drive.Used + $drive.Free)) * 100, 1)
                
                if ($percentFree -lt 10) {
                    $diskWarnings += "$($drive.Name) has only $percentFree% free space"
                }
            }
            
            $healthReport.DiskSpace = $drives | Select-Object Name, 
                @{Name="UsedGB"; Expression={[Math]::Round($_.Used / 1GB, 2)}},
                @{Name="FreeGB"; Expression={[Math]::Round($_.Free / 1GB, 2)}},
                @{Name="TotalGB"; Expression={[Math]::Round(($_.Used + $_.Free) / 1GB, 2)}},
                @{Name="PercentFree"; Expression={[Math]::Round(($_.Free / ($_.Used + $_.Free)) * 100, 1)}}
        }
        else {
            # Linux/macOS
            $rootPartition = Get-PSDrive -Name '/' -ErrorAction SilentlyContinue
            if ($rootPartition) {
                $freeSpaceGB = [Math]::Round($rootPartition.Free / 1GB, 2)
                $percentFree = [Math]::Round(($rootPartition.Free / ($rootPartition.Used + $rootPartition.Free)) * 100, 1)
                
                if ($percentFree -lt 10) {
                    $diskWarnings += "Root partition has only $percentFree% free space"
                }
                
                $healthReport.DiskSpace = [PSCustomObject]@{
                    Partition = "/"
                    FreeGB = $freeSpaceGB
                    PercentFree = $percentFree
                }
            }
        }
        
        $healthReport.Warnings += $diskWarnings
        
        # Cache health (if Performance Monitoring module is loaded)
        if (Get-Command Get-FileManagerMetrics -ErrorAction SilentlyContinue) {
            Write-Verbose "Checking cache health..."
            $metrics = Get-FileManagerMetrics -Last 100
            
            $healthReport.CacheHealth = [PSCustomObject]@{
                TotalMetrics = $metrics.Count
                RecentOperations = ($metrics | Measure-Object).Count
                AverageOperationTime = if ($metrics) {
                    [Math]::Round(($metrics | Measure-Object -Property DurationMs -Average).Average, 2)
                } else { 0 }
            }
        }
        
        # Background operations queue status (placeholder)
        Write-Verbose "Checking background operations..."
        $healthReport.BackgroundOperations = [PSCustomObject]@{
            QueuedOperations = 0  # Would be populated by actual queue
            RunningOperations = 0
            FailedOperations = 0
        }
        
        # Determine overall status
        if ($healthReport.Errors.Count -gt 0) {
            $healthReport.OverallStatus = "Critical"
        }
        elseif ($healthReport.Warnings.Count -gt 0) {
            $healthReport.OverallStatus = "Warning"
        }
        else {
            $healthReport.OverallStatus = "Healthy"
        }
        
        # Display summary
        $statusColor = switch ($healthReport.OverallStatus) {
            "Healthy" { "Green" }
            "Warning" { "Yellow" }
            "Critical" { "Red" }
            default { "Gray" }
        }
        
        Write-Host "`n═══════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "   File Manager Health Report" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "Status: $($healthReport.OverallStatus)" -ForegroundColor $statusColor
        Write-Host "Memory: $($healthReport.SystemResources.MemoryUsageMB) MB" -ForegroundColor Gray
        Write-Host "Modules: $($healthReport.ModuleStatus.LoadedModules)" -ForegroundColor Gray
        
        if ($healthReport.Warnings.Count -gt 0) {
            Write-Host "`nWarnings:" -ForegroundColor Yellow
            $healthReport.Warnings | ForEach-Object { Write-Host "  • $_" -ForegroundColor Yellow }
        }
        
        if ($healthReport.Errors.Count -gt 0) {
            Write-Host "`nErrors:" -ForegroundColor Red
            $healthReport.Errors | ForEach-Object { Write-Host "  • $_" -ForegroundColor Red }
        }
        
        Write-Host "═══════════════════════════════════════`n" -ForegroundColor Cyan
        
        return $healthReport
    }
    catch {
        Write-Error "Failed to perform health check: $_"
        $healthReport.OverallStatus = "Error"
        $healthReport.Errors += $_.Exception.Message
        return $healthReport
    }
}

function Export-DiagnosticData {
    <#
    .SYNOPSIS
        Collects and exports diagnostic data
    .DESCRIPTION
        Gathers logs, configurations, metrics, and system information for troubleshooting
    .PARAMETER OutputPath
        Path to save the diagnostic bundle
    .PARAMETER IncludeLogs
        Include log files in the bundle
    .PARAMETER IncludeMetrics
        Include performance metrics
    .PARAMETER SanitizeSensitiveData
        Remove sensitive information from exports
    .EXAMPLE
        Export-DiagnosticData -OutputPath "C:\Diagnostics\bundle.zip"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeLogs,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeMetrics,
        
        [Parameter(Mandatory=$false)]
        [switch]$SanitizeSensitiveData
    )
    
    try {
        Write-Host "Collecting diagnostic data..." -ForegroundColor Cyan
        
        # Create temp directory for diagnostic data
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "FileManager_Diagnostics_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        
        # Collect system information
        Write-Verbose "Collecting system information..."
        $sysInfo = [PSCustomObject]@{
            Timestamp = Get-Date
            PSVersion = $PSVersionTable.PSVersion
            OS = $PSVersionTable.OS
            Platform = $PSVersionTable.Platform
            ProcessorCount = [Environment]::ProcessorCount
            MachineName = if ($SanitizeSensitiveData) { "REDACTED" } else { $env:COMPUTERNAME }
            UserName = if ($SanitizeSensitiveData) { "REDACTED" } else { $env:USERNAME }
        }
        
        $sysInfo | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $tempDir "SystemInfo.json") -Encoding UTF8
        
        # Collect health report
        Write-Verbose "Collecting health report..."
        $healthReport = Get-FileManagerHealth
        $healthReport | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $tempDir "HealthReport.json") -Encoding UTF8
        
        # Collect configuration
        Write-Verbose "Collecting configuration..."
        if (Get-Command Get-FileManagerConfig -ErrorAction SilentlyContinue) {
            $config = Get-FileManagerConfig
            
            if ($SanitizeSensitiveData -or $PSBoundParameters.Count -eq 1) {
                # Sanitize paths and sensitive data
                $config.ConfigPath = "REDACTED"
            }
            
            $config | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $tempDir "Configuration.json") -Encoding UTF8
        }
        
        # Collect logs
        if ($IncludeLogs -or $PSBoundParameters.Count -eq 1) {
            Write-Verbose "Collecting logs..."
            $logPath = if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
                Join-Path $env:APPDATA "PowerShellFileManager\Logs"
            } else {
                Join-Path $HOME ".config/PowerShellFileManager/logs"
            }
            
            if (Test-Path $logPath) {
                $logsDir = Join-Path $tempDir "Logs"
                New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
                
                # Copy recent log files
                Get-ChildItem -Path $logPath -Filter "*.log" |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 5 |
                    ForEach-Object {
                        if ($SanitizeSensitiveData -or $PSBoundParameters.Count -eq 1) {
                            # Sanitize log content
                            $content = Get-Content $_.FullName
                            $sanitized = $content -replace '([A-Z]:\\[^\\]+)', 'C:\REDACTED' `
                                                  -replace '(/[^/]+/[^/]+)', '/REDACTED' `
                                                  -replace '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', 'email@redacted.com'
                            $sanitized | Set-Content -Path (Join-Path $logsDir $_.Name)
                        }
                        else {
                            Copy-Item -Path $_.FullName -Destination $logsDir
                        }
                    }
            }
        }
        
        # Collect metrics
        if (($IncludeMetrics -or $PSBoundParameters.Count -eq 1) -and (Get-Command Get-FileManagerMetrics -ErrorAction SilentlyContinue)) {
            Write-Verbose "Collecting performance metrics..."
            $metrics = Get-FileManagerMetrics -Last 100
            $metrics | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $tempDir "PerformanceMetrics.json") -Encoding UTF8
            
            $stats = Get-OperationStatistics
            $stats | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $tempDir "OperationStatistics.json") -Encoding UTF8
        }
        
        # Collect module information
        Write-Verbose "Collecting module information..."
        $modules = Get-Module | Where-Object { $_.Path -like "*PowerShellFileManager*" } |
            Select-Object Name, Version, Path, ExportedCommands
        $modules | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $tempDir "LoadedModules.json") -Encoding UTF8
        
        # Create ZIP archive
        Write-Verbose "Creating diagnostic bundle..."
        Compress-Archive -Path "$tempDir\*" -DestinationPath $OutputPath -Force
        
        # Cleanup temp directory
        Remove-Item -Path $tempDir -Recurse -Force
        
        Write-Host "✓ Diagnostic data exported: $OutputPath" -ForegroundColor Green
        
        return [PSCustomObject]@{
            Success = $true
            OutputPath = $OutputPath
            Size = (Get-Item $OutputPath).Length
            ContainsSensitiveData = -not ($SanitizeSensitiveData -or $PSBoundParameters.Count -eq 1)
        }
    }
    catch {
        Write-Error "Failed to export diagnostic data: $_"
        return [PSCustomObject]@{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Test-StartupHealth {
    <#
    .SYNOPSIS
        Performs startup health checks
    .DESCRIPTION
        Validates configuration, plugin directories, and required assemblies on startup
    .EXAMPLE
        Test-StartupHealth
    #>
    [CmdletBinding()]
    param()
    
    $issues = @()
    $warnings = @()
    
    Write-Host "Performing startup health checks..." -ForegroundColor Cyan
    
    # Check configuration directory
    $configDir = if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
        Join-Path $env:APPDATA "PowerShellFileManager"
    } else {
        Join-Path $HOME ".config/PowerShellFileManager"
    }
    
    if (-not (Test-Path $configDir)) {
        try {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
            Write-Verbose "Created configuration directory: $configDir"
        }
        catch {
            $issues += "Cannot create configuration directory: $configDir"
        }
    }
    
    # Test config directory is writable
    $testFile = Join-Path $configDir "writetest.tmp"
    try {
        "test" | Set-Content -Path $testFile
        Remove-Item -Path $testFile -Force
    }
    catch {
        $issues += "Configuration directory is not writable: $configDir"
    }
    
    # Check temp directory availability
    $tempPath = [System.IO.Path]::GetTempPath()
    if (-not (Test-Path $tempPath)) {
        $issues += "Temp directory not accessible: $tempPath"
    }
    
    # Check plugin directories
    $pluginDir = Join-Path $configDir "Plugins"
    if (-not (Test-Path $pluginDir)) {
        try {
            New-Item -Path $pluginDir -ItemType Directory -Force | Out-Null
            Write-Verbose "Created plugin directory: $pluginDir"
        }
        catch {
            $warnings += "Cannot create plugin directory: $pluginDir"
        }
    }
    
    # Check required assemblies (Windows only)
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
        $requiredAssemblies = @(
            'System.Windows.Forms',
            'PresentationFramework',
            'PresentationCore'
        )
        
        foreach ($assembly in $requiredAssemblies) {
            try {
                Add-Type -AssemblyName $assembly -ErrorAction Stop
            }
            catch {
                $warnings += "Assembly not available: $assembly (GUI features may be limited)"
            }
        }
    }
    
    # Display results
    if ($issues.Count -eq 0 -and $warnings.Count -eq 0) {
        Write-Host "✓ All startup health checks passed" -ForegroundColor Green
        return [PSCustomObject]@{
            Success = $true
            Issues = @()
            Warnings = @()
        }
    }
    else {
        if ($issues.Count -gt 0) {
            Write-Host "`nCritical Issues:" -ForegroundColor Red
            $issues | ForEach-Object { Write-Host "  ✗ $_" -ForegroundColor Red }
        }
        
        if ($warnings.Count -gt 0) {
            Write-Host "`nWarnings:" -ForegroundColor Yellow
            $warnings | ForEach-Object { Write-Host "  ⚠ $_" -ForegroundColor Yellow }
        }
        
        return [PSCustomObject]@{
            Success = ($issues.Count -eq 0)
            Issues = $issues
            Warnings = $warnings
        }
    }
}

Export-ModuleMember -Function Get-FileManagerHealth, Export-DiagnosticData, Test-StartupHealth
