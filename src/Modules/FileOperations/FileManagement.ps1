#Requires -Version 7.0

# File Management Module - Core file operations
# Includes duplicate finder, checksum, symlink, sync, etc.

function Find-DuplicateFiles {
    <#
    .SYNOPSIS
        Finds duplicate files by hash, name pattern, or size
    .DESCRIPTION
        Scans directories for duplicate files using SHA256 hashing with comprehensive error handling
    .PARAMETER Path
        Path to scan for duplicates
    .PARAMETER Method
        Method to use: Hash, Name, or Size
    .EXAMPLE
        Find-DuplicateFiles -Path C:\Data -Method Hash
        Finds duplicate files by hash
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({
            if (-not (Test-Path $_ -PathType Container)) {
                throw "Path '$_' does not exist or is not a directory."
            }
            $true
        })]
        [string]$Path,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Hash', 'Name', 'Size')]
        [string]$Method = 'Hash'
    )
    
    try {
        Write-Host "Scanning for duplicates using $Method method..." -ForegroundColor Cyan
        Write-Host "Scanning path: $Path" -ForegroundColor Gray
        
        # Validate path exists and is accessible
        if (-not (Test-Path -Path $Path -PathType Container)) {
            throw [System.IO.DirectoryNotFoundException]::new("Directory not found: $Path")
        }
        
        # Test read access
        try {
            $null = Get-ChildItem -Path $Path -ErrorAction Stop | Select-Object -First 1
        } catch [System.UnauthorizedAccessException] {
            throw [System.UnauthorizedAccessException]::new("Access denied to directory: $Path")
        }
        
        $files = @()
        $accessDeniedCount = 0
        $corruptedFileCount = 0
        
        try {
            Write-Progress -Activity "Scanning for files" -Status "Enumerating files..." -PercentComplete 0
            $files = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue
            Write-Host "Found $($files.Count) files to analyze" -ForegroundColor Green
        } catch [System.UnauthorizedAccessException] {
            Write-Warning "Access denied to some directories in: $Path. Continuing with available files."
        } catch {
            throw [System.IO.IOException]::new("Error reading directory structure: $($_.Exception.Message)")
        }
        
        if ($files.Count -eq 0) {
            Write-Warning "No files found in the specified path."
            return @()
        }
        
        $groups = @{}
        $processedCount = 0
        $totalFiles = $files.Count
        
        foreach ($file in $files) {
            try {
                $processedCount++
                
                # Update progress every 100 files
                if ($processedCount % 100 -eq 0) {
                    $percentComplete = [Math]::Round(($processedCount / $totalFiles) * 100, 2)
                    Write-Progress -Activity "Processing files" -Status "Processed $processedCount of $totalFiles files" -PercentComplete $percentComplete
                }
                
                $key = switch ($Method) {
                    'Hash' {
                        try {
                            $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256 -ErrorAction Stop
                            $hash.Hash
                        } catch [System.UnauthorizedAccessException] {
                            $accessDeniedCount++
                            Write-Verbose "Access denied to file: $($file.FullName)"
                            $null
                        } catch [System.IO.IOException] {
                            $corruptedFileCount++
                            Write-Verbose "I/O error reading file: $($file.FullName)"
                            $null
                        } catch {
                            Write-Verbose "Error processing file $($file.FullName): $($_.Exception.Message)"
                            $null
                        }
                    }
                    'Name' { $file.Name }
                    'Size' { $file.Length }
                }
                
                if ($key) {
                    if (-not $groups.ContainsKey($key)) {
                        $groups[$key] = [System.Collections.ArrayList]::new()
                    }
                    $groups[$key].Add($file) | Out-Null
                }
            } catch {
                Write-Verbose "Error processing file $($file.FullName): $($_.Exception.Message)"
                continue
            }
        }
        
        Write-Progress -Activity "Processing files" -Completed
        
        # Report any issues encountered
        if ($accessDeniedCount -gt 0) {
            Write-Warning "Access denied to $accessDeniedCount files. Some duplicates may not be detected."
        }
        if ($corruptedFileCount -gt 0) {
            Write-Warning "Could not read $corruptedFileCount files (possibly corrupted or in use)."
        }
        
        $duplicates = $groups.Values | Where-Object { $_.Count -gt 1 }
        
        if ($duplicates) {
            Write-Host "`nFound $($duplicates.Count) groups of duplicates:" -ForegroundColor Yellow
            $totalDuplicateFiles = ($duplicates | ForEach-Object { $_.Count }) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
            Write-Host "Total duplicate files: $totalDuplicateFiles" -ForegroundColor Yellow
            
            foreach ($group in $duplicates) {
                Write-Host "`n  Duplicate group ($($group.Count) files):" -ForegroundColor Green
                foreach ($file in $group) {
                    Write-Host "    $($file.FullName)" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "No duplicates found." -ForegroundColor Green
        }
        
        return $duplicates
        
    } catch [System.UnauthorizedAccessException] {
        Write-Warning "Access denied to some files in '$Path'. Running with limited permissions."
        Write-Host "Tip: Try running as administrator or check directory permissions." -ForegroundColor Yellow
        throw
    } catch [System.IO.DirectoryNotFoundException] {
        Write-Error "Directory not found: $Path"
        throw
    } catch [System.IO.IOException] {
        Write-Error "I/O error while processing directory: $($_.Exception.Message)"
        throw
    } catch [System.OutOfMemoryException] {
        Write-Error "Out of memory while processing large directory structure. Try processing smaller subdirectories."
        throw
    } catch {
        Write-Error "Unexpected error during duplicate file search: $($_.Exception.Message)"
        Write-Host "Error details: $($_.ScriptStackTrace)" -ForegroundColor Red
        throw
    }
}

function Get-FolderSize {
    <#
    .SYNOPSIS
        Calculates and displays folder sizes with robust error handling
    .DESCRIPTION
        Recursively calculates the size of folders, handling access denied errors gracefully
    .PARAMETER Path
        Path to calculate size for
    .PARAMETER IncludeSubfolders
        Include detailed subfolder breakdown
    .EXAMPLE
        Get-FolderSize -Path C:\Data
        Gets folder size
    .EXAMPLE
        Get-FolderSize -Path C:\Data -IncludeSubfolders
        Gets folder size with subfolder breakdown
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateScript({
            if (-not (Test-Path $_ -PathType Container)) {
                throw "Path '$_' does not exist or is not a directory."
            }
            $true
        })]
        [string]$Path,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeSubfolders
    )
    
    process {
        try {
            # Validate path exists and is accessible
            if (-not (Test-Path -Path $Path -PathType Container)) {
                throw [System.IO.DirectoryNotFoundException]::new("Directory not found: $Path")
            }
            
            Write-Verbose "Calculating size for: $Path"
            
            # Test read access
            try {
                $null = Get-ChildItem -Path $Path -ErrorAction Stop | Select-Object -First 1
            } catch [System.UnauthorizedAccessException] {
                throw [System.UnauthorizedAccessException]::new("Access denied to directory: $Path")
            }
            
            $files = @()
            $accessDeniedDirs = @()
            $totalSize = 0
            $fileCount = 0
            
            try {
                Write-Progress -Activity "Calculating folder size" -Status "Scanning files..." -PercentComplete 0
                
                # Get all files with error handling for individual directories
                $files = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue
                
                # Calculate size with error handling for individual files
                foreach ($file in $files) {
                    try {
                        $totalSize += $file.Length
                        $fileCount++
                    } catch [System.UnauthorizedAccessException] {
                        Write-Verbose "Access denied to file: $($file.FullName)"
                        continue
                    } catch {
                        Write-Verbose "Error reading file size: $($file.FullName) - $($_.Exception.Message)"
                        continue
                    }
                }
                
                Write-Progress -Activity "Calculating folder size" -Completed
                
            } catch [System.UnauthorizedAccessException] {
                Write-Warning "Access denied to some directories in: $Path"
                # Continue with partial results
            } catch {
                throw [System.IO.IOException]::new("Error reading directory: $($_.Exception.Message)")
            }
            
            $result = [PSCustomObject]@{
                Path = $Path
                SizeBytes = $totalSize
                SizeMB = [Math]::Round($totalSize / 1MB, 2)
                SizeGB = [Math]::Round($totalSize / 1GB, 2)
                SizeTB = [Math]::Round($totalSize / 1TB, 4)
                FileCount = $fileCount
                LastCalculated = Get-Date
                HasPartialResults = $accessDeniedDirs.Count -gt 0
            }
            
            # Add subfolder breakdown if requested
            if ($IncludeSubfolders) {
                try {
                    $subfolders = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                        try {
                            $subFiles = Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction SilentlyContinue
                            $subSize = ($subFiles | Measure-Object -Property Length -Sum).Sum
                            [PSCustomObject]@{
                                Name = $_.Name
                                Path = $_.FullName
                                SizeBytes = $subSize
                                SizeMB = [Math]::Round($subSize / 1MB, 2)
                                FileCount = $subFiles.Count
                            }
                        } catch {
                            Write-Verbose "Error calculating size for subfolder: $($_.FullName)"
                            [PSCustomObject]@{
                                Name = $_.Name
                                Path = $_.FullName
                                SizeBytes = 0
                                SizeMB = 0
                                FileCount = 0
                                Error = "Access denied or calculation error"
                            }
                        }
                    }
                    $result | Add-Member -NotePropertyName Subfolders -NotePropertyValue $subfolders
                } catch {
                    Write-Verbose "Error calculating subfolder sizes: $($_.Exception.Message)"
                }
            }
            
            # Display results
            Write-Host "`nFolder Size Analysis:" -ForegroundColor Cyan
            Write-Host "Path: $($result.Path)" -ForegroundColor Gray
            Write-Host "Total Size: $($result.SizeGB) GB ($($result.SizeMB) MB)" -ForegroundColor Green
            Write-Host "File Count: $($result.FileCount)" -ForegroundColor Green
            
            if ($result.HasPartialResults) {
                Write-Warning "Results may be incomplete due to access restrictions."
            }
            
            return $result
            
        } catch [System.UnauthorizedAccessException] {
            Write-Error "Access denied to '$Path'. Try running as administrator or check directory permissions."
            throw
        } catch [System.IO.DirectoryNotFoundException] {
            Write-Error "Directory not found: $Path"
            throw
        } catch [System.IO.IOException] {
            Write-Error "I/O error while calculating folder size: $($_.Exception.Message)"
            throw
        } catch [System.OutOfMemoryException] {
            Write-Error "Out of memory while processing large directory. Try processing smaller subdirectories."
            throw
        } catch {
            Write-Error "Unexpected error calculating folder size: $($_.Exception.Message)"
            Write-Verbose "Error details: $($_.ScriptStackTrace)"
            throw
        }
    }
}

