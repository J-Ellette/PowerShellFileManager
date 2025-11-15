#Requires -Version 7.0

# Advanced Search Module - Regex search, saved searches, caching & indexing

# Global file index and cache variables
$script:FileIndex = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
$script:DirectoryCache = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
$script:LastIndexUpdate = $null
$script:CacheExpiryMinutes = 30
$script:MaxCacheSize = 100MB
$script:IndexingInProgress = $false

# Cached metadata structure
class FileMetadata {
    [string] $FullPath
    [string] $Name
    [string] $Extension
    [long] $Size
    [DateTime] $LastWriteTime
    [DateTime] $CreationTime
    [DateTime] $LastAccessTime
    [string] $Directory
    [bool] $IsReadOnly
    [bool] $IsHidden
    [bool] $IsSystem
    [string] $Hash
    [hashtable] $CustomProperties
    [DateTime] $IndexedTime
    
    FileMetadata([System.IO.FileInfo] $fileInfo) {
        $this.FullPath = $fileInfo.FullName
        $this.Name = $fileInfo.Name
        $this.Extension = $fileInfo.Extension
        $this.Size = $fileInfo.Length
        $this.LastWriteTime = $fileInfo.LastWriteTime
        $this.CreationTime = $fileInfo.CreationTime
        $this.LastAccessTime = $fileInfo.LastAccessTime
        $this.Directory = $fileInfo.Directory.FullName
        $this.IsReadOnly = $fileInfo.IsReadOnly
        $this.IsHidden = $fileInfo.Attributes -band [System.IO.FileAttributes]::Hidden
        $this.IsSystem = $fileInfo.Attributes -band [System.IO.FileAttributes]::System
        $this.CustomProperties = @{}
        $this.IndexedTime = Get-Date
    }
}

function Update-FileIndex {
    <#
    .SYNOPSIS
        Builds or updates the searchable file index
    .DESCRIPTION
        Creates a comprehensive index of file metadata for faster searches
    .PARAMETER Path
        Path to index (defaults to current directory)
    .PARAMETER Force
        Force rebuild of existing index
    .PARAMETER IncludeHash
        Calculate and include file hashes (slower but more comprehensive)
    .PARAMETER MaxDepth
        Maximum directory depth to index
    .EXAMPLE
        Update-FileIndex -Path "C:\Projects" -IncludeHash
        Builds index with file hashes for the Projects directory
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "Path '$_' does not exist."
            }
            $true
        })]
        [string]$Path = $PWD.Path,
        
        [Parameter(Mandatory=$false)]
        [switch]$Force,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeHash,
        
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 20)]
        [int]$MaxDepth = 10
    )
    
    try {
        if ($script:IndexingInProgress) {
            Write-Warning "Indexing already in progress. Please wait..."
            return
        }
        
        $script:IndexingInProgress = $true
        Write-Host "Building file index for: $Path" -ForegroundColor Cyan
        
        # Check if index exists and is recent enough
        $indexKey = $Path.ToLowerInvariant()
        $existingIndex = $null
        
        if ($script:DirectoryCache.TryGetValue($indexKey, [ref]$existingIndex) -and -not $Force) {
            $indexAge = (Get-Date) - $existingIndex.LastUpdated
            if ($indexAge.TotalMinutes -lt $script:CacheExpiryMinutes) {
                Write-Host "Using cached index (age: $([Math]::Round($indexAge.TotalMinutes, 1)) minutes)" -ForegroundColor Green
                return $existingIndex
            }
        }
        
        # Start indexing
        $startTime = Get-Date
        $processedFiles = 0
        $indexedFiles = @{}
        
        Write-Host "Scanning directory structure..." -ForegroundColor Yellow
        
        # Get all files with depth limit
        $basePath = $Path.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        $files = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | 
                 Where-Object { 
                     try {
                         $relativePath = $_.FullName.Substring($basePath.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
                         $depth = if ($relativePath) { ($relativePath -split [regex]::Escape([IO.Path]::DirectorySeparatorChar)).Count - 1 } else { 0 }
                         $depth -le $MaxDepth
                     } catch {
                         Write-Verbose "Error calculating depth for $($_.FullName): $($_.Exception.Message)"
                         $true  # Include the file if we can't calculate depth
                     }
                 }
        
        $totalFiles = $files.Count
        Write-Host "Found $totalFiles files to index..." -ForegroundColor Yellow
        
        foreach ($file in $files) {
            try {
                $metadata = [FileMetadata]::new($file)
                
                # Calculate hash if requested and file is not too large
                if ($IncludeHash -and $file.Length -lt 50MB) {
                    try {
                        $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256 -ErrorAction Stop
                        $metadata.Hash = $hash.Hash
                    } catch {
                        Write-Verbose "Could not calculate hash for $($file.FullName): $($_.Exception.Message)"
                        $metadata.Hash = $null
                    }
                }
                
                # Add to file index
                $script:FileIndex.AddOrUpdate($file.FullName, $metadata, { param($k, $v) $metadata })
                $indexedFiles[$file.FullName] = $metadata
                
                $processedFiles++
                
                # Progress reporting every 100 files
                if ($processedFiles % 100 -eq 0) {
                    $percentComplete = [Math]::Round(($processedFiles / $totalFiles) * 100, 1)
                    Write-Host "Progress: $percentComplete% ($processedFiles/$totalFiles files)" -ForegroundColor Gray
                }
                
            } catch {
                Write-Verbose "Error indexing file $($file.FullName): $($_.Exception.Message)"
            }
        }
        
        # Create directory cache entry
        $directoryIndex = [PSCustomObject]@{
            Path = $Path
            LastUpdated = Get-Date
            FileCount = $indexedFiles.Count
            TotalSize = ($indexedFiles.Values | Measure-Object -Property Size -Sum).Sum
            IndexedFiles = $indexedFiles
            IncludesHash = $IncludeHash.IsPresent
            IndexDuration = (Get-Date) - $startTime
        }
        
        # Update cache
        $script:DirectoryCache.AddOrUpdate($indexKey, $directoryIndex, { param($k, $v) $directoryIndex })
        $script:LastIndexUpdate = Get-Date
        
        $duration = (Get-Date) - $startTime
        Write-Host "`n✓ Index completed!" -ForegroundColor Green
        Write-Host "  Files indexed: $($indexedFiles.Count)" -ForegroundColor Gray
        Write-Host "  Total size: $([Math]::Round($directoryIndex.TotalSize / 1MB, 2)) MB" -ForegroundColor Gray
        Write-Host "  Duration: $($duration.TotalSeconds.ToString('F1')) seconds" -ForegroundColor Gray
        Write-Host "  Hash calculation: $(if ($IncludeHash) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Gray
        
        # Cleanup old cache entries if needed
        Optimize-FileCache
        
        return $directoryIndex
        
    } catch {
        Write-Error "Error building file index: $($_.Exception.Message)"
        throw
    } finally {
        $script:IndexingInProgress = $false
    }
}

