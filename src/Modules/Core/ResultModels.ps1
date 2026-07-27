#Requires -Version 7.0

# Result Models Module
# Strongly-typed records for UI binding and data consistency

class DirectoryEntry {
    [string]$Name
    [string]$FullName
    [string]$Extension
    [long]$Size
    [datetime]$LastWriteTime
    [datetime]$CreationTime
    [bool]$IsDirectory
    [string]$Attributes
    [string]$DisplaySize
    
    DirectoryEntry([System.IO.FileSystemInfo]$item) {
        $this.Name = $item.Name
        $this.FullName = $item.FullName
        $this.Extension = $item.Extension
        $this.LastWriteTime = $item.LastWriteTime
        $this.CreationTime = $item.CreationTime
        $this.IsDirectory = $item.PSIsContainer
        $this.Attributes = $item.Attributes.ToString()
        
        if ($item.PSIsContainer) {
            $this.Size = 0
            $this.DisplaySize = "<DIR>"
        }
        else {
            $this.Size = $item.Length
            $this.DisplaySize = $this.FormatSize($item.Length)
        }
    }
    
    hidden [string] FormatSize([long]$bytes) {
        if ($bytes -ge 1TB) { return "{0:N2} TB" -f ($bytes / 1TB) }
        elseif ($bytes -ge 1GB) { return "{0:N2} GB" -f ($bytes / 1GB) }
        elseif ($bytes -ge 1MB) { return "{0:N2} MB" -f ($bytes / 1MB) }
        elseif ($bytes -ge 1KB) { return "{0:N2} KB" -f ($bytes / 1KB) }
        else { return "$bytes bytes" }
    }
}

class OperationRecord {
    [guid]$Id
    [string]$Type
    [string]$Path
    [string]$DestinationPath
    [string]$Status
    [double]$Progress
    [datetime]$StartTime
    [object]$EndTime
    [string]$ErrorMessage
    [hashtable]$Metadata
    
    OperationRecord([string]$type, [string]$path) {
        $this.Id = [guid]::NewGuid()
        $this.Type = $type
        $this.Path = $path
        $this.Status = "Queued"
        $this.Progress = 0
        $this.StartTime = Get-Date
        $this.Metadata = @{}
    }
    
    [void] Start() {
        $this.Status = "Running"
        $this.StartTime = Get-Date
    }
    
    [void] Complete() {
        $this.Status = "Completed"
        $this.Progress = 100
        $this.EndTime = Get-Date
    }
    
    [void] Fail([string]$errorMessage) {
        $this.Status = "Failed"
        $this.ErrorMessage = $errorMessage
        $this.EndTime = Get-Date
    }
    
    [void] Cancel() {
        $this.Status = "Cancelled"
        $this.EndTime = Get-Date
    }
    
    [timespan] GetDuration() {
        if ($this.EndTime) {
            return $this.EndTime - $this.StartTime
        }
        else {
            return (Get-Date) - $this.StartTime
        }
    }
}

class SearchResult {
    [string]$Path
    [string]$Name
    [string]$Extension
    [long]$Size
    [datetime]$LastModified
    [double]$MatchScore
    [string]$MatchReason
    [hashtable]$Metadata
    
    SearchResult([string]$path) {
        $this.Path = $path
        $this.Name = Split-Path $path -Leaf
        $this.Extension = [System.IO.Path]::GetExtension($path)
        $this.MatchScore = 1.0
        $this.Metadata = @{}
        
        if (Test-Path $path) {
            $item = Get-Item $path
            $this.Size = if ($item.PSIsContainer) { 0 } else { $item.Length }
            $this.LastModified = $item.LastWriteTime
        }
    }
}

class FileIntegrityRecord {
    [string]$Path
    [string]$Hash
    [string]$Algorithm
    [datetime]$BaselineDate
    [bool]$IsValid
    [datetime]$LastChecked
    [string]$Status
    
    FileIntegrityRecord([string]$path, [string]$hash, [string]$algorithm) {
        $this.Path = $path
        $this.Hash = $hash
        $this.Algorithm = $algorithm
        $this.BaselineDate = Get-Date
        $this.IsValid = $true
        $this.LastChecked = Get-Date
        $this.Status = "Baseline"
    }
    
    [bool] Verify([string]$currentHash) {
        $this.LastChecked = Get-Date
        $this.IsValid = ($this.Hash -eq $currentHash)
        $this.Status = if ($this.IsValid) { "Valid" } else { "Modified" }
        return $this.IsValid
    }
}

class PluginInfo {
    [string]$Name
    [string]$Version
    [string]$Author
    [string]$Description
    [string[]]$SupportedFileTypes
    [string]$Path
    [bool]$IsLoaded
    [datetime]$LoadedAt
    [hashtable]$Configuration
    
    PluginInfo([string]$name, [string]$path) {
        $this.Name = $name
        $this.Path = $path
        $this.IsLoaded = $false
        $this.Configuration = @{}
        $this.SupportedFileTypes = @()
    }
}

class CacheEntry {
    [string]$Key
    [object]$Value
    [datetime]$Created
    [datetime]$LastAccessed
    [int]$AccessCount
    [string]$Category
    
    CacheEntry([string]$key, [object]$value, [string]$category = "General") {
        $this.Key = $key
        $this.Value = $value
        $this.Created = Get-Date
        $this.LastAccessed = Get-Date
        $this.AccessCount = 0
        $this.Category = $category
    }
    
    [void] Access() {
        $this.LastAccessed = Get-Date
        $this.AccessCount++
    }
    
    [bool] IsExpired([int]$expiryMinutes) {
        return ((Get-Date) - $this.Created).TotalMinutes -gt $expiryMinutes
    }
}

class PerformanceMetric {
    [string]$Operation
    [datetime]$Timestamp
    [double]$DurationMs
    [long]$MemoryUsedBytes
    [int]$ItemsProcessed
    [string]$Status
    [hashtable]$Details
    
    PerformanceMetric([string]$operation) {
        $this.Operation = $operation
        $this.Timestamp = Get-Date
        $this.Status = "Started"
        $this.Details = @{}
    }
    
    [void] Complete([int]$itemsProcessed) {
        $this.ItemsProcessed = $itemsProcessed
        $this.Status = "Completed"
        $this.DurationMs = ((Get-Date) - $this.Timestamp).TotalMilliseconds
    }
}

function New-DirectoryEntry {
    <#
    .SYNOPSIS
        Creates a new DirectoryEntry object
    .DESCRIPTION
        Wraps a FileSystemInfo object in a DirectoryEntry for consistent UI binding
    .PARAMETER Item
        FileSystemInfo object to wrap
    .EXAMPLE
        $entry = New-DirectoryEntry -Item (Get-Item "C:\test.txt")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.IO.FileSystemInfo]$Item
    )
    
    process {
        [DirectoryEntry]::new($Item)
    }
}

function New-OperationRecord {
    <#
    .SYNOPSIS
        Creates a new OperationRecord
    .DESCRIPTION
        Creates a tracking record for file operations
    .PARAMETER Type
        Type of operation (Copy, Move, Delete, etc.)
    .PARAMETER Path
        Path being operated on
    .EXAMPLE
        $record = New-OperationRecord -Type "Copy" -Path "C:\source.txt"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Type,
        
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    [OperationRecord]::new($Type, $Path)
}

Export-ModuleMember -Function New-DirectoryEntry, New-OperationRecord
