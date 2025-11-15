#Requires -Version 7.0

<#
.SYNOPSIS
    Keyboard Shortcut Guide - Display available keyboard shortcuts
    PowerToys Integration

.DESCRIPTION
    Provides a comprehensive guide to keyboard shortcuts available
    in the PowerShell File Manager and Windows system.

.NOTES
    Author: PowerShell File Manager V2.0
    Version: 1.0.0
#>

$script:FileManagerShortcuts = @{
    'Navigation' = @(
        @{ Key = 'Ctrl+P'; Description = 'Open Command Palette' }
        @{ Key = 'F5'; Description = 'Refresh current view' }
        @{ Key = 'Alt+Left'; Description = 'Navigate back' }
        @{ Key = 'Alt+Right'; Description = 'Navigate forward' }
        @{ Key = 'Ctrl+L'; Description = 'Focus address bar' }
    )
    'File Operations' = @(
        @{ Key = 'Ctrl+C'; Description = 'Copy selected items' }
        @{ Key = 'Ctrl+X'; Description = 'Cut selected items' }
        @{ Key = 'Ctrl+V'; Description = 'Paste items' }
        @{ Key = 'Delete'; Description = 'Delete selected items' }
        @{ Key = 'Shift+Delete'; Description = 'Permanently delete items' }
        @{ Key = 'Ctrl+A'; Description = 'Select all items' }
        @{ Key = 'F2'; Description = 'Rename selected item' }
        @{ Key = 'Ctrl+N'; Description = 'New file/folder' }
    )
    'View' = @(
        @{ Key = 'Ctrl+='; Description = 'Zoom in' }
        @{ Key = 'Ctrl+-'; Description = 'Zoom out' }
        @{ Key = 'Ctrl+0'; Description = 'Reset zoom' }
        @{ Key = 'F11'; Description = 'Toggle fullscreen' }
    )
    'Tools' = @(
        @{ Key = 'Ctrl+F'; Description = 'Search/Find' }
        @{ Key = 'Ctrl+Shift+F'; Description = 'Advanced search' }
        @{ Key = 'Ctrl+T'; Description = 'Open terminal' }
        @{ Key = 'Ctrl+Shift+T'; Description = 'Task Manager' }
    )
}

$script:WindowsShortcuts = @{
    'General' = @(
        @{ Key = 'Win+E'; Description = 'Open File Explorer' }
        @{ Key = 'Win+D'; Description = 'Show desktop' }
        @{ Key = 'Win+L'; Description = 'Lock computer' }
        @{ Key = 'Win+I'; Description = 'Open Settings' }
        @{ Key = 'Win+X'; Description = 'Quick Link menu' }
        @{ Key = 'Alt+Tab'; Description = 'Switch between windows' }
        @{ Key = 'Alt+F4'; Description = 'Close active window' }
        @{ Key = 'Ctrl+Shift+Esc'; Description = 'Open Task Manager' }
    )
    'Virtual Desktops' = @(
        @{ Key = 'Win+Ctrl+D'; Description = 'Create new virtual desktop' }
        @{ Key = 'Win+Ctrl+F4'; Description = 'Close current desktop' }
        @{ Key = 'Win+Ctrl+Left/Right'; Description = 'Switch virtual desktop' }
    )
    'Window Management' = @(
        @{ Key = 'Win+Left/Right'; Description = 'Snap window to side' }
        @{ Key = 'Win+Up'; Description = 'Maximize window' }
        @{ Key = 'Win+Down'; Description = 'Minimize/Restore window' }
        @{ Key = 'Win+M'; Description = 'Minimize all windows' }
    )
}