function Search-IndexedFiles {
    <#
    .SYNOPSIS
        Fast search using the file index
    .DESCRIPTION
        Searches indexed files using various criteria with high performance
    .PARAMETER Pattern
        Search pattern for file names (supports regex)
    .PARAMETER Path
        Path to search within
    .PARAMETER Extension
        File extension filter
    .PARAMETER SizeMin
        Minimum file size in bytes
    .PARAMETER SizeMax
        Maximum file size in bytes
    .PARAMETER ModifiedAfter
        Files modified after this date
    .PARAMETER ModifiedBefore
        Files modified before this date
    .PARAMETER Hash
        Specific file hash to find
    .EXAMPLE
        Search-IndexedFiles -Pattern "*.log" -SizeMin 1MB
        Finds log files larger than 1MB using the index
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Pattern,
        
        [Parameter(Mandatory=$false)]
        [string]$Path = $PWD.Path,
        
        [Parameter(Mandatory=$false)]
        [string]$Extension,
        
        [Parameter(Mandatory=$false)]
        [long]$SizeMin = 0,
        
        [Parameter(Mandatory=$false)]
        [long]$SizeMax = [long]::MaxValue,
        
        [Parameter(Mandatory=$false)]
        [DateTime]$ModifiedAfter = [DateTime]::MinValue,
        
        [Parameter(Mandatory=$false)]
        [DateTime]$ModifiedBefore = [DateTime]::MaxValue,
        
        [Parameter(Mandatory=$false)]
        [string]$Hash
    )
    
    try {
        $indexKey = $Path.ToLowerInvariant()
        $directoryIndex = $null
        
        if (-not $script:DirectoryCache.TryGetValue($indexKey, [ref]$directoryIndex)) {
            Write-Host "No index found for path: $Path" -ForegroundColor Yellow
            Write-Host "Building index first..." -ForegroundColor Cyan
            $directoryIndex = Update-FileIndex -Path $Path
        }
        
        # Check if index is stale
        $indexAge = (Get-Date) - $directoryIndex.LastUpdated
        if ($indexAge.TotalMinutes -gt $script:CacheExpiryMinutes) {
            Write-Host "Index is stale (age: $([Math]::Round($indexAge.TotalMinutes, 1)) minutes), updating..." -ForegroundColor Yellow
            $directoryIndex = Update-FileIndex -Path $Path
        }
        
        Write-Host "Searching $($directoryIndex.FileCount) indexed files..." -ForegroundColor Cyan
        $startTime = Get-Date
        
        # Apply filters
        $results = $directoryIndex.IndexedFiles.Values | Where-Object {
            $isMatch = $true
            
            # Pattern filter (name-based)
            if ($Pattern -and $isMatch) {
                $isMatch = $_.Name -match $Pattern
            }
            
            # Extension filter
            if ($Extension -and $isMatch) {
                $isMatch = $_.Extension -eq $Extension
            }
            
            # Size filters
            if ($isMatch) {
                $isMatch = $_.Size -ge $SizeMin -and $_.Size -le $SizeMax
            }
            
            # Date filters
            if ($isMatch) {
                $isMatch = $_.LastWriteTime -ge $ModifiedAfter -and $_.LastWriteTime -le $ModifiedBefore
            }
            
            # Hash filter
            if ($Hash -and $isMatch) {
                $isMatch = $_.Hash -eq $Hash
            }
            
            return $isMatch
        }
        
        $searchDuration = (Get-Date) - $startTime
        
        Write-Host "`n✓ Search completed in $($searchDuration.TotalMilliseconds.ToString('F0'))ms" -ForegroundColor Green
        Write-Host "Found $($results.Count) matches" -ForegroundColor Green
        
        # Display results
        if ($results.Count -gt 0) {
            $results | Sort-Object LastWriteTime -Descending | 
                Select-Object Name, 
                          @{N='Size'; E={Format-FileSize $_.Size}}, 
                          LastWriteTime, 
                          Directory |
                Format-Table -AutoSize
        }
        
        return $results
        
    } catch {
        Write-Error "Error searching indexed files: $($_.Exception.Message)"
        throw
    }
}

