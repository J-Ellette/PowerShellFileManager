#Requires -Version 7.0

# Git Integration Module - Show git status in file list

function Get-GitStatus {
    <#
    .SYNOPSIS
        Shows git status for files in current directory
    .DESCRIPTION
        Displays git status indicators (modified, staged, untracked)
    .PARAMETER Path
        Repository path
    .EXAMPLE
        Get-GitStatus -Path C:\MyRepo
        Shows git status
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Path = $pwd
    )
    
    if (-not (Test-Path (Join-Path $Path ".git"))) {
        Write-Warning "Not a git repository: $Path"
        return
    }
    
    Push-Location $Path
    
    try {
        Write-Host "`nGit Status for: $Path" -ForegroundColor Cyan
        
        # Get git status
        $status = git status --porcelain 2>$null
        
        if (-not $status) {
            Write-Host "Working tree clean" -ForegroundColor Green
            return
        }
        
        $results = @()
        foreach ($line in $status) {
            $statusCode = $line.Substring(0, 2)
            $filePath = $line.Substring(3)
            
            $statusText = switch ($statusCode.Trim()) {
                'M' { 'Modified' }
                'A' { 'Added' }
                'D' { 'Deleted' }
                'R' { 'Renamed' }
                'C' { 'Copied' }
                'U' { 'Updated' }
                '??' { 'Untracked' }
                default { $statusCode }
            }
            
            $color = switch ($statusCode.Trim()) {
                'M' { 'Yellow' }
                'A' { 'Green' }
                'D' { 'Red' }
                '??' { 'Gray' }
                default { 'White' }
            }
            
            Write-Host "  [$statusText] $filePath" -ForegroundColor $color
            
            $results += [PSCustomObject]@{
                Status = $statusText
                File = $filePath
                FullPath = Join-Path $Path $filePath
            }
        }
        
        return $results
        
    } finally {
        Pop-Location
    }
}

function Invoke-GitDiff {
    <#
    .SYNOPSIS
        Shows git diff for a file
    .PARAMETER File
        File path
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$File
    )
    
    git diff $File | Write-Host
}

Export-ModuleMember -Function Get-GitStatus, Invoke-GitDiff
