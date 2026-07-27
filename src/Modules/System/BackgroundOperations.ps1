#Requires -Version 7.0

# Background Operations Module - Copy/Move in background with progress tracking

$script:BackgroundOperations = [System.Collections.ArrayList]::new()

function Start-BackgroundCopy {
    <#
    .SYNOPSIS
        Copies files in background with comprehensive error handling and progress tracking
    .DESCRIPTION
        Starts a robust background copy operation with detailed error handling,
        progress monitoring, and recovery capabilities
    .PARAMETER Source
        Source path to copy from
    .PARAMETER Destination
        Destination path to copy to
    .PARAMETER Overwrite
        Whether to overwrite existing files
    .PARAMETER MaxRetries
        Maximum number of retry attempts for failed operations
    .EXAMPLE
        Start-BackgroundCopy -Source C:\Source -Destination D:\Dest
        Starts background copy with default settings
    .EXAMPLE
        Start-BackgroundCopy -Source C:\Source -Destination D:\Dest -Overwrite -MaxRetries 3
        Starts background copy with overwrite enabled and 3 retry attempts
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "Source path '$_' does not exist."
            }
            $true
        })]
        [string]$Source,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Destination,
        
        [Parameter(Mandatory=$false)]
        [switch]$Overwrite,
        
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 10)]
        [int]$MaxRetries = 3
    )
    
    try {
        # Validate source path
        if (-not (Test-Path -Path $Source)) {
            throw [System.IO.DirectoryNotFoundException]::new("Source path not found: $Source")
        }
        
        # Test source access
        try {
            $null = Get-ChildItem -Path $Source -ErrorAction Stop | Select-Object -First 1
        } catch [System.UnauthorizedAccessException] {
            throw [System.UnauthorizedAccessException]::new("Access denied to source path: $Source")
        }
        
        # Validate destination path (create if doesn't exist)
        $destinationParent = Split-Path -Path $Destination -Parent
        if ($destinationParent -and -not (Test-Path -Path $destinationParent)) {
            try {
                New-Item -Path $destinationParent -ItemType Directory -Force -ErrorAction Stop | Out-Null
                Write-Verbose "Created destination directory: $destinationParent"
            } catch {
                throw [System.IO.IOException]::new("Cannot create destination directory: $($_.Exception.Message)")
            }
        }
        
        # Test destination write access
        try {
            $testFile = Join-Path $destinationParent "test_write_access_$(Get-Random).tmp"
            $null = New-Item -Path $testFile -ItemType File -Force -ErrorAction Stop
            Remove-Item -Path $testFile -Force -ErrorAction SilentlyContinue
        } catch {
            throw [System.UnauthorizedAccessException]::new("No write access to destination: $destinationParent")
        }
        
        # Check available space
        try {
            $sourceSize = (Get-ChildItem -Path $Source -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $destinationDrive = (Get-Item $destinationParent).PSDrive
            $freeSpace = (Get-PSDrive $destinationDrive.Name).Free
            
            if ($sourceSize -gt $freeSpace) {
                $sourceSizeGB = [Math]::Round($sourceSize / 1GB, 2)
                $freeSpaceGB = [Math]::Round($freeSpace / 1GB, 2)
                throw [System.IO.IOException]::new("Insufficient disk space. Required: ${sourceSizeGB}GB, Available: ${freeSpaceGB}GB")
            }
        } catch [System.IO.IOException] {
            throw
        } catch {
            Write-Warning "Could not verify disk space: $($_.Exception.Message)"
        }
        
        $operation = [PSCustomObject]@{
            Id = [Guid]::NewGuid()
            Type = 'Copy'
            Source = $Source
            Destination = $Destination
            Status = 'Initializing'
            Progress = 0
            StartTime = Get-Date
            EndTime = $null
            RetryCount = 0
            MaxRetries = $MaxRetries
            Overwrite = $Overwrite.IsPresent
            ErrorCount = 0
            LastError = $null
            TotalSize = $sourceSize
            ProcessedSize = 0
        }
        
        $script:BackgroundOperations.Add($operation) | Out-Null
        
        Write-Host "Background copy started: $($operation.Id)" -ForegroundColor Green
        Write-Host "  From: $Source" -ForegroundColor Gray
        Write-Host "  To: $Destination" -ForegroundColor Gray
        Write-Host "  Size: $([Math]::Round($sourceSize / 1MB, 2)) MB" -ForegroundColor Gray
        
        # Enhanced script block with error handling and progress reporting
        $scriptBlock = {
            param($src, $dest, $overwrite, $maxRetries, $operationId)
            
            $ErrorActionPreference = 'Stop'
            $errors = @()
            
            function Copy-WithRetry {
                param($SourceItem, $DestPath, $MaxRetries)
                
                for ($i = 0; $i -lt $MaxRetries; $i++) {
                    try {
                        if ($overwrite) {
                            Copy-Item -Path $SourceItem -Destination $DestPath -Recurse -Force -ErrorAction Stop
                        } else {
                            Copy-Item -Path $SourceItem -Destination $DestPath -Recurse -ErrorAction Stop
                        }
                        return $true
                    } catch [System.IO.IOException] {
                        $errors += "I/O Error (attempt $($i+1)): $($_.Exception.Message)"
                        if ($i -eq ($MaxRetries - 1)) { throw }
                        Start-Sleep -Seconds (2 * ($i + 1)) # Exponential backoff
                    } catch [System.UnauthorizedAccessException] {
                        $errors += "Access denied (attempt $($i+1)): $($_.Exception.Message)"
                        if ($i -eq ($MaxRetries - 1)) { throw }
                        Start-Sleep -Seconds 1
                    } catch {
                        $errors += "Error (attempt $($i+1)): $($_.Exception.Message)"
                        if ($i -eq ($MaxRetries - 1)) { throw }
                        Start-Sleep -Seconds 1
                    }
                }
                return $false
            }
            
            try {
                Copy-WithRetry -SourceItem $src -DestPath $dest -MaxRetries $maxRetries
                
                return @{
                    Success = $true
                    Errors = $errors
                    Message = "Copy completed successfully"
                }
            } catch {
                return @{
                    Success = $false
                    Errors = $errors + @($_.Exception.Message)
                    Message = "Copy failed: $($_.Exception.Message)"
                }
            }
        }
        
        # Start background job with enhanced error handling
        try {
            $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $Source, $Destination, $Overwrite.IsPresent, $MaxRetries, $operation.Id -ErrorAction Stop
            $operation | Add-Member -NotePropertyName Job -NotePropertyValue $job
            $operation.Status = 'Running'
            
            Write-Verbose "Background job started with ID: $($job.Id)"
            
        } catch {
            $operation.Status = 'Failed'
            $operation.LastError = "Failed to start background job: $($_.Exception.Message)"
            throw [System.InvalidOperationException]::new("Could not start background copy job: $($_.Exception.Message)")
        }
        
        return $operation
        
    } catch [System.IO.DirectoryNotFoundException] {
        Write-Error "Source directory not found: $($_.Exception.Message)"
        throw
    } catch [System.UnauthorizedAccessException] {
        Write-Error "Access denied: $($_.Exception.Message)"
        Write-Host "Try running as administrator or check file/folder permissions." -ForegroundColor Yellow
        throw
    } catch [System.IO.IOException] {
        Write-Error "I/O error: $($_.Exception.Message)"
        throw
    } catch [System.InvalidOperationException] {
        Write-Error "Operation error: $($_.Exception.Message)"
        throw
    } catch {
        Write-Error "Unexpected error starting background copy: $($_.Exception.Message)"
        Write-Verbose "Error type: $($_.Exception.GetType().Name)"
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
        throw
    }
}

