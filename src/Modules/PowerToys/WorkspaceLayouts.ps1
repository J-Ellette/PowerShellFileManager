#Requires -Version 7.0

<#
.SYNOPSIS
    Workspace Layouts - Window and workspace management (FancyZones integration)
    PowerToys Integration

.DESCRIPTION
    Provides workspace layout management, window arrangement, and
    multi-monitor workspace configurations.

.NOTES
    Author: PowerShell File Manager V2.0
    Version: 1.0.0
    Requires: Windows OS
#>

$script:WorkspaceLayouts = @{
    'TwoColumns' = @{
        Name = 'Two Columns'
        Description = '50/50 vertical split'
        Zones = @(
            @{ X = 0; Y = 0; Width = 50; Height = 100 }
            @{ X = 50; Y = 0; Width = 50; Height = 100 }
        )
    }
    'ThreeColumns' = @{
        Name = 'Three Columns'
        Description = '33/33/33 vertical split'
        Zones = @(
            @{ X = 0; Y = 0; Width = 33; Height = 100 }
            @{ X = 33; Y = 0; Width = 34; Height = 100 }
            @{ X = 67; Y = 0; Width = 33; Height = 100 }
        )
    }
    'GridFour' = @{
        Name = 'Grid (4 zones)'
        Description = '2x2 grid layout'
        Zones = @(
            @{ X = 0; Y = 0; Width = 50; Height = 50 }
            @{ X = 50; Y = 0; Width = 50; Height = 50 }
            @{ X = 0; Y = 50; Width = 50; Height = 50 }
            @{ X = 50; Y = 50; Width = 50; Height = 50 }
        )
    }
    'PriorityGrid' = @{
        Name = 'Priority Grid'
        Description = 'Large left, small right stacked'
        Zones = @(
            @{ X = 0; Y = 0; Width = 70; Height = 100 }
            @{ X = 70; Y = 0; Width = 30; Height = 50 }
            @{ X = 70; Y = 50; Width = 30; Height = 50 }
        )
    }
}

function Get-WorkspaceLayout {
    <#
    .SYNOPSIS
        Get available workspace layouts
    
    .DESCRIPTION
        Returns predefined workspace layout configurations
    
    .PARAMETER Name
        Specific layout name to retrieve
    
    .EXAMPLE
        Get-WorkspaceLayout
        Get all available layouts
    #>
    [CmdletBinding()]
    param(
        [string]$Name
    )
    
    if ($Name) {
        if ($script:WorkspaceLayouts.ContainsKey($Name)) {
            $layout = $script:WorkspaceLayouts[$Name]
            [PSCustomObject]@{
                Name = $Name
                DisplayName = $layout.Name
                Description = $layout.Description
                Zones = $layout.Zones
            }
        } else {
            Write-Error "Layout not found: $Name"
        }
    } else {
        $script:WorkspaceLayouts.Keys | ForEach-Object {
            $layout = $script:WorkspaceLayouts[$_]
            [PSCustomObject]@{
                Name = $_
                DisplayName = $layout.Name
                Description = $layout.Description
                ZoneCount = $layout.Zones.Count
            }
        }
    }
}