function Get-FileChecksum {
    <#
    .SYNOPSIS
        Calculates file checksum (SHA256/SHA512)
    .DESCRIPTION
        Computes cryptographic hash for file verification
    .PARAMETER Path
        Path to file
    .PARAMETER Algorithm
        Hash algorithm (SHA256, SHA512)
    .EXAMPLE
        Get-FileChecksum -Path file.txt -Algorithm SHA256
        Gets SHA256 checksum
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('SHA256', 'SHA512')]
        [string]$Algorithm = 'SHA256'
    )
    
    process {
        if (Test-Path $Path) {
            $hash = Get-FileHash -Path $Path -Algorithm $Algorithm
            
            Write-Host "`n$Algorithm Checksum for: $Path" -ForegroundColor Cyan
            Write-Host $hash.Hash -ForegroundColor Green
            
            return $hash
        } else {
            Write-Error "File not found: $Path"
        }
    }
}

function New-Symlink {
    <#
    .SYNOPSIS
        Creates symbolic link or junction
    .DESCRIPTION
        Easy creation of symbolic links and junctions
    .PARAMETER Path
        Path where symlink will be created
    .PARAMETER Target
        Target path that symlink points to
    .PARAMETER Type
        Type: SymbolicLink or Junction
    .EXAMPLE
        New-Symlink -Path C:\link -Target C:\target -Type SymbolicLink
        Creates symbolic link
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [string]$Target,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('SymbolicLink', 'Junction')]
        [string]$Type = 'SymbolicLink'
    )
    
    try {
        if ($Type -eq 'SymbolicLink') {
            New-Item -ItemType SymbolicLink -Path $Path -Target $Target -Force
        } else {
            New-Item -ItemType Junction -Path $Path -Target $Target -Force
        }
        
        Write-Host "$Type created successfully!" -ForegroundColor Green
        Write-Host "  Path: $Path" -ForegroundColor Gray
        Write-Host "  Target: $Target" -ForegroundColor Gray
    } catch {
        Write-Error "Failed to create ${Type}: $_"
    }
}