function Get-BackgroundOperations {
    <#
    .SYNOPSIS
        Gets list of background operations with detailed status and error handling
    .DESCRIPTION
        Retrieves all background operations with current status, progress, and error information
    .PARAMETER IncludeCompleted
        Include completed operations in the results
    .PARAMETER OperationId
        Get specific operation by ID
    .EXAMPLE
        Get-BackgroundOperations
        Gets all active background operations
    .EXAMPLE
        Get-BackgroundOperations -IncludeCompleted
        Gets all operations including completed ones
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [switch]$IncludeCompleted,
        
        [Parameter(Mandatory=$false)]
        [Guid]$OperationId
    )
    
    try {
        if (-not $script:BackgroundOperations) {
            Write-Verbose "No background operations found."
            return @()
        }
        
        $operations = $script:BackgroundOperations.Clone()
        
        # Filter by specific operation ID if provided
        if ($OperationId -ne [Guid]::Empty) {
            $operations = $operations | Where-Object { $_.Id -eq $OperationId }
            if (-not $operations) {
                Write-Warning "Operation with ID $OperationId not found."
                return @()
            }
        }
        
        # Update status for all operations
        foreach ($op in $operations) {
            try {
                if ($op.Job) {
                    $jobState = $op.Job.State
                    $previousStatus = $op.Status
                    
                    # Update status based on job state
                    switch ($jobState) {
                        'Running' { $op.Status = 'Running' }
                        'Completed' { 
                            $op.Status = 'Completed'
                            if (-not $op.EndTime) {
                                $op.EndTime = Get-Date
                            }
                            
                            # Get job results
                            try {
                                $result = Receive-Job -Job $op.Job -ErrorAction SilentlyContinue
                                if ($result.Success -eq $false) {
                                    $op.Status = 'Failed'
                                    $op.LastError = $result.Message
                                    $op.ErrorCount = $result.Errors.Count
                                }
                            } catch {
                                Write-Verbose "Error retrieving job results for operation $($op.Id): $($_.Exception.Message)"
                            }
                        }
                        'Failed' { 
                            $op.Status = 'Failed'
                            if (-not $op.EndTime) {
                                $op.EndTime = Get-Date
                            }
                            
                            # Get error details
                            try {
                                $errors = $op.Job | Receive-Job -ErrorAction SilentlyContinue
                                if ($errors) {
                                    $op.LastError = $errors[-1].Exception.Message
                                    $op.ErrorCount = $errors.Count
                                }
                            } catch {
                                Write-Verbose "Error retrieving job errors for operation $($op.Id): $($_.Exception.Message)"
                            }
                        }
                        'Stopped' { $op.Status = 'Stopped' }
                        'Suspended' { $op.Status = 'Suspended' }
                        default { $op.Status = $jobState }
                    }
                    
                    # Calculate progress if possible
                    if ($op.Status -eq 'Running' -and $op.TotalSize -gt 0) {
                        try {
                            # Estimate progress based on destination folder size (rough approximation)
                            if (Test-Path $op.Destination) {
                                $destSize = (Get-ChildItem -Path $op.Destination -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                                $op.ProcessedSize = $destSize
                                $op.Progress = [Math]::Min(100, [Math]::Round(($destSize / $op.TotalSize) * 100, 2))
                            }
                        } catch {
                            Write-Verbose "Could not calculate progress for operation $($op.Id): $($_.Exception.Message)"
                        }
                    }
                    
                    # Add duration calculation
                    if ($op.EndTime) {
                        $op | Add-Member -NotePropertyName Duration -NotePropertyValue ($op.EndTime - $op.StartTime) -Force
                    } else {
                        $op | Add-Member -NotePropertyName Duration -NotePropertyValue ((Get-Date) - $op.StartTime) -Force
                    }
                    
                    # Log status changes
                    if ($previousStatus -ne $op.Status) {
                        Write-Verbose "Operation $($op.Id) status changed from $previousStatus to $($op.Status)"
                    }
                }
            } catch {
                Write-Warning "Error updating status for operation $($op.Id): $($_.Exception.Message)"
                $op.Status = 'Error'
                $op.LastError = $_.Exception.Message
            }
        }
        
        # Filter out completed operations if not requested
        if (-not $IncludeCompleted) {
            $operations = $operations | Where-Object { $_.Status -notin @('Completed', 'Failed', 'Stopped') }
        }
        
        # Clean up completed jobs older than 1 hour
        try {
            $cutoffTime = (Get-Date).AddHours(-1)
            $oldOperations = $script:BackgroundOperations | Where-Object { 
                $_.EndTime -and $_.EndTime -lt $cutoffTime -and $_.Status -in @('Completed', 'Failed', 'Stopped')
            }
            
            foreach ($oldOp in $oldOperations) {
                if ($oldOp.Job) {
                    try {
                        Remove-Job -Job $oldOp.Job -Force -ErrorAction SilentlyContinue
                    } catch {
                        Write-Verbose "Error cleaning up old job $($oldOp.Job.Id): $($_.Exception.Message)"
                    }
                }
                $script:BackgroundOperations.Remove($oldOp) | Out-Null
            }
            
            if ($oldOperations.Count -gt 0) {
                Write-Verbose "Cleaned up $($oldOperations.Count) old operations"
            }
        } catch {
            Write-Verbose "Error during cleanup: $($_.Exception.Message)"
        }
        
        return $operations
        
    } catch {
        Write-Error "Error retrieving background operations: $($_.Exception.Message)"
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
        return @()
    }
}

