#Requires -Version 7.0

# Logging Module - Centralized logging system for error tracking and debugging

$script:LogPath = if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
    Join-Path $env:APPDATA "PowerShellFileManager\Logs"
} else {
    Join-Path $HOME ".config/PowerShellFileManager/logs"
}

$script:LogFile = Join-Path $script:LogPath "FileManager_$(Get-Date -Format 'yyyy-MM-dd').log"
$script:LogLevel = 'Info'
$script:MaxLogFiles = 30
$script:MaxLogSizeMB = 10

# Initialize logging
function Initialize-FileManagerLogging {
    <#
    .SYNOPSIS
        Initializes the logging system
    .DESCRIPTION
        Sets up log directory and configures logging parameters
    .PARAMETER LogLevel
        Minimum log level to record (Debug, Info, Warning, Error)
    .PARAMETER MaxLogFiles
        Maximum number of log files to retain
    .PARAMETER MaxLogSizeMB
        Maximum size of each log file in MB
    .EXAMPLE
        Initialize-FileManagerLogging -LogLevel Info -MaxLogFiles 30
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet('Debug', 'Info', 'Warning', 'Error')]
        [string]$LogLevel = 'Info',
        
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 100)]
        [int]$MaxLogFiles = 30,
        
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 100)]
        [int]$MaxLogSizeMB = 10
    )
    
    try {
        # Create log directory if it doesn't exist
        if (-not (Test-Path $script:LogPath)) {
            New-Item -Path $script:LogPath -ItemType Directory -Force | Out-Null
        }
        
        $script:LogLevel = $LogLevel
        $script:MaxLogFiles = $MaxLogFiles
        $script:MaxLogSizeMB = $MaxLogSizeMB
        
        # Clean up old log files
        Remove-OldLogFiles
        
        # Write initialization message
        Write-FileManagerLog -Level Info -Message "FileManager logging initialized" -Category "System"
        Write-FileManagerLog -Level Info -Message "Log Level: $LogLevel, Max Files: $MaxLogFiles, Max Size: ${MaxLogSizeMB}MB" -Category "System"
        
    } catch {
        Write-Warning "Failed to initialize logging: $($_.Exception.Message)"
    }
}

function Write-FileManagerLog {
    <#
    .SYNOPSIS
        Writes a log entry with comprehensive error handling
    .DESCRIPTION
        Centralized logging function with automatic rotation and error handling
    .PARAMETER Level
        Log level (Debug, Info, Warning, Error)
    .PARAMETER Message
        Log message
    .PARAMETER Category
        Optional category for the log entry
    .PARAMETER Exception
        Optional exception object for detailed error logging
    .PARAMETER FunctionName
        Name of the calling function
    .EXAMPLE
        Write-FileManagerLog -Level Error -Message "Failed to copy file" -Category "FileOperations" -Exception $_
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Debug', 'Info', 'Warning', 'Error')]
        [string]$Level,
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [string]$Category = "General",
        
        [Parameter(Mandatory=$false)]
        [System.Exception]$Exception,
        
        [Parameter(Mandatory=$false)]
        [string]$FunctionName = (Get-PSCallStack)[1].FunctionName
    )
    
    try {
        # Check if we should log this level
        $levels = @('Debug', 'Info', 'Warning', 'Error')
        $currentLevelIndex = $levels.IndexOf($script:LogLevel)
        $messageLevelIndex = $levels.IndexOf($Level)
        
        if ($messageLevelIndex -lt $currentLevelIndex) {
            return
        }
        
        # Ensure log directory exists
        if (-not (Test-Path $script:LogPath)) {
            New-Item -Path $script:LogPath -ItemType Directory -Force | Out-Null
        }
        
        # Check if log file needs rotation
        if (Test-Path $script:LogFile) {
            $logSize = (Get-Item $script:LogFile).Length / 1MB
            if ($logSize -gt $script:MaxLogSizeMB) {
                Move-LogFileToBackup
            }
        }
        
        # Build log entry
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $processId = $PID
        $threadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        
        $logEntry = "[$timestamp] [$Level] [$Category] [PID:$processId] [TID:$threadId] [$FunctionName] $Message"
        
        # Add exception details if provided
        if ($Exception) {
            $logEntry += "`n    Exception: $($Exception.GetType().Name): $($Exception.Message)"
            if ($Exception.InnerException) {
                $logEntry += "`n    Inner Exception: $($Exception.InnerException.GetType().Name): $($Exception.InnerException.Message)"
            }
            if ($Exception.StackTrace) {
                $logEntry += "`n    Stack Trace: $($Exception.StackTrace)"
            }
        }
        
        # Write to log file with file locking
        $retryCount = 0
        $maxRetries = 3
        
        while ($retryCount -lt $maxRetries) {
            try {
                # Use Add-Content with file locking
                Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8 -ErrorAction Stop
                break
            } catch [System.IO.IOException] {
                $retryCount++
                if ($retryCount -ge $maxRetries) {
                    # Last resort: write to console
                    Write-Host "LOG WRITE FAILED: $logEntry" -ForegroundColor Red
                    break
                }
                Start-Sleep -Milliseconds (100 * $retryCount)
            }
        }
        
        # Also write to console for Warning and Error levels
        if ($Level -in @('Warning', 'Error')) {
            $color = if ($Level -eq 'Warning') { 'Yellow' } else { 'Red' }
            Write-Host "[$Level] $Message" -ForegroundColor $color
        } elseif ($Level -eq 'Debug' -and $VerbosePreference -ne 'SilentlyContinue') {
            Write-Verbose "[$Level] $Message"
        }
        
    } catch {
        # Fallback error handling - write to console if logging fails
        Write-Host "LOGGING ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Original message: [$Level] $Message" -ForegroundColor Yellow
    }
}