function Get-FileIndexStatistics {
    <#
    .SYNOPSIS
        Gets statistics about the file index and cache
    .DESCRIPTION
        Returns information about index size, cache usage, and performance metrics
    .EXAMPLE
        Get-FileIndexStatistics
        Shows current index and cache statistics
    #>
    [CmdletBinding()]
    param()
    
    try {
        $totalIndexedFiles = $script:FileIndex.Count
        $totalDirectories = $script:DirectoryCache.Count
        $totalCacheSize = 0
        $oldestIndex = [DateTime]::MaxValue
        $newestIndex = [DateTime]::MinValue
        
        # Calculate cache statistics
        foreach ($entry in $script:DirectoryCache.Values) {
            $totalCacheSize += $entry.TotalSize
            if ($entry.LastUpdated -lt $oldestIndex) { $oldestIndex = $entry.LastUpdated }
            if ($entry.LastUpdated -gt $newestIndex) { $newestIndex = $entry.LastUpdated }
        }
        
        $stats = [PSCustomObject]@{
            TotalIndexedFiles = $totalIndexedFiles
            CachedDirectories = $totalDirectories
            TotalCacheSize = Format-FileSize $totalCacheSize
            CacheExpiryMinutes = $script:CacheExpiryMinutes
            LastIndexUpdate = $script:LastIndexUpdate
            OldestIndex = if ($oldestIndex -ne [DateTime]::MaxValue) { $oldestIndex } else { $null }
            NewestIndex = if ($newestIndex -ne [DateTime]::MinValue) { $newestIndex } else { $null }
            IndexingInProgress = $script:IndexingInProgress
            CacheDirectories = ($script:DirectoryCache.Keys | Sort-Object)
        }
        
        # Display formatted statistics
        Write-Host "`n📊 File Index Statistics" -ForegroundColor Green
        Write-Host "========================" -ForegroundColor Green
        Write-Host "Total indexed files: $($stats.TotalIndexedFiles)" -ForegroundColor Cyan
        Write-Host "Cached directories: $($stats.CachedDirectories)" -ForegroundColor Cyan
        Write-Host "Total cache size: $($stats.TotalCacheSize)" -ForegroundColor Cyan
        Write-Host "Cache expiry: $($stats.CacheExpiryMinutes) minutes" -ForegroundColor Cyan
        Write-Host "Last update: $($stats.LastIndexUpdate)" -ForegroundColor Cyan
        Write-Host "Indexing active: $($stats.IndexingInProgress)" -ForegroundColor Cyan
        
        if ($stats.CacheDirectories.Count -gt 0) {
            Write-Host "`nCached Directories:" -ForegroundColor Yellow
            $stats.CacheDirectories | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        }
        
        return $stats
        
    } catch {
        Write-Error "Error getting index statistics: $($_.Exception.Message)"
        throw
    }
}

function Clear-FileCache {
    <#
    .SYNOPSIS
        Clears the file index and cache
    .DESCRIPTION
        Removes cached file metadata to free memory or force rebuild
    .PARAMETER Path
        Specific path to clear (clears all if not specified)
    .EXAMPLE
        Clear-FileCache
        Clears entire file cache
    .EXAMPLE
        Clear-FileCache -Path "C:\Projects"
        Clears cache for specific directory
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Path
    )
    
    try {
        if ($Path) {
            $indexKey = $Path.ToLowerInvariant()
            $removed = $script:DirectoryCache.TryRemove($indexKey, [ref]$null)
            
            # Remove associated file entries
            $filesToRemove = $script:FileIndex.Keys | Where-Object { $_.StartsWith($Path, [StringComparison]::OrdinalIgnoreCase) }
            $fileCount = 0
            foreach ($file in $filesToRemove) {
                if ($script:FileIndex.TryRemove($file, [ref]$null)) {
                    $fileCount++
                }
            }
            
            if ($removed) {
                Write-Host "✓ Cleared cache for path: $Path" -ForegroundColor Green
                Write-Host "  Removed $fileCount file entries" -ForegroundColor Gray
            } else {
                Write-Warning "No cache found for path: $Path"
            }
        } else {
            # Clear everything
            $directoryCount = $script:DirectoryCache.Count
            $fileCount = $script:FileIndex.Count
            
            $script:DirectoryCache.Clear()
            $script:FileIndex.Clear()
            $script:LastIndexUpdate = $null
            
            Write-Host "✓ Cleared entire file cache" -ForegroundColor Green
            Write-Host "  Removed $directoryCount directory caches" -ForegroundColor Gray
            Write-Host "  Removed $fileCount file entries" -ForegroundColor Gray
            
            # Force garbage collection
            [System.GC]::Collect()
        }
        
    } catch {
        Write-Error "Error clearing file cache: $($_.Exception.Message)"
        throw
    }
}

function Optimize-FileCache {
    <#
    .SYNOPSIS
        Optimizes the file cache by removing old entries
    .DESCRIPTION
        Removes expired cache entries and manages memory usage
    .EXAMPLE
        Optimize-FileCache
        Removes expired cache entries
    #>
    [CmdletBinding()]
    param()
    
    try {
        $removed = 0
        $now = Get-Date
        $toRemove = @()
        
        # Find expired entries
        foreach ($kvp in $script:DirectoryCache.GetEnumerator()) {
            $age = $now - $kvp.Value.LastUpdated
            if ($age.TotalMinutes -gt $script:CacheExpiryMinutes) {
                $toRemove += $kvp.Key
            }
        }
        
        # Remove expired entries
        foreach ($key in $toRemove) {
            if ($script:DirectoryCache.TryRemove($key, [ref]$null)) {
                $removed++
            }
        }
        
        # Clean up orphaned file entries
        $validPaths = $script:DirectoryCache.Values | ForEach-Object { $_.Path.ToLowerInvariant() }
        $orphanedFiles = $script:FileIndex.Keys | Where-Object {
            $filePath = $_.ToLowerInvariant()
            $hasValidParent = $false
            foreach ($validPath in $validPaths) {
                if ($filePath.StartsWith($validPath)) {
                    $hasValidParent = $true
                    break
                }
            }
            return -not $hasValidParent
        }
        
        $orphanedCount = 0
        foreach ($orphanFile in $orphanedFiles) {
            if ($script:FileIndex.TryRemove($orphanFile, [ref]$null)) {
                $orphanedCount++
            }
        }
        
        if ($removed -gt 0 -or $orphanedCount -gt 0) {
            Write-Host "✓ Cache optimization completed" -ForegroundColor Green
            Write-Host "  Removed $removed expired directory caches" -ForegroundColor Gray
            Write-Host "  Removed $orphanedCount orphaned file entries" -ForegroundColor Gray
        }
        
    } catch {
        Write-Error "Error optimizing file cache: $($_.Exception.Message)"
        throw
    }
}