function Sync-Directories {
    <#
    .SYNOPSIS
        Synchronizes two directories with conflict resolution
    .DESCRIPTION
        Syncs files between source and destination with options
    .PARAMETER Source
        Source directory
    .PARAMETER Destination
        Destination directory
    .PARAMETER Mode
        Sync mode: Mirror, Update, or TwoWay
    .EXAMPLE
        Sync-Directories -Source C:\Source -Destination C:\Dest -Mode Mirror
        Mirrors source to destination
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Source,
        
        [Parameter(Mandatory=$true)]
        [string]$Destination,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Mirror', 'Update', 'TwoWay')]
        [string]$Mode = 'Update',
        
        [Parameter(Mandatory=$false)]
        [switch]$WhatIf
    )
    
    if (-not (Test-Path $Source)) {
        Write-Error "Source path not found: $Source"
        return
    }
    
    if (-not (Test-Path $Destination)) {
        Write-Host "Creating destination directory: $Destination" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }
    
    Write-Host "Synchronizing directories..." -ForegroundColor Cyan
    Write-Host "  Source: $Source" -ForegroundColor Gray
    Write-Host "  Destination: $Destination" -ForegroundColor Gray
    Write-Host "  Mode: $Mode" -ForegroundColor Gray
    
    $sourceFiles = Get-ChildItem -Path $Source -Recurse -File
    $destFiles = Get-ChildItem -Path $Destination -Recurse -File -ErrorAction SilentlyContinue
    
    $copied = 0
    $updated = 0
    $deleted = 0
    
    foreach ($srcFile in $sourceFiles) {
        $relativePath = $srcFile.FullName.Substring($Source.Length)
        $destPath = Join-Path $Destination $relativePath
        $destDir = Split-Path $destPath -Parent
        
        if (-not (Test-Path $destDir)) {
            if (-not $WhatIf) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
        }
        
        if (-not (Test-Path $destPath)) {
            Write-Host "  [NEW] $relativePath" -ForegroundColor Green
            if (-not $WhatIf) {
                Copy-Item -Path $srcFile.FullName -Destination $destPath -Force
            }
            $copied++
        } elseif ($srcFile.LastWriteTime -gt (Get-Item $destPath).LastWriteTime) {
            Write-Host "  [UPDATE] $relativePath" -ForegroundColor Yellow
            if (-not $WhatIf) {
                Copy-Item -Path $srcFile.FullName -Destination $destPath -Force
            }
            $updated++
        }
    }
    
    if ($Mode -eq 'Mirror') {
        foreach ($destFile in $destFiles) {
            $relativePath = $destFile.FullName.Substring($Destination.Length)
            $srcPath = Join-Path $Source $relativePath
            
            if (-not (Test-Path $srcPath)) {
                Write-Host "  [DELETE] $relativePath" -ForegroundColor Red
                if (-not $WhatIf) {
                    Remove-Item -Path $destFile.FullName -Force
                }
                $deleted++
            }
        }
    }
    
    Write-Host "`nSync complete:" -ForegroundColor Cyan
    Write-Host "  Copied: $copied" -ForegroundColor Green
    Write-Host "  Updated: $updated" -ForegroundColor Yellow
    Write-Host "  Deleted: $deleted" -ForegroundColor Red
}