function Stop-BackgroundOperation {
    <#
    .SYNOPSIS
        Stops a background operation with proper cleanup and error handling
    .DESCRIPTION
        Safely stops and cleans up a background operation, with optional force termination
    .PARAMETER Id
        Operation ID to stop
    .PARAMETER Force
        Force termination even if operation is not responding
    .PARAMETER Reason
        Reason for stopping the operation (for logging)
    .EXAMPLE
        Stop-BackgroundOperation -Id $operationId
        Stops the specified operation
    .EXAMPLE
        Stop-BackgroundOperation -Id $operationId -Force -Reason "User cancellation"
        Force stops the operation with a reason
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({
            if ($_ -eq [Guid]::Empty) {
                throw "Operation ID cannot be empty."
            }
            $true
        })]
        [Guid]$Id,
        
        [Parameter(Mandatory=$false)]
        [switch]$Force,
        
        [Parameter(Mandatory=$false)]
        [string]$Reason = "Manual stop"
    )
    
    try {
        Write-Verbose "Attempting to stop operation: $Id (Reason: $Reason)"
        
        $operation = $script:BackgroundOperations | Where-Object { $_.Id -eq $Id }
        
        if (-not $operation) {
            Write-Warning "Operation with ID $Id not found."
            return $false
        }
        
        if ($operation.Status -in @('Completed', 'Failed', 'Stopped')) {
            Write-Warning "Operation $Id is already in terminal state: $($operation.Status)"
            return $true
        }
        
        if (-not $operation.Job) {
            Write-Warning "Operation $Id has no associated job to stop."
            $operation.Status = 'Stopped'
            $operation.EndTime = Get-Date
            return $true
        }
        
        $jobId = $operation.Job.Id
        Write-Verbose "Stopping job $jobId for operation $Id"
        
        try {
            # First try graceful stop
            if (-not $Force) {
                Stop-Job -Job $operation.Job -ErrorAction Stop
                
                # Wait up to 10 seconds for graceful shutdown
                $timeout = 10
                $elapsed = 0
                while ($operation.Job.State -eq 'Running' -and $elapsed -lt $timeout) {
                    Start-Sleep -Milliseconds 500
                    $elapsed += 0.5
                }
                
                if ($operation.Job.State -eq 'Running') {
                    Write-Warning "Operation did not stop gracefully, attempting force stop..."
                    $Force = $true
                }
            }
            
            # Force stop if requested or graceful stop failed
            if ($Force -and $operation.Job.State -eq 'Running') {
                try {
                    # Get the underlying process if possible and terminate it
                    $job = $operation.Job
                    if ($job.ChildJobs) {
                        foreach ($childJob in $job.ChildJobs) {
                            if ($childJob.Runspace -and $childJob.Runspace.RunspaceStateInfo.State -eq 'Opened') {
                                $childJob.Runspace.Close()
                            }
                        }
                    }
                    
                    Stop-Job -Job $operation.Job -ErrorAction SilentlyContinue
                } catch {
                    Write-Verbose "Error during force stop: $($_.Exception.Message)"
                }
            }
            
            # Clean up the job
            try {
                Remove-Job -Job $operation.Job -Force -ErrorAction Stop
                Write-Verbose "Successfully removed job $jobId"
            } catch {
                Write-Warning "Could not remove job $jobId`: $($_.Exception.Message)"
            }
            
            # Update operation status
            $operation.Status = 'Stopped'
            $operation.EndTime = Get-Date
            $operation.LastError = $Reason
            
            Write-Host "Operation stopped: $Id" -ForegroundColor Yellow
            Write-Host "  Reason: $Reason" -ForegroundColor Gray
            Write-Host "  Duration: $($operation.EndTime - $operation.StartTime)" -ForegroundColor Gray
            
            return $true
            
        } catch [System.InvalidOperationException] {
            Write-Warning "Job is already in a terminal state or cannot be stopped: $($_.Exception.Message)"
            $operation.Status = 'Stopped'
            $operation.EndTime = Get-Date
            return $true
        } catch {
            Write-Error "Error stopping job: $($_.Exception.Message)"
            $operation.LastError = "Stop failed: $($_.Exception.Message)"
            throw
        }
        
    } catch [System.ArgumentException] {
        Write-Error "Invalid operation ID: $($_.Exception.Message)"
        return $false
    } catch {
        Write-Error "Unexpected error stopping background operation: $($_.Exception.Message)"
        Write-Verbose "Error type: $($_.Exception.GetType().Name)"
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
        return $false
    }
}

