# Example Scripts for PowerShell File Manager V2.0

## Example 1: Find and Archive Old Files

```powershell
# Find files older than 1 year and archive them

$oldFiles = Get-ChildItem -Path "C:\Documents" -Recurse -File |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddYears(-1) }

Write-Host "Found $($oldFiles.Count) files older than 1 year"

if ($oldFiles.Count -gt 0) {
    # Create archive directory
    $archiveDate = Get-Date -Format "yyyy-MM-dd"
    $archivePath = "C:\Archive\Archive_$archiveDate"
    New-Item -ItemType Directory -Path $archivePath -Force
    
    # Move files to archive
    foreach ($file in $oldFiles) {
        $relativePath = $file.FullName.Replace("C:\Documents\", "")
        $destPath = Join-Path $archivePath $relativePath
        $destDir = Split-Path $destPath -Parent
        
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        
        Move-Item -Path $file.FullName -Destination $destPath
    }
    
    # Create ZIP archive
    New-Archive -Path $archivePath -Destination "C:\Archive\Archive_$archiveDate.zip" -Format ZIP
    
    # Remove temporary directory
    Remove-Item -Path $archivePath -Recurse -Force
    
    Write-Host "Archived to: C:\Archive\Archive_$archiveDate.zip"
}
```

## Example 2: Clean Up Duplicate Files

```powershell
# Find and remove duplicate files, keeping only one copy

$duplicates = Find-DuplicateFiles -Path "C:\Downloads" -Method Hash

foreach ($group in $duplicates) {
    Write-Host "`nDuplicate group ($($group.Count) files):"
    
    # Keep the first file, remove others
    $keep = $group[0]
    Write-Host "  KEEP: $($keep.FullName)" -ForegroundColor Green
    
    for ($i = 1; $i -lt $group.Count; $i++) {
        Write-Host "  DELETE: $($group[$i].FullName)" -ForegroundColor Red
        Remove-Item -Path $group[$i].FullName -Force
    }
}
```

## Example 3: Organize Files by Type

```powershell
# Organize files into folders by extension

$sourcePath = "C:\Downloads"
$targetPath = "C:\Organized"

$files = Get-ChildItem -Path $sourcePath -File

foreach ($file in $files) {
    $extension = $file.Extension.TrimStart('.').ToUpper()
    if ([string]::IsNullOrEmpty($extension)) {
        $extension = "NO_EXTENSION"
    }
    
    $destFolder = Join-Path $targetPath $extension
    
    if (-not (Test-Path $destFolder)) {
        New-Item -ItemType Directory -Path $destFolder -Force | Out-Null
    }
    
    $destPath = Join-Path $destFolder $file.Name
    Move-Item -Path $file.FullName -Destination $destPath
    
    Write-Host "Moved $($file.Name) to $extension folder"
}

Write-Host "`nOrganization complete!"
```

## Example 4: Backup Modified Files

```powershell
# Backup files modified in the last 7 days

$sourcePath = "C:\Projects"
$backupPath = "D:\Backups\Weekly_$(Get-Date -Format 'yyyy-MM-dd')"

$recentFiles = Get-ChildItem -Path $sourcePath -Recurse -File |
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) }

Write-Host "Found $($recentFiles.Count) files modified in the last 7 days"

foreach ($file in $recentFiles) {
    $relativePath = $file.FullName.Replace($sourcePath, "")
    $destPath = Join-Path $backupPath $relativePath
    $destDir = Split-Path $destPath -Parent
    
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    
    Copy-Item -Path $file.FullName -Destination $destPath -Force
}

# Create backup report
$report = @"
Backup Report
Created: $(Get-Date)
Source: $sourcePath
Destination: $backupPath
Files Backed Up: $($recentFiles.Count)

Files:
$($recentFiles | Select-Object Name, Length, LastWriteTime | Format-Table | Out-String)
"@

$report | Out-File -FilePath (Join-Path $backupPath "BackupReport.txt")

Write-Host "Backup complete: $backupPath"
```

## Example 5: Find Large Files and Generate Report

```powershell
# Find files larger than 100MB and generate HTML report

$largeFiles = Get-ChildItem -Path "C:\" -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -gt 100MB } |
    Select-Object Name, FullName, 
        @{N='SizeMB';E={[Math]::Round($_.Length/1MB,2)}},
        LastWriteTime |
    Sort-Object SizeMB -Descending

$html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Large Files Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Large Files Report</h1>
    <p>Generated: $(Get-Date)</p>
    <p>Files larger than 100MB: $($largeFiles.Count)</p>
    <p>Total size: $([Math]::Round(($largeFiles | Measure-Object -Property SizeMB -Sum).Sum/1024,2)) GB</p>
    
    <table>
        <tr>
            <th>Name</th>
            <th>Path</th>
            <th>Size (MB)</th>
            <th>Last Modified</th>
        </tr>
"@

foreach ($file in $largeFiles) {
    $html += @"
        <tr>
            <td>$($file.Name)</td>
            <td>$($file.FullName)</td>
            <td>$($file.SizeMB)</td>
            <td>$($file.LastWriteTime)</td>
        </tr>
"@
}

$html += @"
    </table>
</body>
</html>
"@

$reportPath = "C:\Reports\LargeFilesReport_$(Get-Date -Format 'yyyy-MM-dd').html"
$html | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "Report saved: $reportPath"
Start-Process $reportPath
```

## Example 6: Sync with Verification

```powershell
# Sync directories with checksum verification