function Get-KeyboardShortcut {
    <#
    .SYNOPSIS
        Get available keyboard shortcuts
    
    .DESCRIPTION
        Returns categorized list of keyboard shortcuts
    
    .PARAMETER Category
        Filter by category (FileManager or Windows)
    
    .EXAMPLE
        Get-KeyboardShortcut
        Get all keyboard shortcuts
    
    .EXAMPLE
        Get-KeyboardShortcut -Category FileManager
        Get only File Manager shortcuts
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('FileManager', 'Windows', 'All')]
        [string]$Category = 'All'
    )
    
    $results = @()
    
    if ($Category -in 'FileManager', 'All') {
        foreach ($cat in $script:FileManagerShortcuts.Keys) {
            foreach ($shortcut in $script:FileManagerShortcuts[$cat]) {
                $results += [PSCustomObject]@{
                    Source = 'File Manager'
                    Category = $cat
                    Key = $shortcut.Key
                    Description = $shortcut.Description
                }
            }
        }
    }
    
    if ($Category -in 'Windows', 'All') {
        foreach ($cat in $script:WindowsShortcuts.Keys) {
            foreach ($shortcut in $script:WindowsShortcuts[$cat]) {
                $results += [PSCustomObject]@{
                    Source = 'Windows'
                    Category = $cat
                    Key = $shortcut.Key
                    Description = $shortcut.Description
                }
            }
        }
    }
    
    return $results
}

function Show-ShortcutGuide {
    <#
    .SYNOPSIS
        Display interactive keyboard shortcut guide
    
    .DESCRIPTION
        Shows a formatted guide of all available keyboard shortcuts
    
    .PARAMETER Category
        Show specific category only
    
    .EXAMPLE
        Show-ShortcutGuide
        Display complete shortcut guide
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('FileManager', 'Windows', 'All')]
        [string]$Category = 'All'
    )
    
    Clear-Host
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║        KEYBOARD SHORTCUT GUIDE                       ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    if ($Category -in 'FileManager', 'All') {
        Write-Host "`n█ FILE MANAGER SHORTCUTS █" -ForegroundColor Yellow
        foreach ($cat in $script:FileManagerShortcuts.Keys) {
            Write-Host "`n  ► $cat" -ForegroundColor Green
            foreach ($shortcut in $script:FileManagerShortcuts[$cat]) {
                Write-Host "    $($shortcut.Key.PadRight(20)) - $($shortcut.Description)" -ForegroundColor White
            }
        }
    }
    
    if ($Category -in 'Windows', 'All') {
        Write-Host "`n█ WINDOWS SHORTCUTS █" -ForegroundColor Yellow
        foreach ($cat in $script:WindowsShortcuts.Keys) {
            Write-Host "`n  ► $cat" -ForegroundColor Green
            foreach ($shortcut in $script:WindowsShortcuts[$cat]) {
                Write-Host "    $($shortcut.Key.PadRight(20)) - $($shortcut.Description)" -ForegroundColor White
            }
        }
    }
    
    Write-Host "`n" -NoNewline
    Read-Host "Press Enter to continue"
}

function Find-Shortcut {
    <#
    .SYNOPSIS
        Search for shortcuts by keyword
    
    .DESCRIPTION
        Find keyboard shortcuts matching a search term
    
    .PARAMETER SearchTerm
        Search term to match against key or description
    
    .EXAMPLE
        Find-Shortcut -SearchTerm "copy"
        Find all shortcuts related to copying
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SearchTerm
    )
    
    $allShortcuts = Get-KeyboardShortcut -Category All
    
    $results = $allShortcuts | Where-Object {
        $_.Key -like "*$SearchTerm*" -or $_.Description -like "*$SearchTerm*"
    }
    
    if ($results) {
        Write-Host "`nSearch results for: $SearchTerm" -ForegroundColor Cyan
        $results | Format-Table -Property Source, Category, Key, Description -AutoSize
    } else {
        Write-Host "No shortcuts found matching: $SearchTerm" -ForegroundColor Yellow
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Get-KeyboardShortcut'
    'Show-ShortcutGuide'
    'Find-Shortcut'
)