function Sync-Directories {
    <#
    .SYNOPSIS
        Synchronizes two directories with options
    .DESCRIPTION
        Compares and synchronizes files between source and destination directories
    .PARAMETER Source
        Source directory path
    .PARAMETER Destination
        Destination directory path
    .PARAMETER WhatIf
        Show what would be synchronized without making changes
    .PARAMETER DeleteExtra
        Delete files in destination that don't exist in source
    .EXAMPLE
        Sync-Directories -Source "C:\Source" -Destination "D:\Backup" -WhatIf
        Shows what would be synchronized
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
        [switch]$WhatIf,
        
        [Parameter(Mandatory=$false)]
        [switch]$DeleteExtra
    )
    
    try {
        Write-Host "Synchronizing directories..." -ForegroundColor Cyan
        Write-Host "Source: $Source" -ForegroundColor Gray
        Write-Host "Destination: $Destination" -ForegroundColor Gray
        
        # Index both directories
        Write-Host "Indexing source directory..." -ForegroundColor Yellow
        $sourceIndex = Update-FileIndex -Path $Source -IncludeHash
        
        if (Test-Path $Destination) {
            Write-Host "Indexing destination directory..." -ForegroundColor Yellow
            $destIndex = Update-FileIndex -Path $Destination -IncludeHash
        } else {
            Write-Host "Creating destination directory..." -ForegroundColor Yellow
            New-Item -Path $Destination -ItemType Directory -Force | Out-Null
            $destIndex = $null
        }
        
        # Compare and sync
        $syncActions = @()
        $sourceFiles = $sourceIndex.IndexedFiles
        $destFiles = if ($destIndex) { $destIndex.IndexedFiles } else { @{} }
        
        # Normalize base paths
        $sourceBase = $Source.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        $destBase = $Destination.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        
        # Find files to copy/update
        foreach ($sourceFile in $sourceFiles.Values) {
            $relativePath = $sourceFile.FullPath.Substring($sourceBase.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
            $destPath = Join-Path $Destination $relativePath
            
            $action = $null
            if (-not (Test-Path $destPath)) {
                $action = "Copy (New)"
            } else {
                $destMetadata = $destFiles[$destPath]
                if ($destMetadata) {
                    if ($sourceFile.Hash -and $destMetadata.Hash -and $sourceFile.Hash -ne $destMetadata.Hash) {
                        $action = "Copy (Changed)"
                    } elseif ($sourceFile.LastWriteTime -gt $destMetadata.LastWriteTime) {
                        $action = "Copy (Newer)"
                    }
                }
            }
            
            if ($action) {
                $syncActions += [PSCustomObject]@{
                    Action = $action
                    Source = $sourceFile.FullPath
                    Destination = $destPath
                    Size = $sourceFile.Size
                }
            }
        }
        
        # Find files to delete (if requested)
        if ($DeleteExtra -and $destFiles.Count -gt 0) {
            foreach ($destFile in $destFiles.Values) {
                $relativePath = $destFile.FullPath.Substring($destBase.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
                $sourcePath = Join-Path $Source $relativePath
                
                if (-not (Test-Path $sourcePath)) {
                    $syncActions += [PSCustomObject]@{
                        Action = "Delete (Extra)"
                        Source = ""
                        Destination = $destFile.FullPath
                        Size = $destFile.Size
                    }
                }
            }
        }
        
        # Display sync plan
        Write-Host "`nSync Plan:" -ForegroundColor Green
        if ($syncActions.Count -eq 0) {
            Write-Host "No changes needed - directories are in sync!" -ForegroundColor Green
            return
        }
        
        $syncActions | Group-Object Action | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Count) files" -ForegroundColor Cyan
        }
        
        $totalSize = ($syncActions | Where-Object { $_.Action -like "Copy*" } | Measure-Object Size -Sum).Sum
        Write-Host "  Total size to copy: $(Format-FileSize $totalSize)" -ForegroundColor Cyan
        
        if ($WhatIf) {
            Write-Host "`nDetailed actions (WhatIf mode):" -ForegroundColor Yellow
            $syncActions | Format-Table Action, @{N='File'; E={Split-Path $_.Destination -Leaf}}, @{N='Size'; E={Format-FileSize $_.Size}} -AutoSize
            return
        }
        
        # Execute sync
        $confirmed = Read-Host "`nProceed with synchronization? (y/N)"
        if ($confirmed -eq 'y' -or $confirmed -eq 'Y') {
            Write-Host "Executing synchronization..." -ForegroundColor Yellow
            
            foreach ($action in $syncActions) {
                try {
                    switch -Wildcard ($action.Action) {
                        "Copy*" {
                            $destDir = Split-Path $action.Destination -Parent
                            if (-not (Test-Path $destDir)) {
                                New-Item -Path $destDir -ItemType Directory -Force | Out-Null
                            }
                            Copy-Item -Path $action.Source -Destination $action.Destination -Force
                            Write-Host "✓ $($action.Action): $(Split-Path $action.Destination -Leaf)" -ForegroundColor Green
                        }
                        "Delete*" {
                            Remove-Item -Path $action.Destination -Force
                            Write-Host "✓ $($action.Action): $(Split-Path $action.Destination -Leaf)" -ForegroundColor Red
                        }
                    }
                } catch {
                    Write-Warning "Failed $($action.Action): $($action.Destination) - $($_.Exception.Message)"
                }
            }
            
            Write-Host "`n✓ Synchronization completed!" -ForegroundColor Green
        } else {
            Write-Host "Synchronization cancelled." -ForegroundColor Yellow
        }
        
    } catch {
        Write-Error "Error synchronizing directories: $($_.Exception.Message)"
        throw
    }
}

# Helper function for file size formatting
function Format-FileSize {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    } elseif ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    } elseif ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    } else {
        return "$Bytes bytes"
    }
}

function Search-Files {
    <#
    .SYNOPSIS
        Advanced file search with regex
    .DESCRIPTION
        Searches files by name, content, or properties using regex
    .PARAMETER Path
        Base path to search
    .PARAMETER Pattern
        Search pattern (regex)
    .PARAMETER ContentSearch
        Search file contents
    .EXAMPLE
        Search-Files -Path C:\ -Pattern "\.log$"
        Finds all log files
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [string]$Pattern,
        
        [Parameter(Mandatory=$false)]
        [switch]$ContentSearch,
        
        [Parameter(Mandatory=$false)]
        [switch]$CaseSensitive
    )
    
    Write-Host "Searching in: $Path" -ForegroundColor Cyan
    Write-Host "Pattern: $Pattern" -ForegroundColor Gray
    
    if ($ContentSearch) {
        Write-Host "Searching file contents..." -ForegroundColor Yellow
        
        $results = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | 
            Where-Object { 
                try {
                    (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match $Pattern
                } catch {
                    $false
                }
            }
    } else {
        $results = Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue | 
            Where-Object { $_.Name -match $Pattern }
    }
    
    Write-Host "`nFound $($results.Count) matches" -ForegroundColor Green
    $results | Format-Table Name, FullName, Length, LastWriteTime -AutoSize
    
    return $results
}