function Get-FileManagerLogs {
    <#
    .SYNOPSIS
        Retrieves log entries with filtering options
    .DESCRIPTION
        Reads and filters log entries from the current log file
    .PARAMETER Level
        Filter by log level
    .PARAMETER Category
        Filter by category
    .PARAMETER Last
        Number of last entries to retrieve
    .PARAMETER Since
        Get logs since specified datetime
    .EXAMPLE
        Get-FileManagerLogs -Level Error -Last 50
        Gets last 50 error entries
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet('Debug', 'Info', 'Warning', 'Error')]
        [string]$Level,
        
        [Parameter(Mandatory=$false)]
        [string]$Category,
        
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 10000)]
        [int]$Last,
        
        [Parameter(Mandatory=$false)]
        [DateTime]$Since
    )
    
    try {
        if (-not (Test-Path $script:LogFile)) {
            Write-Warning "Log file not found: $script:LogFile"
            return @()
        }
        
        $logEntries = Get-Content -Path $script:LogFile -ErrorAction Stop
        $parsedLogs = @()
        
        foreach ($entry in $logEntries) {
            if ($entry -match '^\[(.+?)\] \[(.+?)\] \[(.+?)\] \[PID:(\d+)\] \[TID:(\d+)\] \[(.+?)\] (.+)$') {
                $parsedLog = [PSCustomObject]@{
                    Timestamp = [DateTime]::ParseExact($Matches[1], "yyyy-MM-dd HH:mm:ss.fff", $null)
                    Level = $Matches[2]
                    Category = $Matches[3]
                    ProcessId = [int]$Matches[4]
                    ThreadId = [int]$Matches[5]
                    FunctionName = $Matches[6]
                    Message = $Matches[7]
                    RawEntry = $entry
                }
                $parsedLogs += $parsedLog
            }
        }
        
        # Apply filters
        $filteredLogs = $parsedLogs
        
        if ($Level) {
            $filteredLogs = $filteredLogs | Where-Object { $_.Level -eq $Level }
        }
        
        if ($Category) {
            $filteredLogs = $filteredLogs | Where-Object { $_.Category -like "*$Category*" }
        }
        
        if ($Since) {
            $filteredLogs = $filteredLogs | Where-Object { $_.Timestamp -gt $Since }
        }
        
        # Apply Last filter
        if ($Last) {
            $filteredLogs = $filteredLogs | Select-Object -Last $Last
        }
        
        return $filteredLogs
        
    } catch {
        Write-Error "Error reading log file: $($_.Exception.Message)"
        return @()
    }
}

function Remove-OldLogFiles {
    <#
    .SYNOPSIS
        Cleans up old log files
    .DESCRIPTION
        Removes log files older than the retention period
    #>
    [CmdletBinding()]
    param()
    
    try {
        if (-not (Test-Path $script:LogPath)) {
            return
        }
        
        $logFiles = Get-ChildItem -Path $script:LogPath -Filter "FileManager_*.log" -ErrorAction SilentlyContinue
        
        if ($logFiles.Count -gt $script:MaxLogFiles) {
            $filesToDelete = $logFiles | Sort-Object LastWriteTime | Select-Object -First ($logFiles.Count - $script:MaxLogFiles)
            
            foreach ($file in $filesToDelete) {
                try {
                    Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                    Write-Verbose "Deleted old log file: $($file.Name)"
                } catch {
                    Write-Warning "Could not delete log file $($file.Name): $($_.Exception.Message)"
                }
            }
        }
        
    } catch {
        Write-Warning "Error during log cleanup: $($_.Exception.Message)"
    }
}

function Move-LogFileToBackup {
    <#
    .SYNOPSIS
        Rotates the current log file
    .DESCRIPTION
        Moves the current log file to a timestamped backup and starts a new log
    #>
    [CmdletBinding()]
    param()
    
    try {
        if (Test-Path $script:LogFile) {
            $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
            $backupFile = $script:LogFile -replace "\.log$", "_$timestamp.log"
            
            Move-Item -Path $script:LogFile -Destination $backupFile -Force -ErrorAction Stop
            Write-Verbose "Rotated log file to: $backupFile"
        }
        
    } catch {
        Write-Warning "Error rotating log file: $($_.Exception.Message)"
    }
}

function Write-Log {
    <#
    .SYNOPSIS
        Simplified logging facade for File Manager operations
    .DESCRIPTION
        Routes log messages to UI console and rolling file log with correlation IDs
    .PARAMETER Level
        Log level (Trace, Debug, Info, Warn, Error)
    .PARAMETER Message
        Log message content
    .PARAMETER OperationId
        Optional operation ID for correlation
    .EXAMPLE
        Write-Log -Level Info -Message "File copied successfully" -OperationId $opId
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Trace', 'Debug', 'Info', 'Warn', 'Error')]
        [string]$Level,
        
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        $OperationId
    )
    
    # Map simplified levels to full levels
    $mappedLevel = switch ($Level) {
        'Trace' { 'Debug' }
        'Warn' { 'Warning' }
        default { $Level }
    }
    
    # Build enhanced message with operation ID if provided
    $enhancedMessage = if ($OperationId) {
        "[OpId:$OperationId] $Message"
    } else {
        $Message
    }
    
    # Get calling function from stack
    $callingFunction = (Get-PSCallStack)[1].FunctionName
    
    # Route to existing logging infrastructure
    Write-FileManagerLog -Level $mappedLevel -Message $enhancedMessage -FunctionName $callingFunction
}

# Auto-initialize logging when module is imported
Initialize-FileManagerLogging

Export-ModuleMember -Function Initialize-FileManagerLogging, Write-FileManagerLog, Get-FileManagerLogs, Remove-OldLogFiles, Move-LogFileToBackup, Write-Log