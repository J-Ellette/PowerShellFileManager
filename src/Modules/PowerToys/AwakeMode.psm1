#Requires -Version 7.0

<#
.SYNOPSIS
    Awake Mode - Keep system awake during operations
    PowerToys Integration

.DESCRIPTION
    Prevents system sleep and screen timeout during long-running operations.
    Useful for downloads, backups, and other lengthy tasks.

.NOTES
    Author: PowerShell File Manager V2.0
    Version: 1.0.0
    Cross-Platform: Windows, Linux, macOS
#>

$script:AwakeState = @{
    IsActive = $false
    StartTime = $null
    Mode = 'None'
}

function Enable-AwakeMode {
    <#
    .SYNOPSIS
        Enable awake mode to prevent system sleep
    
    .DESCRIPTION
        Keeps the system awake by preventing sleep and screen timeout.
        On Windows, uses SetThreadExecutionState API.
    
    .PARAMETER Mode
        Awake mode: Display (keep screen on), System (prevent sleep), or Both
    
    .PARAMETER Duration
        Optional duration in minutes (indefinite if not specified)
    
    .EXAMPLE
        Enable-AwakeMode -Mode Both
        Keep system and display awake
    
    .EXAMPLE
        Enable-AwakeMode -Mode System -Duration 60
        Keep system awake for 60 minutes
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Display', 'System', 'Both')]
        [string]$Mode = 'Both',
        
        [int]$Duration
    )
    
    if ($script:AwakeState.IsActive) {
        Write-Warning "Awake mode is already active"
        return
    }
    
    $isWindowsPlatform = $IsWindows -or $PSVersionTable.PSVersion.Major -le 5
    
    if ($isWindowsPlatform) {
        # Windows: Use SetThreadExecutionState
        Add-Type -TypeDefinition @'
        using System;
        using System.Runtime.InteropServices;
        
        public class PowerAPI {
            [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
            public static extern uint SetThreadExecutionState(uint esFlags);
            
            public const uint ES_CONTINUOUS = 0x80000000;
            public const uint ES_SYSTEM_REQUIRED = 0x00000001;
            public const uint ES_DISPLAY_REQUIRED = 0x00000002;
        }
'@ -ErrorAction SilentlyContinue
        
        $flags = [PowerAPI]::ES_CONTINUOUS
        
        switch ($Mode) {
            'Display' { $flags = $flags -bor [PowerAPI]::ES_DISPLAY_REQUIRED }
            'System' { $flags = $flags -bor [PowerAPI]::ES_SYSTEM_REQUIRED }
            'Both' { 
                $flags = $flags -bor [PowerAPI]::ES_SYSTEM_REQUIRED -bor [PowerAPI]::ES_DISPLAY_REQUIRED 
            }
        }
        
        $result = [PowerAPI]::SetThreadExecutionState($flags)
        
        if ($result -eq 0) {
            Write-Error "Failed to enable awake mode"
            return
        }
        
    } else {
        # Linux/macOS: Try caffeine or caffeinate
        if ($IsMacOS) {
            try {
                Start-Process caffeinate -ArgumentList "-d" -NoNewWindow -PassThru | Out-Null
                Write-Verbose "Started caffeinate on macOS"
            } catch {
                Write-Warning "caffeinate not available. Awake mode may not work on macOS."
            }
        } elseif ($IsLinux) {
            try {
                # Check for caffeine or xset
                if (Get-Command caffeine -ErrorAction SilentlyContinue) {
                    Start-Process caffeine -NoNewWindow -PassThru | Out-Null
                } else {
                    Write-Warning "caffeine not installed. Install with: sudo apt install caffeine"
                }
            } catch {
                Write-Warning "Could not enable awake mode on Linux"
            }
        }
    }
    
    $script:AwakeState.IsActive = $true
    $script:AwakeState.StartTime = Get-Date
    $script:AwakeState.Mode = $Mode
    
    Write-Host "✓ Awake mode enabled ($Mode)" -ForegroundColor Green
    if ($Duration) {
        Write-Host "  Duration: $Duration minutes" -ForegroundColor Cyan
        
        # Schedule automatic disable
        Start-Job -ScriptBlock {
            param($Minutes)
            Start-Sleep -Seconds ($Minutes * 60)
            Disable-AwakeMode
        } -ArgumentList $Duration | Out-Null
    } else {
        Write-Host "  Duration: Indefinite (call Disable-AwakeMode to stop)" -ForegroundColor Cyan
    }
    
    [PSCustomObject]@{
        Status = 'Active'
        Mode = $Mode
        StartTime = $script:AwakeState.StartTime
        Duration = if ($Duration) { "$Duration minutes" } else { "Indefinite" }
    }
}