function Save-SearchQuery {
    <#
    .SYNOPSIS
        Saves a search query for reuse
    .PARAMETER Name
        Query name
    .PARAMETER Query
        Search query
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [scriptblock]$Query
    )
    
    $configPath = if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
        Join-Path $env:APPDATA "PowerShellFileManager/SavedSearches"
    } else {
        Join-Path $HOME ".config/PowerShellFileManager/SavedSearches"
    }
    if (-not (Test-Path $configPath)) {
        New-Item -ItemType Directory -Path $configPath -Force | Out-Null
    }
    
    $queryPath = Join-Path $configPath "$Name.ps1"
    $Query.ToString() | Out-File -FilePath $queryPath -Encoding UTF8
    
    Write-Host "Search query saved: $Name" -ForegroundColor Green
}

function Get-SavedSearches {
    <#
    .SYNOPSIS
        Lists saved search queries
    #>
    [CmdletBinding()]
    param()
    
    $configPath = if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
        Join-Path $env:APPDATA "PowerShellFileManager/SavedSearches"
    } else {
        Join-Path $HOME ".config/PowerShellFileManager/SavedSearches"
    }
    if (Test-Path $configPath) {
        $searches = Get-ChildItem -Path $configPath -Filter "*.ps1"
        return $searches | Select-Object @{N='Name'; E={$_.BaseName}}, FullName
    }
}

# Advanced Search Capabilities: Fuzzy Search and Search History

# Global search history and suggestions
$script:SearchHistory = [System.Collections.ArrayList]::new()
$script:SearchSuggestions = @{}
$script:MaxSearchHistory = 100

function Get-LevenshteinDistance {
    <#
    .SYNOPSIS
        Calculates the Levenshtein distance between two strings
    .DESCRIPTION
        Implements the Levenshtein distance algorithm for fuzzy string matching
    .PARAMETER String1
        First string to compare
    .PARAMETER String2
        Second string to compare
    .EXAMPLE
        Get-LevenshteinDistance "hello" "helo"
        Returns 1 (one character difference)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$String1,
        
        [Parameter(Mandatory=$true)]
        [string]$String2
    )
    
    if ($String1 -eq $String2) { return 0 }
    if ($String1.Length -eq 0) { return $String2.Length }
    if ($String2.Length -eq 0) { return $String1.Length }
    
    # Create matrix using PowerShell arrays
    $matrix = @()
    for ($i = 0; $i -le $String1.Length; $i++) {
        $row = @()
        for ($j = 0; $j -le $String2.Length; $j++) {
            $row += 0
        }
        $matrix += ,$row
    }
    
    # Initialize first row and column
    for ($i = 0; $i -le $String1.Length; $i++) { $matrix[$i][0] = $i }
    for ($j = 0; $j -le $String2.Length; $j++) { $matrix[0][$j] = $j }
    
    # Fill matrix
    for ($i = 1; $i -le $String1.Length; $i++) {
        for ($j = 1; $j -le $String2.Length; $j++) {
            $char1 = $String1.Substring($i - 1, 1)
            $char2 = $String2.Substring($j - 1, 1)
            $cost = if ($char1 -eq $char2) { 0 } else { 1 }
            
            $deletion = $matrix[$i - 1][$j] + 1
            $insertion = $matrix[$i][$j - 1] + 1
            $substitution = $matrix[$i - 1][$j - 1] + $cost
            
            $matrix[$i][$j] = [Math]::Min([Math]::Min($deletion, $insertion), $substitution)
        }
    }
    
    return $matrix[$String1.Length][$String2.Length]
}

function Get-FuzzyMatchScore {
    <#
    .SYNOPSIS
        Calculates a fuzzy match score between two strings
    .DESCRIPTION
        Returns a score between 0 and 1 indicating similarity (1 = exact match, 0 = no similarity)
    .PARAMETER String1
        First string to compare
    .PARAMETER String2
        Second string to compare
    .EXAMPLE
        Get-FuzzyMatchScore "PowerShell" "powershel"
        Returns approximately 0.9 (90% similarity)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$String1,
        
        [Parameter(Mandatory=$true)]
        [string]$String2
    )
    
    if ($String1 -eq $String2) { return 1.0 }
    if ($String1.Length -eq 0 -or $String2.Length -eq 0) { return 0.0 }
    
    $distance = Get-LevenshteinDistance -String1 $String1.ToLower() -String2 $String2.ToLower()
    $maxLength = [Math]::Max($String1.Length, $String2.Length)
    
    return [Math]::Round((1.0 - ($distance / $maxLength)), 3)
}

