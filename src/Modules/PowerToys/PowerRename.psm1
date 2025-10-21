#Requires -Version 7.0

<#
.SYNOPSIS
    PowerRename - Advanced batch file renaming
    PowerToys Integration

.DESCRIPTION
    Provides advanced batch renaming capabilities with regex support,
    find/replace, case conversion, numbering, and preview functionality.

.NOTES
    Author: PowerShell File Manager V2.0
    Version: 1.0.0
#>

function Invoke-PowerRename {
    <#
    .SYNOPSIS
        Advanced batch file/folder renaming with preview
    
    .DESCRIPTION
        Rename multiple files/folders using find/replace, regex, case conversion,
        and numbering patterns with preview before applying changes.
    
    .PARAMETER Path
        Path to files/folders to rename (supports wildcards)
    
    .PARAMETER Find
        Text or regex pattern to find
    
    .PARAMETER Replace
        Replacement text (supports capture groups with regex)
    
    .PARAMETER UseRegex
        Enable regex mode for find/replace
    
    .PARAMETER CaseConversion
        Convert case: Upper, Lower, Title, or None
    
    .PARAMETER AddNumbering
        Add sequential numbering
    
    .PARAMETER NumberingStart
        Starting number for sequence (default: 1)
    
    .PARAMETER NumberingPadding
        Zero-padding for numbers (default: 0)
    
    .PARAMETER Preview
        Show preview without applying changes
    
    .PARAMETER IncludeFolders
        Include folders in renaming operation
    
    .EXAMPLE
        Invoke-PowerRename -Path "C:\Photos\*.jpg" -Find "IMG_" -Replace "Photo_" -Preview
        Preview renaming all JPG files
    
    .EXAMPLE
        Invoke-PowerRename -Path "*.txt" -Find "(\d+)" -Replace "File_$1" -UseRegex
        Regex-based renaming with capture groups
    
    .EXAMPLE
        Invoke-PowerRename -Path "*.md" -CaseConversion Title -AddNumbering -NumberingStart 1 -NumberingPadding 3
        Convert to title case and add numbered prefix (001_, 002_, etc.)
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string[]]$Path,
        
        [string]$Find,
        
        [string]$Replace,
        
        [switch]$UseRegex,
        
        [ValidateSet('None', 'Upper', 'Lower', 'Title')]
        [string]$CaseConversion = 'None',
        
        [switch]$AddNumbering,
        
        [int]$NumberingStart = 1,
        
        [int]$NumberingPadding = 0,
        
        [switch]$Preview,
        
        [switch]$IncludeFolders
    )
    
    begin {
        $counter = $NumberingStart
        $results = @()
    }
    
    process {
        foreach ($itemPath in $Path) {
            try {
                $items = Get-ChildItem -Path $itemPath -ErrorAction Stop
                
                if (-not $IncludeFolders) {
                    $items = $items | Where-Object { -not $_.PSIsContainer }
                }
                
                foreach ($item in $items) {
                    $newName = $item.Name
                    
                    # Apply find/replace
                    if ($Find) {
                        if ($UseRegex) {
                            $newName = $newName -replace $Find, $Replace
                        } else {
                            $newName = $newName.Replace($Find, $Replace)
                        }
                    }
                    
                    # Apply case conversion
                    switch ($CaseConversion) {
                        'Upper' { 
                            $ext = [System.IO.Path]::GetExtension($newName)
                            $base = [System.IO.Path]::GetFileNameWithoutExtension($newName)
                            $newName = $base.ToUpper() + $ext 
                        }
                        'Lower' { 
                            $ext = [System.IO.Path]::GetExtension($newName)
                            $base = [System.IO.Path]::GetFileNameWithoutExtension($newName)
                            $newName = $base.ToLower() + $ext 
                        }
                        'Title' { 
                            $ext = [System.IO.Path]::GetExtension($newName)
                            $base = [System.IO.Path]::GetFileNameWithoutExtension($newName)
                            $culture = [System.Globalization.CultureInfo]::CurrentCulture
                            $textInfo = $culture.TextInfo
                            $newName = $textInfo.ToTitleCase($base.ToLower()) + $ext 
                        }
                    }
                    
                    # Add numbering
                    if ($AddNumbering) {
                        $ext = [System.IO.Path]::GetExtension($newName)
                        $base = [System.IO.Path]::GetFileNameWithoutExtension($newName)
                        $numberStr = $counter.ToString().PadLeft($NumberingPadding, '0')
                        $newName = "${numberStr}_${base}${ext}"
                        $counter++
                    }
                    
                    # Create result object
                    $result = [PSCustomObject]@{
                        OriginalPath = $item.FullName
                        OriginalName = $item.Name
                        NewName = $newName
                        Changed = ($item.Name -ne $newName)
                        Type = if ($item.PSIsContainer) { 'Folder' } else { 'File' }
                        Status = 'Pending'
                    }
                    
                    # Apply changes if not in preview mode
                    if (-not $Preview -and $result.Changed) {
                        if ($PSCmdlet.ShouldProcess($item.FullName, "Rename to '$newName'")) {
                            try {
                                Rename-Item -Path $item.FullName -NewName $newName -ErrorAction Stop
                                $result.Status = 'Success'
                                Write-Verbose "Renamed: $($item.Name) -> $newName"
                            } catch {
                                $result.Status = 'Failed'
                                $result | Add-Member -NotePropertyName 'Error' -NotePropertyValue $_.Exception.Message
                                Write-Error "Failed to rename $($item.Name): $_"
                            }
                        }
                    } elseif ($Preview) {
                        $result.Status = 'Preview'
                    } else {
                        $result.Status = 'NoChange'
                    }
                    
                    $results += $result
                }
            } catch {
                Write-Error "Failed to process $itemPath : $_"
            }
        }
    }
    
    end {
        # Display summary
        $changedCount = ($results | Where-Object { $_.Changed }).Count
        
        if ($Preview) {
            Write-Host "`nRename Preview:" -ForegroundColor Cyan
            $results | Where-Object { $_.Changed } | Format-Table -Property OriginalName, NewName, Type -AutoSize
            Write-Host "`nTotal changes: $changedCount" -ForegroundColor Yellow
            Write-Host "Run without -Preview to apply changes" -ForegroundColor Yellow
        } else {
            $successCount = ($results | Where-Object { $_.Status -eq 'Success' }).Count
            Write-Host "`nRename Complete:" -ForegroundColor Green
            Write-Host "  Successfully renamed: $successCount files/folders" -ForegroundColor Cyan
        }
        
        return $results
    }
}

function New-RenamePattern {
    <#
    .SYNOPSIS
        Create a reusable rename pattern
    
    .DESCRIPTION
        Defines a named rename pattern that can be saved and reused
    
    .PARAMETER Name
        Name for the pattern
    
    .PARAMETER Find
        Find pattern
    
    .PARAMETER Replace
        Replace pattern
    
    .PARAMETER UseRegex
        Enable regex
    
    .PARAMETER CaseConversion
        Case conversion option
    
    .EXAMPLE
        New-RenamePattern -Name "PhotoCleanup" -Find "IMG_" -Replace "Photo_" -CaseConversion Title
        Create a reusable pattern
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [string]$Find,
        [string]$Replace,
        [switch]$UseRegex,
        
        [ValidateSet('None', 'Upper', 'Lower', 'Title')]
        [string]$CaseConversion = 'None'
    )
    
    $pattern = @{
        Name = $Name
        Find = $Find
        Replace = $Replace
        UseRegex = $UseRegex.IsPresent
        CaseConversion = $CaseConversion
        Created = Get-Date
    }
    
    [PSCustomObject]$pattern
}

# Export module members
Export-ModuleMember -Function @(
    'Invoke-PowerRename'
    'New-RenamePattern'
)