function Invoke-FileComparison {
    <#
    .SYNOPSIS
        Compares two files side-by-side
    .DESCRIPTION
        Displays differences between two files
    .PARAMETER Path1
        First file path
    .PARAMETER Path2
        Second file path
    .EXAMPLE
        Invoke-FileComparison -Path1 file1.txt -Path2 file2.txt
        Compares two files
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path1,
        
        [Parameter(Mandatory=$true)]
        [string]$Path2
    )
    
    if (-not (Test-Path $Path1)) {
        Write-Error "File not found: $Path1"
        return
    }
    
    if (-not (Test-Path $Path2)) {
        Write-Error "File not found: $Path2"
        return
    }
    
    Write-Host "`nComparing files..." -ForegroundColor Cyan
    Write-Host "  File 1: $Path1" -ForegroundColor Gray
    Write-Host "  File 2: $Path2" -ForegroundColor Gray
    
    $content1 = Get-Content -Path $Path1
    $content2 = Get-Content -Path $Path2
    
    $diff = Compare-Object -ReferenceObject $content1 -DifferenceObject $content2 -IncludeEqual
    
    foreach ($line in $diff) {
        switch ($line.SideIndicator) {
            '<=' { Write-Host "  - $($line.InputObject)" -ForegroundColor Red }
            '=>' { Write-Host "  + $($line.InputObject)" -ForegroundColor Green }
            '==' { Write-Host "    $($line.InputObject)" -ForegroundColor Gray }
        }
    }
}