function Search-FilesFuzzy {
    <#
    .SYNOPSIS
        Performs fuzzy search on files using Levenshtein distance
    .DESCRIPTION
        Searches for files with names similar to the query using fuzzy matching
    .PARAMETER Query
        Search query string
    .PARAMETER FuzzyThreshold
        Minimum similarity score (0-1) for matches
    .PARAMETER Path
        Path to search in (uses indexed files if available)
    .PARAMETER UseIndex
        Use cached index for faster search
    .PARAMETER MaxResults
        Maximum number of results to return
    .EXAMPLE
        Search-FilesFuzzy -Query "powrshel" -FuzzyThreshold 0.7
        Finds files with names similar to "powrshel" (like "PowerShell.ps1")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Query,
        
        [Parameter(Mandatory=$false)]
        [ValidateRange(0.1, 1.0)]
        [double]$FuzzyThreshold = 0.7,
        
        [Parameter(Mandatory=$false)]
        [string]$Path = $PWD.Path,
        
        [Parameter(Mandatory=$false)]
        [switch]$UseIndex,
        
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 1000)]
        [int]$MaxResults = 50
    )
    
    try {
        # Record search in history
        Add-SearchToHistory -Query $Query -SearchType "Fuzzy"
        
        Write-Host "Fuzzy searching for: '$Query' (threshold: $FuzzyThreshold)" -ForegroundColor Cyan
        $startTime = Get-Date
        
        $candidates = @()
        
        if ($UseIndex) {
            # Use indexed search if available
            $indexKey = $Path.ToLowerInvariant()
            $directoryIndex = $null
            
            if ($script:DirectoryCache.TryGetValue($indexKey, [ref]$directoryIndex)) {
                $candidates = $directoryIndex.IndexedFiles.Values
                Write-Host "Using cached index with $($candidates.Count) files..." -ForegroundColor Yellow
            } else {
                Write-Host "No index found, building index first..." -ForegroundColor Yellow
                $directoryIndex = Update-FileIndex -Path $Path
                $candidates = $directoryIndex.IndexedFiles.Values
            }
        } else {
            # Traditional file system search
            Write-Host "Scanning file system..." -ForegroundColor Yellow
            $files = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue
            $candidates = $files | ForEach-Object {
                [PSCustomObject]@{
                    Name = $_.Name
                    FullPath = $_.FullName
                    Size = $_.Length
                    LastWriteTime = $_.LastWriteTime
                    Directory = $_.Directory.FullName
                }
            }
        }
        
        Write-Host "Analyzing $($candidates.Count) files for fuzzy matches..." -ForegroundColor Yellow
        
        # Perform fuzzy matching
        $results = @()
        $processed = 0
        
        foreach ($candidate in $candidates) {
            $processed++
            
            # Progress reporting every 100 files
            if ($processed % 100 -eq 0) {
                $percent = [Math]::Round(($processed / $candidates.Count) * 100, 1)
                Write-Host "Progress: $percent% ($processed/$($candidates.Count))" -ForegroundColor Gray
            }
            
            # Calculate fuzzy score for filename (without extension for better matching)
            $nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($candidate.Name)
            $score = Get-FuzzyMatchScore -String1 $Query -String2 $nameWithoutExt
            
            # Also check full filename
            $fullScore = Get-FuzzyMatchScore -String1 $Query -String2 $candidate.Name
            $finalScore = [Math]::Max($score, $fullScore)
            
            if ($finalScore -ge $FuzzyThreshold) {
                $results += [PSCustomObject]@{
                    Name = $candidate.Name
                    FullPath = $candidate.FullPath
                    Directory = $candidate.Directory
                    Size = $candidate.Size
                    LastWriteTime = $candidate.LastWriteTime
                    FuzzyScore = $finalScore
                    MatchType = if ($score -gt $fullScore) { "Name" } else { "FullName" }
                }
            }
            
            # Limit results to prevent memory issues
            if ($results.Count -ge $MaxResults) {
                Write-Host "Reached maximum results limit ($MaxResults)" -ForegroundColor Yellow
                break
            }
        }
        
        # Sort by fuzzy score (highest first)
        $results = $results | Sort-Object FuzzyScore -Descending
        
        $searchDuration = (Get-Date) - $startTime
        
        Write-Host "`n✓ Fuzzy search completed in $($searchDuration.TotalMilliseconds.ToString('F0'))ms" -ForegroundColor Green
        Write-Host "Found $($results.Count) fuzzy matches" -ForegroundColor Green
        
        # Display results
        if ($results.Count -gt 0) {
            Write-Host "`nTop fuzzy matches:" -ForegroundColor Green
            $results | Select-Object -First 20 | 
                Format-Table Name, 
                          @{N='Score'; E={($_.FuzzyScore * 100).ToString('F1') + '%'}}, 
                          @{N='Size'; E={Format-FileSize $_.Size}}, 
                          @{N='Modified'; E={$_.LastWriteTime.ToString('yyyy-MM-dd HH:mm')}},
                          @{N='Directory'; E={Split-Path $_.Directory -Leaf}} -AutoSize
                          
            if ($results.Count -gt 20) {
                Write-Host "... and $($results.Count - 20) more matches (use -MaxResults to see more)" -ForegroundColor Gray
            }
        }
        
        return $results
        
    } catch {
        Write-Error "Error performing fuzzy search: $($_.Exception.Message)"
        throw
    }
}

function Add-SearchToHistory {
    <#
    .SYNOPSIS
        Adds a search query to the search history
    .DESCRIPTION
        Records search queries for building intelligent suggestions
    .PARAMETER Query
        The search query
    .PARAMETER SearchType
        Type of search performed
    .PARAMETER ResultCount
        Number of results found
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Query,
        
        [Parameter(Mandatory=$false)]
        [string]$SearchType = "Standard",
        
        [Parameter(Mandatory=$false)]
        [int]$ResultCount = 0
    )
    
    try {
        $searchEntry = [PSCustomObject]@{
            Query = $Query
            SearchType = $SearchType
            Timestamp = Get-Date
            ResultCount = $ResultCount
            Frequency = 1
        }
        
        # Check if query already exists
        $existing = $script:SearchHistory | Where-Object { $_.Query -eq $Query -and $_.SearchType -eq $SearchType }
        if ($existing) {
            $existing.Frequency++
            $existing.Timestamp = Get-Date
            $existing.ResultCount = $ResultCount
        } else {
            $script:SearchHistory.Add($searchEntry) | Out-Null
        }
        
        # Trim history if it gets too large
        if ($script:SearchHistory.Count -gt $script:MaxSearchHistory) {
            $toRemove = $script:SearchHistory | Sort-Object Timestamp | Select-Object -First ($script:SearchHistory.Count - $script:MaxSearchHistory)
            foreach ($item in $toRemove) {
                $script:SearchHistory.Remove($item) | Out-Null
            }
        }
        
        # Save to persistent storage
        Save-SearchHistory
        
    } catch {
        Write-Verbose "Error adding search to history: $($_.Exception.Message)"
    }
}