function Sync-WithVerification {
    param(
        [string]$Source,
        [string]$Destination
    )
    
    $sourceFiles = Get-ChildItem -Path $Source -Recurse -File
    $verified = 0
    $failed = 0
    
    foreach ($srcFile in $sourceFiles) {
        $relativePath = $srcFile.FullName.Substring($Source.Length)
        $destPath = Join-Path $Destination $relativePath
        $destDir = Split-Path $destPath -Parent
        
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        
        # Copy file
        Copy-Item -Path $srcFile.FullName -Destination $destPath -Force
        
        # Verify with checksum
        $srcHash = Get-FileHash -Path $srcFile.FullName -Algorithm SHA256
        $destHash = Get-FileHash -Path $destPath -Algorithm SHA256
        
        if ($srcHash.Hash -eq $destHash.Hash) {
            Write-Host "✓ Verified: $relativePath" -ForegroundColor Green
            $verified++
        } else {
            Write-Host "✗ Failed: $relativePath" -ForegroundColor Red
            $failed++
        }
    }
    
    Write-Host "`nSync complete:"
    Write-Host "  Verified: $verified" -ForegroundColor Green
    Write-Host "  Failed: $failed" -ForegroundColor Red
}

Sync-WithVerification -Source "C:\Important" -Destination "D:\Backup"
```

## Example 7: Clean Temp Files

```powershell
# Clean temporary and cache files

$tempLocations = @(
    "$env:TEMP\*"
    "$env:LOCALAPPDATA\Temp\*"
    "C:\Windows\Temp\*"
    "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*"
)

$totalFreed = 0

foreach ($location in $tempLocations) {
    if (Test-Path (Split-Path $location -Parent)) {
        Write-Host "Cleaning: $location"
        
        $files = Get-ChildItem -Path $location -Recurse -Force -ErrorAction SilentlyContinue
        $size = ($files | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        
        if ($size) {
            $totalFreed += $size
            Remove-Item -Path $location -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  Freed: $([Math]::Round($size/1MB,2)) MB"
        }
    }
}

Write-Host "`nTotal space freed: $([Math]::Round($totalFreed/1GB,2)) GB" -ForegroundColor Green
```

## Example 8: File Metadata Batch Update

```powershell
# Update creation time for all photos to match EXIF date

$photos = Get-ChildItem -Path "C:\Photos" -Include "*.jpg","*.jpeg" -Recurse

foreach ($photo in $photos) {
    try {
        # Get EXIF data
        $metadata = Get-FileMetadata -Path $photo.FullName
        
        if ($metadata['Date taken']) {
            $dateTaken = [DateTime]::Parse($metadata['Date taken'])
            
            # Update file creation time to match EXIF
            Edit-FileMetadata -Path $photo.FullName -Properties @{
                CreationTime = $dateTaken
                LastWriteTime = $dateTaken
            }
            
            Write-Host "Updated: $($photo.Name) -> $dateTaken"
        }
    } catch {
        Write-Warning "Failed to process: $($photo.Name)"
    }
}
```

## Example 9: Git-Aware Backup

```powershell
# Backup only modified/untracked git files

$repoPath = "C:\MyProject"
$backupPath = "D:\Backups\Project_$(Get-Date -Format 'yyyy-MM-dd-HHmmss')"

# Get git status
$gitStatus = Get-GitStatus -Path $repoPath

if ($gitStatus) {
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    
    foreach ($item in $gitStatus) {
        $sourcePath = $item.FullPath
        $relativePath = $item.File
        $destPath = Join-Path $backupPath $relativePath
        $destDir = Split-Path $destPath -Parent
        
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        
        Copy-Item -Path $sourcePath -Destination $destPath -Force
        Write-Host "Backed up [$($item.Status)]: $relativePath"
    }
    
    Write-Host "`nBackup complete: $backupPath"
} else {
    Write-Host "No modified files found"
}
```

## Example 10: Automated Folder Organization

```powershell
# Organize downloads folder automatically

$downloadsPath = "$env:USERPROFILE\Downloads"

# Define organization rules
$rules = @{
    'Documents' = @('*.pdf', '*.doc', '*.docx', '*.txt', '*.xlsx')
    'Images' = @('*.jpg', '*.jpeg', '*.png', '*.gif', '*.bmp')
    'Videos' = @('*.mp4', '*.avi', '*.mkv', '*.mov')
    'Music' = @('*.mp3', '*.wav', '*.flac', '*.m4a')
    'Archives' = @('*.zip', '*.rar', '*.7z', '*.tar', '*.gz')
    'Installers' = @('*.exe', '*.msi')
}

foreach ($category in $rules.Keys) {
    $targetFolder = Join-Path $downloadsPath $category
    
    if (-not (Test-Path $targetFolder)) {
        New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
    }
    
    foreach ($pattern in $rules[$category]) {
        $files = Get-ChildItem -Path $downloadsPath -Filter $pattern -File
        
        foreach ($file in $files) {
            $destPath = Join-Path $targetFolder $file.Name
            Move-Item -Path $file.FullName -Destination $destPath -Force
            Write-Host "Moved $($file.Name) to $category"
        }
    }
}

Write-Host "`nDownloads folder organized!"
```

---

These examples demonstrate the power and flexibility of PowerShell File Manager V2.0.
Modify them to suit your specific needs!