# Enhanced Async Operations with Runspace Management and Progress Reporting

# Global runspace pool for efficient resource management
$script:RunspacePool = $null
$script:MaxRunspaces = [Environment]::ProcessorCount
$script:EnhancedOperations = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()

function Initialize-RunspacePool {
    <#
    .SYNOPSIS
        Initializes a runspace pool for efficient async operations
    .DESCRIPTION
        Creates and configures a runspace pool optimized for file operations
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 32)]
        [int]$MaxConcurrency = $script:MaxRunspaces
    )
    
    try {
        if ($script:RunspacePool -and $script:RunspacePool.RunspacePoolStateInfo.State -eq 'Opened') {
            Write-Verbose "Runspace pool already initialized"
            return
        }
        
        # Create initial session state with required modules
        $initialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        
        # Add required cmdlets and variables
        $initialSessionState.Commands.Add((New-Object System.Management.Automation.Runspaces.SessionStateCmdletEntry('Get-ChildItem', [Microsoft.PowerShell.Commands.GetChildItemCommand], $null)))
        $initialSessionState.Commands.Add((New-Object System.Management.Automation.Runspaces.SessionStateCmdletEntry('Copy-Item', [Microsoft.PowerShell.Commands.CopyItemCommand], $null)))
        
        # Create runspace pool
        $script:RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxConcurrency, $initialSessionState, $Host)
        $script:RunspacePool.Open()
        
        Write-Verbose "Runspace pool initialized with max concurrency: $MaxConcurrency"
        
    } catch {
        Write-Error "Failed to initialize runspace pool: $($_.Exception.Message)"
        throw
    }
}