function Save-SearchHistory {
    <#
    .SYNOPSIS
        Saves search history to persistent storage
    .DESCRIPTION
        Stores search history in JSON format for persistence across sessions
    #>
    [CmdletBinding()]
    param()
    
    try {
        $configPath = if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
            Join-Path $env:APPDATA "PowerShellFileManager"
        } else {
            Join-Path $HOME ".config/PowerShellFileManager"
        }
        
        if (-not (Test-Path $configPath)) {
            New-Item -ItemType Directory -Path $configPath -Force | Out-Null
        }
        
        $historyPath = Join-Path $configPath "SearchHistory.json"
        $script:SearchHistory | ConvertTo-Json -Depth 3 | Out-File -FilePath $historyPath -Encoding UTF8
        
    } catch {
        Write-Verbose "Error saving search history: $($_.Exception.Message)"
    }
}

function Import-SearchHistory {
    <#
    .SYNOPSIS
        Imports search history from persistent storage
    .DESCRIPTION
        Restores search history from JSON file
    #>
    [CmdletBinding()]
    param()
    
    try {
        $configPath = if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
            Join-Path $env:APPDATA "PowerShellFileManager"
        } else {
            Join-Path $HOME ".config/PowerShellFileManager"
        }
        
        $historyPath = Join-Path $configPath "SearchHistory.json"
        
        if (Test-Path $historyPath) {
            $historyData = Get-Content -Path $historyPath -Raw | ConvertFrom-Json
            $script:SearchHistory.Clear()
            foreach ($entry in $historyData) {
                $script:SearchHistory.Add($entry) | Out-Null
            }
            Write-Verbose "Imported $($script:SearchHistory.Count) search history entries"
        }
        
    } catch {
        Write-Verbose "Error importing search history: $($_.Exception.Message)"
    }
}

function Get-SearchSuggestions {
    <#
    .SYNOPSIS
        Returns intelligent search suggestions based on history and patterns
    .DESCRIPTION
        Provides search suggestions based on search history, file patterns, and common queries
    .PARAMETER PartialQuery
        Partial search query to provide suggestions for
    .PARAMETER MaxSuggestions
        Maximum number of suggestions to return
    .PARAMETER IncludeHistory
        Include suggestions from search history
    .PARAMETER IncludePatterns
        Include suggestions based on file patterns
    .EXAMPLE
        Get-SearchSuggestions -PartialQuery "pow"
        Returns suggestions like "PowerShell", "power.txt", etc.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$PartialQuery = "",
        
        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 50)]
        [int]$MaxSuggestions = 10,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeHistory,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludePatterns
    )
    
    try {
        # Import history if not already loaded
        if ($script:SearchHistory.Count -eq 0) {
            Import-SearchHistory
        }
        
        $suggestions = @()
        
        # History-based suggestions (default to true if not specified)
        $includeHistoryValue = if ($PSBoundParameters.ContainsKey('IncludeHistory')) { $IncludeHistory } else { $true }
        if ($includeHistoryValue -and $script:SearchHistory.Count -gt 0) {
            $historySuggestions = $script:SearchHistory | 
                Where-Object { 
                    if ($PartialQuery) {
                        $_.Query -like "*$PartialQuery*" 
                    } else { 
                        $true 
                    }
                } |
                Sort-Object @{Expression="Frequency"; Descending=$true}, @{Expression="Timestamp"; Descending=$true} |
                Select-Object -First ($MaxSuggestions / 2) |
                ForEach-Object {
                    [PSCustomObject]@{
                        Suggestion = $_.Query
                        Type = "History"
                        Frequency = $_.Frequency
                        LastUsed = $_.Timestamp
                        Score = $_.Frequency * 2 # Weight history suggestions
                    }
                }
            $suggestions += $historySuggestions
        }
        # Pattern-based suggestions (default to true if not specified)
        $includePatternsValue = if ($PSBoundParameters.ContainsKey('IncludePatterns')) { $IncludePatterns } else { $true }
        if ($includePatternsValue) {
            $patternSuggestions = @()
            
            # Common file patterns
            $commonPatterns = @{
                "pow" = @("*.ps1", "*.psm1", "PowerShell*")
                "doc" = @("*.docx", "*.doc", "*.pdf")
                "img" = @("*.jpg", "*.png", "*.gif", "*.bmp")
                "vid" = @("*.mp4", "*.avi", "*.mkv", "*.mov")
                "arc" = @("*.zip", "*.rar", "*.7z", "*.tar")
                "txt" = @("*.txt", "*.log", "*.md")
                "large" = @("size > 100MB", "*.iso", "*.bin")
                "recent" = @("modified today", "modified this week", "modified this month")
            }
            
            # File extension suggestions
            $extensions = @(".ps1", ".psm1", ".txt", ".log", ".md", ".pdf", ".docx", ".xlsx", ".jpg", ".png", ".mp4", ".zip")
            
            if ($PartialQuery) {
                # Find matching patterns
                foreach ($key in $commonPatterns.Keys) {
                    if ($key -like "*$PartialQuery*" -or $PartialQuery -like "*$key*") {
                        foreach ($pattern in $commonPatterns[$key]) {
                            $patternSuggestions += [PSCustomObject]@{
                                Suggestion = $pattern
                                Type = "Pattern"
                                Score = 1
                            }
                        }
                    }
                }
                
                # Find matching extensions
                $matchingExtensions = $extensions | Where-Object { $_ -like "*$PartialQuery*" }
                foreach ($ext in $matchingExtensions) {
                    $patternSuggestions += [PSCustomObject]@{
                        Suggestion = "*$ext"
                        Type = "Extension"
                        Score = 1
                    }
                }
            } else {
                # Provide general suggestions
                $generalSuggestions = @(
                    "*.ps1", "*.txt", "*.log", "*.pdf", "*.jpg", 
                    "large files", "recent files", "duplicate files"
                )
                
                foreach ($suggestion in $generalSuggestions) {
                    $patternSuggestions += [PSCustomObject]@{
                        Suggestion = $suggestion
                        Type = "General"
                        Score = 0.5
                    }
                }
            }
            
            $suggestions += $patternSuggestions
        }
        
        # Sort and limit suggestions
        $finalSuggestions = $suggestions | 
            Sort-Object @{Expression="Score"; Descending=$true}, Type |
            Select-Object -First $MaxSuggestions -Unique
        
        Write-Host "`n🔍 Search Suggestions:" -ForegroundColor Green
        if ($finalSuggestions.Count -gt 0) {
            $finalSuggestions | ForEach-Object { 
                $icon = switch ($_.Type) {
                    "History" { "🕒" }
                    "Pattern" { "🎯" }
                    "Extension" { "📄" }
                    "General" { "💡" }
                    default { "🔍" }
                }
                Write-Host "  $icon $($_.Suggestion)" -ForegroundColor Cyan
            }
        } else {
            Write-Host "  No suggestions available" -ForegroundColor Gray
        }
        
        return $finalSuggestions
        
    } catch {
        Write-Error "Error getting search suggestions: $($_.Exception.Message)"
        return @()
    }
}

