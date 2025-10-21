#Requires -Version 7.0

# Disk Analyzer Module - Visual tree map of folder sizes

function Get-DiskSpace {
    <#
    .SYNOPSIS
        Analyzes disk space usage
    .DESCRIPTION
        Provides detailed disk space analysis with folder size breakdown
    .PARAMETER Path
        Path to analyze
    .PARAMETER Depth
        Maximum depth to analyze
    .EXAMPLE
        Get-DiskSpace -Path C:\ -Depth 3
        Analyzes disk space
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$false)]
        [int]$Depth = 2
    )
    
    Write-Host "Analyzing disk space in: $Path" -ForegroundColor Cyan
    Write-Host "Depth: $Depth" -ForegroundColor Gray
    
    function Get-FolderSizeRecursive {
        param($FolderPath, $CurrentDepth, $MaxDepth)
        
        if ($CurrentDepth -gt $MaxDepth) { return $null }
        
        $folderInfo = Get-Item $FolderPath -ErrorAction SilentlyContinue
        if (-not $folderInfo) { return $null }
        
        $files = Get-ChildItem -Path $FolderPath -File -ErrorAction SilentlyContinue
        $size = ($files | Measure-Object -Property Length -Sum).Sum
        
        $subFolders = Get-ChildItem -Path $FolderPath -Directory -ErrorAction SilentlyContinue
        $children = @()
        
        foreach ($subFolder in $subFolders) {
            $child = Get-FolderSizeRecursive -FolderPath $subFolder.FullName `
                -CurrentDepth ($CurrentDepth + 1) -MaxDepth $MaxDepth
            
            if ($child) {
                $size += $child.Size
                $children += $child
            }
        }
        
        return [PSCustomObject]@{
            Path = $FolderPath
            Name = Split-Path $FolderPath -Leaf
            Size = $size
            SizeMB = [Math]::Round($size / 1MB, 2)
            SizeGB = [Math]::Round($size / 1GB, 2)
            FileCount = $files.Count
            Children = $children
        }
    }
    
    $result = Get-FolderSizeRecursive -FolderPath $Path -CurrentDepth 0 -MaxDepth $Depth
    
    # Display results
    function Show-FolderTree {
        param($Node, $Indent = "")
        
        $sizeStr = if ($Node.SizeGB -gt 1) {
            "$($Node.SizeGB) GB"
        } else {
            "$($Node.SizeMB) MB"
        }
        
        Write-Host "$Indent$($Node.Name) [$sizeStr] ($($Node.FileCount) files)" -ForegroundColor Cyan
        
        $sortedChildren = $Node.Children | Sort-Object Size -Descending
        foreach ($child in $sortedChildren) {
            Show-FolderTree -Node $child -Indent "$Indent  "
        }
    }
    
    Write-Host "`nDisk Space Analysis:" -ForegroundColor Green
    Show-FolderTree -Node $result
    
    return $result
}

Export-ModuleMember -Function Get-DiskSpace