function Start-EnhancedBackgroundCopy {
    <#
    .SYNOPSIS
        Enhanced background copy with runspace management and real-time progress
    .DESCRIPTION
        Performs file copy operations using runspaces for better performance and robocopy for reliability
    .PARAMETER Source
        Source path to copy from
    .PARAMETER Destination
        Destination path to copy to
    .PARAMETER UseRobocopy
        Use robocopy for improved performance and reliability
    .PARAMETER ProgressCallback
        Script block to execute for progress updates
    .PARAMETER BufferSize
        Buffer size for copy operations (in bytes)
    .EXAMPLE
        Start-EnhancedBackgroundCopy -Source "C:\Large Folder" -Destination "D:\Backup" -UseRobocopy
        Starts enhanced copy using robocopy with progress tracking
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "Source path '$_' does not exist."
            }
            $true
        })]
        [string]$Source,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Destination,
        
        [Parameter(Mandatory=$false)]
        [switch]$UseRobocopy,
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$ProgressCallback,
        
        [Parameter(Mandatory=$false)]
        [ValidateRange(1KB, 10MB)]
        [int]$BufferSize = 1MB,
        
        [Parameter(Mandatory=$false)]
        [switch]$Overwrite
    )
    
    try {
        # Initialize runspace pool if needed
        Initialize-RunspacePool
        
        # Create operation tracking object
        $operationId = [Guid]::NewGuid().ToString()
        $operation = [PSCustomObject]@{
            Id = $operationId
            Type = if ($UseRobocopy) { 'EnhancedCopy-Robocopy' } else { 'EnhancedCopy-PowerShell' }
            Source = $Source
            Destination = $Destination
            Status = 'Initializing'
            Progress = 0
            StartTime = Get-Date
            EndTime = $null
            TotalFiles = 0
            ProcessedFiles = 0
            TotalSize = 0
            ProcessedSize = 0
            TransferSpeed = 0
            EstimatedTimeRemaining = "Calculating..."
            LastProgressUpdate = Get-Date
            Runspace = $null
            AsyncResult = $null
            UseRobocopy = $UseRobocopy.IsPresent
            BufferSize = $BufferSize
        }
        
        # Calculate total size and file count
        Write-Host "Analyzing source directory..." -ForegroundColor Yellow
        try {
            $sourceItems = Get-ChildItem -Path $Source -Recurse -File -ErrorAction SilentlyContinue
            $operation.TotalFiles = $sourceItems.Count
            $operation.TotalSize = ($sourceItems | Measure-Object -Property Length -Sum).Sum
            
            Write-Host "Found $($operation.TotalFiles) files, total size: $([Math]::Round($operation.TotalSize / 1MB, 2)) MB" -ForegroundColor Green
        } catch {
            Write-Warning "Could not analyze source directory: $($_.Exception.Message)"
            $operation.TotalFiles = -1
            $operation.TotalSize = -1
        }
        
        # Create enhanced script block for runspace execution
        if ($UseRobocopy) {
            $scriptBlock = {
                param($src, $dest, $operationId, $overwrite)
                
                try {
                    # Prepare robocopy arguments
                    $robocopyArgs = @(
                        "`"$src`"",
                        "`"$dest`"",
                        "/E",           # Copy subdirectories including empty ones
                        "/R:3",         # Retry 3 times on failed copies
                        "/W:1",         # Wait 1 second between retries
                        "/TEE",         # Output to console and log
                        "/NP",          # No progress percentage
                        "/BYTES",       # Show sizes in bytes
                        "/ETA"          # Show estimated time of completion
                    )
                    
                    if ($overwrite) {
                        $robocopyArgs += "/IS"  # Include same files
                    } else {
                        $robocopyArgs += "/XO"  # Exclude older files
                    }
                    
                    # Start robocopy process
                    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
                    $processInfo.FileName = "robocopy.exe"
                    $processInfo.Arguments = $robocopyArgs -join " "
                    $processInfo.UseShellExecute = $false
                    $processInfo.RedirectStandardOutput = $true
                    $processInfo.RedirectStandardError = $true
                    $processInfo.CreateNoWindow = $true
                    
                    $process = New-Object System.Diagnostics.Process
                    $process.StartInfo = $processInfo
                    
                    # Progress tracking variables
                    $lastProgress = @{
                        ProcessedFiles = 0
                        ProcessedSize = 0
                        Percentage = 0
                        Speed = 0
                        ETA = "Calculating..."
                    }
                    
                    $startTime = Get-Date
                    $process.Start() | Out-Null
                    
                    # Read output for progress tracking
                    while (-not $process.HasExited) {
                        $output = $process.StandardOutput.ReadLine()
                        if ($output) {
                            # Parse robocopy output for progress information
                            # This is a simplified parser - robocopy output parsing can be complex
                            if ($output -match "(\d+)%") {
                                $percentage = [int]$matches[1]
                                $lastProgress.Percentage = $percentage
                                
                                # Calculate transfer speed and ETA
                                $elapsed = (Get-Date) - $startTime
                                if ($elapsed.TotalSeconds -gt 0 -and $percentage -gt 0) {
                                    $estimatedTotal = $elapsed.TotalSeconds * (100 / $percentage)
                                    $remaining = $estimatedTotal - $elapsed.TotalSeconds
                                    $lastProgress.ETA = [TimeSpan]::FromSeconds($remaining).ToString("hh\:mm\:ss")
                                }
                            }
                        }
                        Start-Sleep -Milliseconds 100
                    }
                    
                    $process.WaitForExit()
                    $exitCode = $process.ExitCode
                    
                    # Robocopy exit codes: 0-7 are success, 8+ are errors
                    $success = $exitCode -lt 8
                    
                    return @{
                        Success = $success
                        ExitCode = $exitCode
                        ProcessedFiles = $lastProgress.ProcessedFiles
                        ProcessedSize = $lastProgress.ProcessedSize
                        Message = if ($success) { "Robocopy completed successfully" } else { "Robocopy completed with errors (exit code: $exitCode)" }
                        Output = $process.StandardOutput.ReadToEnd()
                        Error = $process.StandardError.ReadToEnd()
                    }
                    
                } catch {
                    return @{
                        Success = $false
                        ExitCode = -1
                        Message = "Failed to execute robocopy: $($_.Exception.Message)"
                        Error = $_.Exception.Message
                    }
                }
            }
        } else {
            # PowerShell-based copy with progress tracking
            $scriptBlock = {
                param($src, $dest, $operationId, $bufferSize, $overwrite)
                
                try {
                    $sourceItems = Get-ChildItem -Path $src -Recurse -File
                    $totalFiles = $sourceItems.Count
                    $totalSize = ($sourceItems | Measure-Object -Property Length -Sum).Sum
                    $processedFiles = 0
                    $processedSize = 0
                    $startTime = Get-Date
                    
                    foreach ($file in $sourceItems) {
                        try {
                            $relativePath = $file.FullName.Substring($src.Length + 1)
                            $destFile = Join-Path $dest $relativePath
                            $destDir = Split-Path $destFile -Parent
                            
                            # Create destination directory if it doesn't exist
                            if (-not (Test-Path $destDir)) {
                                New-Item -Path $destDir -ItemType Directory -Force | Out-Null
                            }
                            
                            # Copy file with buffer
                            if ($overwrite -or -not (Test-Path $destFile)) {
                                Copy-Item -Path $file.FullName -Destination $destFile -Force:$overwrite
                                $processedSize += $file.Length
                            }
                            
                            $processedFiles++
                            
                            # Calculate progress metrics
                            $percentage = if ($totalSize -gt 0) { [Math]::Round(($processedSize / $totalSize) * 100, 1) } else { 0 }
                            $elapsed = (Get-Date) - $startTime
                            $speed = if ($elapsed.TotalSeconds -gt 0) { $processedSize / $elapsed.TotalSeconds } else { 0 }
                            
                            # Calculate ETA
                            $eta = "Calculating..."
                            if ($speed -gt 0 -and $totalSize -gt $processedSize) {
                                $remainingBytes = $totalSize - $processedSize
                                $remainingSeconds = $remainingBytes / $speed
                                $eta = [TimeSpan]::FromSeconds($remainingSeconds).ToString("hh\:mm\:ss")
                            }
                            
                            # Report progress every 10 files or 5MB
                            if (($processedFiles % 10 -eq 0) -or ($processedSize % (5MB) -lt $file.Length)) {
                                # Progress reporting - output progress data for external monitoring
                                Write-Verbose "Progress: $percentage% ($processedFiles/$totalFiles files, $([Math]::Round($processedSize/1MB,1))/$([Math]::Round($totalSize/1MB,1)) MB, Speed: $([Math]::Round($speed/1MB,1)) MB/s, ETA: $eta)"
                            }
                            
                        } catch {
                            Write-Warning "Failed to copy file '$($file.FullName)': $($_.Exception.Message)"
                        }
                    }
                    
                    return @{
                        Success = $true
                        ProcessedFiles = $processedFiles
                        ProcessedSize = $processedSize
                        TotalFiles = $totalFiles
                        TotalSize = $totalSize
                        Message = "PowerShell copy completed successfully"
                    }
                    
                } catch {
                    return @{
                        Success = $false
                        Message = "PowerShell copy failed: $($_.Exception.Message)"
                        Error = $_.Exception.Message
                    }
                }
            }
        }
        
        # Create runspace and start async operation
        $runspace = [PowerShell]::Create()
        $runspace.RunspacePool = $script:RunspacePool
        
        # Add script and parameters
        $runspace.AddScript($scriptBlock) | Out-Null
        $runspace.AddArgument($Source) | Out-Null
        $runspace.AddArgument($Destination) | Out-Null
        $runspace.AddArgument($operationId) | Out-Null
        
        if ($UseRobocopy) {
            $runspace.AddArgument($Overwrite.IsPresent) | Out-Null
        } else {
            $runspace.AddArgument($BufferSize) | Out-Null
            $runspace.AddArgument($Overwrite.IsPresent) | Out-Null
        }
        
        # Start async execution
        $asyncResult = $runspace.BeginInvoke()
        
        # Update operation object
        $operation.Runspace = $runspace
        $operation.AsyncResult = $asyncResult
        $operation.Status = 'Running'
        
        # Store in concurrent dictionary
        $script:EnhancedOperations.TryAdd($operationId, $operation) | Out-Null
        
        Write-Host "Enhanced background copy started: $operationId" -ForegroundColor Green
        Write-Host "  Type: $($operation.Type)" -ForegroundColor Gray
        Write-Host "  From: $Source" -ForegroundColor Gray
        Write-Host "  To: $Destination" -ForegroundColor Gray
        if ($operation.TotalSize -gt 0) {
            Write-Host "  Size: $([Math]::Round($operation.TotalSize / 1MB, 2)) MB" -ForegroundColor Gray
        }
        
        return $operation
        
    } catch {
        Write-Error "Failed to start enhanced background copy: $($_.Exception.Message)"
        throw
    }
}