function Clear-SearchHistory {
    <#
    .SYNOPSIS
        Clears the search history
    .DESCRIPTION
        Removes all search history entries from memory and persistent storage
    .EXAMPLE
        Clear-SearchHistory
        Clears all search history
    #>
    [CmdletBinding()]
    param()
    
    try {
        $script:SearchHistory.Clear()
        
        # Remove persistent file
        $configPath = if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
            Join-Path $env:APPDATA "PowerShellFileManager"
        } else {
            Join-Path $HOME ".config/PowerShellFileManager"
        }
        
        $historyPath = Join-Path $configPath "SearchHistory.json"
        if (Test-Path $historyPath) {
            Remove-Item -Path $historyPath -Force
        }
        
        Write-Host "✓ Search history cleared" -ForegroundColor Green
        
    } catch {
        Write-Error "Error clearing search history: $($_.Exception.Message)"
        throw
    }
}

function Get-SearchHistory {
    <#
    .SYNOPSIS
        Gets the search history
    .DESCRIPTION
        Returns the current search history with statistics
    .PARAMETER Query
        Filter history by specific query
    .PARAMETER SearchType
        Filter by search type
    .EXAMPLE
        Get-SearchHistory
        Shows all search history
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Query,
        
        [Parameter(Mandatory=$false)]
        [string]$SearchType
    )
    
    try {
        # Load history if not already loaded
        if ($script:SearchHistory.Count -eq 0) {
            Load-SearchHistory
        }
        
        $history = $script:SearchHistory
        
        # Apply filters
        if ($Query) {
            $history = $history | Where-Object { $_.Query -like "*$Query*" }
        }
        
        if ($SearchType) {
            $history = $history | Where-Object { $_.SearchType -eq $SearchType }
        }
        
        # Display statistics
        Write-Host "`n📊 Search History Statistics" -ForegroundColor Green
        Write-Host "=============================" -ForegroundColor Green
        Write-Host "Total searches: $($script:SearchHistory.Count)" -ForegroundColor Cyan
        
        if ($history.Count -gt 0) {
            $topQueries = $history | Group-Object Query | Sort-Object Count -Descending | Select-Object -First 5
            Write-Host "Most frequent queries:" -ForegroundColor Yellow
            $topQueries | ForEach-Object { 
                Write-Host "  '$($_.Name)' - $($_.Count) times" -ForegroundColor Gray 
            }
            
            Write-Host "`nRecent History:" -ForegroundColor Yellow
            $history | Sort-Object Timestamp -Descending | Select-Object -First 10 |
                Format-Table Query, SearchType, 
                          @{N='Frequency'; E={$_.Frequency}},
                          @{N='Results'; E={$_.ResultCount}},
                          @{N='Last Used'; E={$_.Timestamp.ToString('MM/dd HH:mm')}} -AutoSize
        }
        
        return $history
        
    } catch {
        Write-Error "Error getting search history: $($_.Exception.Message)"
        throw
    }
}

function Search-Content {
    <#
    .SYNOPSIS
        Searches file contents for a pattern
    .DESCRIPTION
        Searches within file contents using regex patterns
    .PARAMETER Path
        Base path to search
    .PARAMETER Pattern
        Search pattern (regex)
    .PARAMETER CaseSensitive
        Perform case-sensitive search
    .EXAMPLE
        Search-Content -Path C:\Logs -Pattern "error"
        Searches for "error" in log files
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [string]$Pattern,
        
        [Parameter(Mandatory=$false)]
        [switch]$CaseSensitive
    )
    
    Write-Host "Searching file contents in: $Path" -ForegroundColor Cyan
    Write-Host "Pattern: $Pattern" -ForegroundColor Gray
    
    $results = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | 
        Where-Object { 
            try {
                $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
                if ($CaseSensitive) {
                    $content -cmatch $Pattern
                } else {
                    $content -match $Pattern
                }
            } catch {
                $false
            }
        }
    
    Write-Host "`nFound $($results.Count) matches" -ForegroundColor Green
    $results | Format-Table Name, FullName, Length, LastWriteTime -AutoSize
    
    return $results
}

function Get-FuzzyMatch {
    <#
    .SYNOPSIS
        Alias for Get-FuzzyMatchScore - calculates fuzzy match similarity
    .DESCRIPTION
        Returns a score between 0 and 1 indicating similarity between two strings
    .PARAMETER String1
        First string to compare
    .PARAMETER String2
        Second string to compare
    .EXAMPLE
        Get-FuzzyMatch "PowerShell" "powershel"
        Returns approximately 0.9 (90% similarity)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$String1,
        
        [Parameter(Mandatory=$true)]
        [string]$String2
    )
    
    return Get-FuzzyMatchScore -String1 $String1 -String2 $String2
}

# Initialize search history on module load
Import-SearchHistory

Export-ModuleMember -Function Search-Files, Search-Content, Get-FuzzyMatch, Save-SearchQuery, Get-SavedSearches, 
                              Update-FileIndex, Search-IndexedFiles, Get-FileIndexStatistics, 
                              Clear-FileCache, Optimize-FileCache, Sync-Directories,
                              Search-FilesFuzzy, Get-SearchSuggestions, Clear-SearchHistory, Get-SearchHistory
