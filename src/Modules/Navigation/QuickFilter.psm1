#Requires -Version 7.0

# Quick Filter Module - Real-time filtering of current directory

function Invoke-QuickFilter {
    <#
    .SYNOPSIS
        Filters current directory in real-time
    .PARAMETER Filter
        Filter pattern
    .EXAMPLE
        Invoke-QuickFilter -Filter "*.txt"
        Shows only text files
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Filter
    )
    
    $items = Get-ChildItem -Path $pwd | Where-Object { $_.Name -like "*$Filter*" }
    
    Write-Host "`nFiltered Results ($($items.Count) items):" -ForegroundColor Cyan
    $items | Format-Table -AutoSize
    
    return $items
}

Export-ModuleMember -Function Invoke-QuickFilter