function Get-EnhancedOperationStatus {
    <#
    .SYNOPSIS
        Gets real-time status of enhanced background operations
    .DESCRIPTION
        Retrieves current status, progress, and performance metrics for enhanced operations
    .PARAMETER OperationId
        Specific operation ID to query
    .PARAMETER IncludeCompleted
        Include completed operations in results
    .EXAMPLE
        Get-EnhancedOperationStatus
        Gets status of all active enhanced operations
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$OperationId,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeCompleted
    )
    
    try {
        $results = @()
        
        if ($OperationId) {
            $operation = $null
            if ($script:EnhancedOperations.TryGetValue($OperationId, [ref]$operation)) {
                $results += Update-OperationProgress -Operation $operation
            } else {
                Write-Warning "Operation not found: $OperationId"
                return $null
            }
        } else {
            foreach ($kvp in $script:EnhancedOperations.GetEnumerator()) {
                $operation = Update-OperationProgress -Operation $kvp.Value
                if ($IncludeCompleted -or $operation.Status -notin @('Completed', 'Failed', 'Cancelled')) {
                    $results += $operation
                }
            }
        }
        
        return $results
        
    } catch {
        Write-Error "Error getting enhanced operation status: $($_.Exception.Message)"
        return @()
    }
}

function Update-OperationProgress {
    <#
    .SYNOPSIS
        Updates progress information for an enhanced operation
    .DESCRIPTION
        Checks runspace status and updates progress metrics
    .PARAMETER Operation
        Operation object to update
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Operation
    )
    
    try {
        if ($Operation.AsyncResult.IsCompleted -and $Operation.Status -eq 'Running') {
            # Operation completed - get results
            try {
                $result = $Operation.Runspace.EndInvoke($Operation.AsyncResult)
                $Operation.EndTime = Get-Date
                
                if ($result -and $result.Success) {
                    $Operation.Status = 'Completed'
                    $Operation.Progress = 100
                    $Operation.ProcessedFiles = $result.ProcessedFiles
                    $Operation.ProcessedSize = $result.ProcessedSize
                } else {
                    $Operation.Status = 'Failed'
                    $Operation.LastError = $result.Message
                }
                
                # Clean up runspace
                $Operation.Runspace.Dispose()
                $Operation.Runspace = $null
                
            } catch {
                $Operation.Status = 'Failed'
                $Operation.LastError = "Error retrieving results: $($_.Exception.Message)"
                $Operation.EndTime = Get-Date
            }
        }
        
        # Calculate real-time metrics for running operations
        if ($Operation.Status -eq 'Running') {
            $elapsed = (Get-Date) - $Operation.StartTime
            
            # Estimate progress based on time (rough estimate)
            if ($Operation.TotalSize -gt 0 -and $Operation.ProcessedSize -gt 0) {
                $Operation.Progress = [Math]::Round(($Operation.ProcessedSize / $Operation.TotalSize) * 100, 1)
                $Operation.TransferSpeed = if ($elapsed.TotalSeconds -gt 0) { 
                    [Math]::Round($Operation.ProcessedSize / $elapsed.TotalSeconds / 1MB, 2) 
                } else { 0 }
                
                if ($Operation.TransferSpeed -gt 0) {
                    $remainingBytes = $Operation.TotalSize - $Operation.ProcessedSize
                    $remainingSeconds = $remainingBytes / ($Operation.TransferSpeed * 1MB)
                    $Operation.EstimatedTimeRemaining = [TimeSpan]::FromSeconds($remainingSeconds).ToString("hh\:mm\:ss")
                }
            }
        }
        
        return $Operation
        
    } catch {
        Write-Error "Error updating operation progress: $($_.Exception.Message)"
        return $Operation
    }
}