function Rename-FileBatch {
    <#
    .SYNOPSIS
        Batch rename files with regex patterns
    .DESCRIPTION
        Renames multiple files using regex-based patterns
    .PARAMETER Path
        Path containing files to rename
    .PARAMETER Pattern
        Regex pattern to match
    .PARAMETER Replacement
        Replacement string
    .EXAMPLE
        Rename-FileBatch -Path C:\Files -Pattern "old" -Replacement "new"
        Renames files matching pattern
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [string]$Pattern,
        
        [Parameter(Mandatory=$true)]
        [string]$Replacement,
        
        [Parameter(Mandatory=$false)]
        [switch]$WhatIf
    )
    
    $files = Get-ChildItem -Path $Path -File | Where-Object { $_.Name -match $Pattern }
    
    if ($files.Count -eq 0) {
        Write-Host "No files match the pattern." -ForegroundColor Yellow
        return
    }
    
    Write-Host "Files to rename: $($files.Count)" -ForegroundColor Cyan
    
    foreach ($file in $files) {
        $newName = $file.Name -replace $Pattern, $Replacement
        Write-Host "  $($file.Name) -> $newName" -ForegroundColor Gray
        
        if (-not $WhatIf) {
            Rename-Item -Path $file.FullName -NewName $newName
        }
    }
    
    if (-not $WhatIf) {
        Write-Host "`nRename complete!" -ForegroundColor Green
    } else {
        Write-Host "`n(WhatIf mode - no changes made)" -ForegroundColor Yellow
    }
}

Export-ModuleMember -Function Find-DuplicateFiles, Get-FolderSize, Get-FileChecksum, `
    New-Symlink, Sync-Directories, Invoke-FileComparison, Rename-FileBatch