function Set-WindowLayout {
    <#
    .SYNOPSIS
        Arrange windows according to a workspace layout
    
    .DESCRIPTION
        Position open windows into zones based on selected layout
    
    .PARAMETER LayoutName
        Name of the layout to apply
    
    .PARAMETER ProcessName
        Filter windows by process name
    
    .EXAMPLE
        Set-WindowLayout -LayoutName TwoColumns
        Arrange windows in two column layout
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('TwoColumns', 'ThreeColumns', 'GridFour', 'PriorityGrid')]
        [string]$LayoutName,
        
        [string[]]$ProcessName
    )
    
    if (-not ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5)) {
        Write-Error "Window layout management is only supported on Windows"
        return
    }
    
    $layout = Get-WorkspaceLayout -Name $LayoutName
    if (-not $layout) { return }
    
    # Get target windows
    $windows = if ($ProcessName) {
        Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | 
            Where-Object { $_.MainWindowHandle -ne 0 }
    } else {
        Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle }
    }
    
    if (-not $windows) {
        Write-Warning "No windows found to arrange"
        return
    }
    
    # Get screen dimensions
    Add-Type -AssemblyName System.Windows.Forms
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    
    # Arrange windows in zones
    $zoneIndex = 0
    foreach ($window in $windows) {
        if ($zoneIndex -ge $layout.Zones.Count) { break }
        
        $zone = $layout.Zones[$zoneIndex]
        
        $x = [int]($screen.Left + ($screen.Width * $zone.X / 100))
        $y = [int]($screen.Top + ($screen.Height * $zone.Y / 100))
        $width = [int]($screen.Width * $zone.Width / 100)
        $height = [int]($screen.Height * $zone.Height / 100)
        
        if ($PSCmdlet.ShouldProcess($window.MainWindowTitle, "Move to zone $($zoneIndex + 1)")) {
            try {
                Add-Type -TypeDefinition @"
                using System;
                using System.Runtime.InteropServices;
                public class WinAPI {
                    [DllImport("user32.dll")]
                    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
                }
"@ -ErrorAction SilentlyContinue
                
                [WinAPI]::MoveWindow($window.MainWindowHandle, $x, $y, $width, $height, $true) | Out-Null
                
                Write-Verbose "Moved $($window.MainWindowTitle) to zone $($zoneIndex + 1)"
            } catch {
                Write-Error "Failed to move window: $_"
            }
        }
        
        $zoneIndex++
    }
    
    Write-Host "Applied layout: $($layout.DisplayName)" -ForegroundColor Green
}

function Save-WorkspaceSnapshot {
    <#
    .SYNOPSIS
        Save current window positions as a workspace snapshot
    
    .DESCRIPTION
        Captures current window positions and sizes for later restoration
    
    .PARAMETER Name
        Name for the workspace snapshot
    
    .EXAMPLE
        Save-WorkspaceSnapshot -Name "Development"
        Save current workspace as "Development"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )
    
    $windows = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle } |
        Select-Object ProcessName, MainWindowTitle, MainWindowHandle
    
    $snapshot = @{
        Name = $Name
        Timestamp = Get-Date
        Windows = $windows
    }
    
    $snapshotPath = Join-Path $env:TEMP "workspace_$Name.json"
    $snapshot | ConvertTo-Json -Depth 10 | Set-Content $snapshotPath
    
    Write-Host "Workspace snapshot saved: $snapshotPath" -ForegroundColor Green
    
    [PSCustomObject]@{
        Name = $Name
        WindowCount = $windows.Count
        Path = $snapshotPath
        Timestamp = $snapshot.Timestamp
    }
}

function Show-WorkspaceLayoutMenu {
    <#
    .SYNOPSIS
        Display interactive workspace layout menu
    
    .DESCRIPTION
        Shows menu to select and apply workspace layouts
    
    .EXAMPLE
        Show-WorkspaceLayoutMenu
        Launch the workspace layout selector
    #>
    [CmdletBinding()]
    param()
    
    Clear-Host
    Write-Host "`nWorkspace Layout Manager" -ForegroundColor Cyan
    Write-Host "=" * 50
    
    $layouts = Get-WorkspaceLayout
    
    Write-Host "`nAvailable Layouts:" -ForegroundColor Yellow
    $index = 1
    foreach ($layout in $layouts) {
        Write-Host "$index. $($layout.DisplayName) - $($layout.Description) ($($layout.ZoneCount) zones)"
        $index++
    }
    Write-Host "Q. Quit"
    
    $choice = Read-Host "`nSelect layout (1-$($layouts.Count))"
    
    if ($choice -match '^\d+$' -and [int]$choice -le $layouts.Count) {
        $selectedLayout = $layouts[[int]$choice - 1]
        Set-WindowLayout -LayoutName $selectedLayout.Name
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Get-WorkspaceLayout'
    'Set-WindowLayout'
    'Save-WorkspaceSnapshot'
    'Show-WorkspaceLayoutMenu'
)