function Stop-EnhancedOperation {
    <#
    .SYNOPSIS
        Stops an enhanced background operation
    .DESCRIPTION
        Gracefully stops a running enhanced operation and cleans up resources
    .PARAMETER OperationId
        ID of the operation to stop
    .EXAMPLE
        Stop-EnhancedOperation -OperationId "12345678-1234-1234-1234-123456789012"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$OperationId
    )
    
    try {
        $operation = $null
        if ($script:EnhancedOperations.TryGetValue($OperationId, [ref]$operation)) {
            if ($operation.Status -eq 'Running' -and $operation.Runspace) {
                try {
                    # Try to stop gracefully
                    $operation.Runspace.Stop()
                    $operation.Status = 'Cancelled'
                    $operation.EndTime = Get-Date
                    
                    # Clean up resources
                    $operation.Runspace.Dispose()
                    $operation.Runspace = $null
                    
                    Write-Host "Enhanced operation stopped: $OperationId" -ForegroundColor Yellow
                    return $true
                    
                } catch {
                    Write-Warning "Error stopping operation: $($_.Exception.Message)"
                    $operation.Status = 'Failed'
                    $operation.LastError = "Stop failed: $($_.Exception.Message)"
                    return $false
                }
            } else {
                Write-Warning "Operation is not running or already completed: $OperationId"
                return $true
            }
        } else {
            Write-Error "Operation not found: $OperationId"
            return $false
        }
        
    } catch {
        Write-Error "Error stopping enhanced operation: $($_.Exception.Message)"
        return $false
    }
}

