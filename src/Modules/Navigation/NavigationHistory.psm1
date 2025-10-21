#Requires -Version 7.0

# Navigation History Module - Directory history and quick jump

$script:NavigationHistory = [System.Collections.ArrayList]::new()
$script:CurrentIndex = -1
$script:MaxHistory = 100

function Add-NavigationHistory {
    <#
    .SYNOPSIS
        Adds a location to navigation history
    .PARAMETER Path
        Path to add to history
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    # Remove future history if we're not at the end
    if ($script:CurrentIndex -lt $script:NavigationHistory.Count - 1) {
        $script:NavigationHistory.RemoveRange($script:CurrentIndex + 1, 
            $script:NavigationHistory.Count - $script:CurrentIndex - 1)
    }
    
    $script:NavigationHistory.Add($Path) | Out-Null
    $script:CurrentIndex = $script:NavigationHistory.Count - 1
    
    # Trim if exceeds max
    if ($script:NavigationHistory.Count -gt $script:MaxHistory) {
        $script:NavigationHistory.RemoveAt(0)
        $script:CurrentIndex--
    }
}

function Get-NavigationHistory {
    <#
    .SYNOPSIS
        Gets navigation history
    .EXAMPLE
        Get-NavigationHistory
        Shows navigation history
    #>
    [CmdletBinding()]
    param()
    
    return $script:NavigationHistory
}

function Invoke-NavigationBack {
    <#
    .SYNOPSIS
        Navigates to previous location
    #>
    [CmdletBinding()]
    param()
    
    if ($script:CurrentIndex -gt 0) {
        $script:CurrentIndex--
        $path = $script:NavigationHistory[$script:CurrentIndex]
        Set-Location $path
        Write-Host "Navigated back to: $path" -ForegroundColor Cyan
        return $path
    } else {
        Write-Host "No previous location in history" -ForegroundColor Yellow
    }
}

function Invoke-NavigationForward {
    <#
    .SYNOPSIS
        Navigates to next location
    #>
    [CmdletBinding()]
    param()
    
    if ($script:CurrentIndex -lt $script:NavigationHistory.Count - 1) {
        $script:CurrentIndex++
        $path = $script:NavigationHistory[$script:CurrentIndex]
        Set-Location $path
        Write-Host "Navigated forward to: $path" -ForegroundColor Cyan
        return $path
    } else {
        Write-Host "No next location in history" -ForegroundColor Yellow
    }
}

Export-ModuleMember -Function Add-NavigationHistory, Get-NavigationHistory, `
    Invoke-NavigationBack, Invoke-NavigationForward