function Disable-AwakeMode {
    <#
    .SYNOPSIS
        Disable awake mode and restore normal power settings
    
    .DESCRIPTION
        Restores normal system sleep and screen timeout behavior
    
    .EXAMPLE
        Disable-AwakeMode
        Disable awake mode
    #>
    [CmdletBinding()]
    param()
    
    if (-not $script:AwakeState.IsActive) {
        Write-Warning "Awake mode is not active"
        return
    }
    
    $isWindowsPlatform = $IsWindows -or $PSVersionTable.PSVersion.Major -le 5
    
    if ($isWindowsPlatform) {
        # Reset execution state
        [PowerAPI]::SetThreadExecutionState([PowerAPI]::ES_CONTINUOUS) | Out-Null
    } else {
        # Kill caffeine/caffeinate processes
        if ($IsMacOS) {
            Get-Process -Name "caffeinate" -ErrorAction SilentlyContinue | Stop-Process -Force
        } elseif ($IsLinux) {
            Get-Process -Name "caffeine" -ErrorAction SilentlyContinue | Stop-Process -Force
        }
    }
    
    $duration = (Get-Date) - $script:AwakeState.StartTime
    
    $script:AwakeState.IsActive = $false
    $script:AwakeState.StartTime = $null
    $script:AwakeState.Mode = 'None'
    
    Write-Host "✓ Awake mode disabled" -ForegroundColor Green
    Write-Host "  Active duration: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
    
    [PSCustomObject]@{
        Status = 'Disabled'
        Duration = $duration.ToString('hh\:mm\:ss')
    }
}

function Get-AwakeStatus {
    <#
    .SYNOPSIS
        Get current awake mode status
    
    .DESCRIPTION
        Returns information about current awake mode state
    
    .EXAMPLE
        Get-AwakeStatus
        Check awake mode status
    #>
    [CmdletBinding()]
    param()
    
    if ($script:AwakeState.IsActive) {
        $duration = (Get-Date) - $script:AwakeState.StartTime
        
        [PSCustomObject]@{
            Status = 'Active'
            Mode = $script:AwakeState.Mode
            StartTime = $script:AwakeState.StartTime
            Duration = $duration.ToString('hh\:mm\:ss')
            IsActive = $true
        }
    } else {
        [PSCustomObject]@{
            Status = 'Inactive'
            IsActive = $false
        }
    }
}

function Invoke-WithAwakeMode {
    <#
    .SYNOPSIS
        Execute a script block with awake mode enabled
    
    .DESCRIPTION
        Runs a script block with awake mode automatically enabled and disabled
    
    .PARAMETER ScriptBlock
        Script block to execute
    
    .PARAMETER Mode
        Awake mode to use
    
    .EXAMPLE
        Invoke-WithAwakeMode -ScriptBlock { Start-Sleep 300; Write-Host "Done" } -Mode Both
        Run long operation with awake mode
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,
        
        [ValidateSet('Display', 'System', 'Both')]
        [string]$Mode = 'Both'
    )
    
    try {
        Enable-AwakeMode -Mode $Mode
        & $ScriptBlock
    } finally {
        Disable-AwakeMode
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Enable-AwakeMode'
    'Disable-AwakeMode'
    'Get-AwakeStatus'
    'Invoke-WithAwakeMode'
)