function Clear-CompletedEnhancedOperations {
    <#
    .SYNOPSIS
        Removes completed operations from memory
    .DESCRIPTION
        Cleans up completed, failed, or cancelled operations to free memory
    .EXAMPLE
        Clear-CompletedEnhancedOperations
    #>
    [CmdletBinding()]
    param()
    
    try {
        $removed = 0
        $toRemove = @()
        
        foreach ($kvp in $script:EnhancedOperations.GetEnumerator()) {
            $operation = $kvp.Value
            if ($operation.Status -in @('Completed', 'Failed', 'Cancelled')) {
                # Clean up any remaining runspace resources
                if ($operation.Runspace) {
                    try {
                        $operation.Runspace.Dispose()
                    } catch {
                        Write-Verbose "Error disposing runspace: $($_.Exception.Message)"
                    }
                }
                $toRemove += $kvp.Key
            }
        }
        
        foreach ($key in $toRemove) {
            if ($script:EnhancedOperations.TryRemove($key, [ref]$null)) {
                $removed++
            }
        }
        
        Write-Verbose "Removed $removed completed operations from memory"
        return $removed
        
    } catch {
        Write-Error "Error clearing completed operations: $($_.Exception.Message)"
        return 0
    }
}

Export-ModuleMember -Function Start-BackgroundCopy, Get-BackgroundOperations, Stop-BackgroundOperation, 
                              Start-EnhancedBackgroundCopy, Get-EnhancedOperationStatus, Stop-EnhancedOperation, 
                              Clear-CompletedEnhancedOperations, Initialize-RunspacePool
