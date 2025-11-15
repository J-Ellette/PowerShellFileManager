<#
.SYNOPSIS
    Always On Top - Window Pinning Module
    PowerToys Integration - Item 46

.DESCRIPTION
    Provides functionality to pin windows always on top using Windows API.
    Allows toggling the WS_EX_TOPMOST extended window style for any window.

.NOTES
    Author: PowerShell File Manager V2.0
    Version: 1.0.0
    Requires: Windows OS with User32.dll
#>

# Windows API definitions
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class WindowHelper {
    private const int GWL_EXSTYLE = -20;
    private const int WS_EX_TOPMOST = 0x0008;
    private const int HWND_TOPMOST = -1;
    private const int HWND_NOTOPMOST = -2;
    private const int SWP_NOMOVE = 0x0002;
    private const int SWP_NOSIZE = 0x0001;

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll")]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter,
        int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool IsWindow(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    public static bool IsWindowTopMost(IntPtr hWnd) {
        int exStyle = GetWindowLong(hWnd, GWL_EXSTYLE);
        return (exStyle & WS_EX_TOPMOST) == WS_EX_TOPMOST;
    }

    public static bool SetTopMost(IntPtr hWnd, bool topMost) {
        IntPtr hWndInsertAfter = topMost ? (IntPtr)HWND_TOPMOST : (IntPtr)HWND_NOTOPMOST;
        return SetWindowPos(hWnd, hWndInsertAfter, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
    }

    public static string GetWindowTitle(IntPtr hWnd) {
        int length = GetWindowTextLength(hWnd);
        if (length == 0) return string.Empty;

        System.Text.StringBuilder sb = new System.Text.StringBuilder(length + 1);
        GetWindowText(hWnd, sb, sb.Capacity);
        return sb.ToString();
    }
}
"@

function Set-WindowAlwaysOnTop {
    <#
    .SYNOPSIS
        Sets a window to be always on top or removes the always on top status

    .DESCRIPTION
        Uses Windows API to set the WS_EX_TOPMOST extended window style,
        making the window stay on top of other windows

    .PARAMETER WindowHandle
        The handle (HWND) of the window to modify

    .PARAMETER Enable
        If specified, enables always on top. Otherwise, disables it.

    .PARAMETER ProcessId
        The process ID of the window to pin. If not specified, uses the current PowerShell window.

    .PARAMETER WindowTitle
        The title of the window to pin. Searches for a window with this title.

    .EXAMPLE
        Set-WindowAlwaysOnTop -Enable
        Pins the current PowerShell window on top

    .EXAMPLE
        Set-WindowAlwaysOnTop -WindowTitle "PowerShell File Manager" -Enable
        Pins the file manager window on top

    .EXAMPLE
        Set-WindowAlwaysOnTop -ProcessId 1234 -Enable
        Pins the window belonging to process ID 1234

    .OUTPUTS
        [PSCustomObject] with Status, WindowHandle, WindowTitle, IsTopMost properties
    #>
    [CmdletBinding(DefaultParameterSetName='Current', SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param(
        [Parameter(ParameterSetName='Handle', Mandatory=$true)]
        [IntPtr]$WindowHandle,

        [Parameter(ParameterSetName='ProcessId')]
        [int]$ProcessId,

        [Parameter(ParameterSetName='Title')]
        [string]$WindowTitle,

        [Parameter()]
        [switch]$Enable,
        [Parameter()]
        [ValidateSet('Like','Exact')]
        [string]$TitleMatch = 'Like'
    )

    try {
        # Determine which window to target
        $hWnd = $null

        switch ($PSCmdlet.ParameterSetName) {
            'Handle' {
                $hWnd = $WindowHandle
            }
            'ProcessId' {
                # Find window by process ID
                $process = Get-Process -Id $ProcessId -ErrorAction Stop
                $hWnd = $process.MainWindowHandle
                if ($hWnd -eq [IntPtr]::Zero) {
                    throw "Process $ProcessId does not have a main window"
                }
            }
            'Title' {
                # Find window by title (search all processes)
                $processes = if ($TitleMatch -eq 'Exact') { Get-Process | Where-Object { $_.MainWindowTitle -eq $WindowTitle } } else { Get-Process | Where-Object { $_.MainWindowTitle -like "*$WindowTitle*" } }
                if ($processes.Count -eq 0) {
                    throw "No window found with title matching '$WindowTitle'"
                }
                if ($processes.Count -gt 1) {
                    Write-Warning "Multiple windows found matching '$WindowTitle'. Using first match."
                }
                $hWnd = $processes[0].MainWindowHandle
            }
            'Current' {
                # Use current foreground window (likely PowerShell window)
                $hWnd = [WindowHelper]::GetForegroundWindow()
            }
        }

        # Validate window handle
        if ($hWnd -eq [IntPtr]::Zero -or -not [WindowHelper]::IsWindow($hWnd)) {
            throw "Invalid window handle"
        }

        # Get window title for output
        $title = [WindowHelper]::GetWindowTitle($hWnd)

        # Set or remove topmost status
        $current = [WindowHelper]::IsWindowTopMost($hWnd)
        $desired = $Enable.IsPresent

        if ($current -eq $desired) {
            return [PSCustomObject]@{
                Status = 'NoOp'
                WindowHandle = $hWnd
                WindowTitle = $title
                IsTopMost = $current
                PreviousState = $current
                Action = if ($desired) { 'Enable' } else { 'Disable' }
                Message = 'State already as requested'
            }
        }

        if (-not $PSCmdlet.ShouldProcess($title, (if ($desired) { 'Enable AlwaysOnTop' } else { 'Disable AlwaysOnTop' }))) { return }

        $success = [WindowHelper]::SetTopMost($hWnd, $desired)

        if (-not $success) {
            $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
            throw "Failed to set window topmost status (Win32: $err)"
        }

        # Verify the change
        $isTopMost = [WindowHelper]::IsWindowTopMost($hWnd)

        # Return result object
        [PSCustomObject]@{
            Status = if ($success) { 'Success' } else { 'Failed' }
            WindowHandle = $hWnd
            WindowTitle = $title
            IsTopMost = $isTopMost
            PreviousState = $current
            Action = if ($desired) { 'Enabled' } else { 'Disabled' }
        }

    } catch {
        Write-Error "Failed to set window always on top: $_"
        [PSCustomObject]@{
            Status = 'Error'
            WindowHandle = $hWnd
            WindowTitle = $title
            IsTopMost = $false
            Error = $_.Exception.Message
        }
    }
}

function Switch-WindowAlwaysOnTop {
    <#
    .SYNOPSIS
        Toggles the always on top status of a window

    .DESCRIPTION
        Checks if a window is currently always on top, then toggles that status

    .PARAMETER WindowHandle
        The handle (HWND) of the window to toggle

    .PARAMETER ProcessId
        The process ID of the window to toggle

    .PARAMETER WindowTitle
        The title of the window to toggle

    .EXAMPLE
        Toggle-WindowAlwaysOnTop
        Toggles the current foreground window

    .EXAMPLE
        Toggle-WindowAlwaysOnTop -WindowTitle "File Manager"
        Toggles the file manager window

    .OUTPUTS
        [PSCustomObject] with Status, WindowHandle, WindowTitle, IsTopMost properties
    #>
    [CmdletBinding(DefaultParameterSetName='Current')]
    param(
        [Parameter(ParameterSetName='Handle', Mandatory=$true)]
        [IntPtr]$WindowHandle,

        [Parameter(ParameterSetName='ProcessId')]
        [int]$ProcessId,

        [Parameter(ParameterSetName='Title')]
        [string]$WindowTitle,
        [Parameter()]
        [ValidateSet('Like','Exact')]
        [string]$TitleMatch = 'Like'
    )

    try {
        # Determine which window to target
        $hWnd = $null

        switch ($PSCmdlet.ParameterSetName) {
            'Handle' {
                $hWnd = $WindowHandle
            }
            'ProcessId' {
                $process = Get-Process -Id $ProcessId -ErrorAction Stop
                $hWnd = $process.MainWindowHandle
                if ($hWnd -eq [IntPtr]::Zero) {
                    throw "Process $ProcessId does not have a main window"
                }
            }
            'Title' {
                $processes = if ($TitleMatch -eq 'Exact') { Get-Process | Where-Object { $_.MainWindowTitle -eq $WindowTitle } } else { Get-Process | Where-Object { $_.MainWindowTitle -like "*$WindowTitle*" } }
                if ($processes.Count -eq 0) {
                    throw "No window found with title matching '$WindowTitle'"
                }
                if ($processes.Count -gt 1) {
                    Write-Warning "Multiple windows found matching '$WindowTitle'. Using first match."
                }
                $hWnd = $processes[0].MainWindowHandle
            }
            'Current' {
                $hWnd = [WindowHelper]::GetForegroundWindow()
            }
        }

        # Validate window handle
        if ($hWnd -eq [IntPtr]::Zero -or -not [WindowHelper]::IsWindow($hWnd)) {
            throw "Invalid window handle"
        }

        # Check current status
        $isCurrentlyTopMost = [WindowHelper]::IsWindowTopMost($hWnd)

        # Toggle by calling Set-WindowAlwaysOnTop with opposite state
        $params = @{
            WindowHandle = $hWnd
            Enable = -not $isCurrentlyTopMost
        }

        Set-WindowAlwaysOnTop @params

    } catch {
        Write-Error "Failed to toggle window always on top: $_"
    }
}

function Get-WindowTopMostStatus {
    <#
    .SYNOPSIS
        Checks if a window is currently always on top

    .DESCRIPTION
        Queries the WS_EX_TOPMOST extended window style

    .PARAMETER WindowHandle
        The handle (HWND) of the window to check

    .PARAMETER ProcessId
        The process ID of the window to check

    .PARAMETER WindowTitle
        The title of the window to check

    .EXAMPLE
        Get-WindowTopMostStatus
        Checks the current foreground window

    .EXAMPLE
        Get-WindowTopMostStatus -WindowTitle "PowerShell"
        Checks if the PowerShell window is pinned on top

    .OUTPUTS
        [PSCustomObject] with WindowHandle, WindowTitle, IsTopMost, ProcessId properties
    #>
    [CmdletBinding(DefaultParameterSetName='Current')]
    param(
        [Parameter(ParameterSetName='Handle', Mandatory=$true)]
        [IntPtr]$WindowHandle,

        [Parameter(ParameterSetName='ProcessId')]
        [int]$ProcessId,

        [Parameter(ParameterSetName='Title')]
        [string]$WindowTitle,
        [Parameter()]
        [ValidateSet('Like','Exact')]
        [string]$TitleMatch = 'Like'
    )

    try {
        # Determine which window to target
        $hWnd = $null
        $procId = 0

        switch ($PSCmdlet.ParameterSetName) {
            'Handle' {
                $hWnd = $WindowHandle
                [WindowHelper]::GetWindowThreadProcessId($hWnd, [ref]$procId) | Out-Null
            }
            'ProcessId' {
                $process = Get-Process -Id $ProcessId -ErrorAction Stop
                $hWnd = $process.MainWindowHandle
                $procId = $ProcessId
                if ($hWnd -eq [IntPtr]::Zero) {
                    throw "Process $ProcessId does not have a main window"
                }
            }
            'Title' {
                $processes = if ($TitleMatch -eq 'Exact') { Get-Process | Where-Object { $_.MainWindowTitle -eq $WindowTitle } } else { Get-Process | Where-Object { $_.MainWindowTitle -like "*$WindowTitle*" } }
                if ($processes.Count -eq 0) {
                    throw "No window found with title matching '$WindowTitle'"
                }
                if ($processes.Count -gt 1) {
                    Write-Warning "Multiple windows found matching '$WindowTitle'. Using first match."
                }
                $hWnd = $processes[0].MainWindowHandle
                $procId = $processes[0].Id
            }
            'Current' {
                $hWnd = [WindowHelper]::GetForegroundWindow()
                [WindowHelper]::GetWindowThreadProcessId($hWnd, [ref]$procId) | Out-Null
            }
        }

        # Validate window handle
        if ($hWnd -eq [IntPtr]::Zero -or -not [WindowHelper]::IsWindow($hWnd)) {
            throw "Invalid window handle"
        }

        # Get window info
        $title = [WindowHelper]::GetWindowTitle($hWnd)
        $isTopMost = [WindowHelper]::IsWindowTopMost($hWnd)

        # Return result object
        [PSCustomObject]@{
            WindowHandle = $hWnd
            WindowTitle = $title
            IsTopMost = $isTopMost
            ProcessId = $procId
            Status = if ($isTopMost) { 'Pinned On Top' } else { 'Normal' }
        }

    } catch {
        Write-Error "Failed to get window status: $_"
    }
}

function Show-WindowPinIndicator {
    <#
    .SYNOPSIS
        Shows a visual notification when a window is pinned/unpinned

    .DESCRIPTION
        Displays a brief notification message indicating the pin status change

    .PARAMETER WindowTitle
        The title of the window that was pinned/unpinned

    .PARAMETER IsPinned
        Whether the window is now pinned (true) or unpinned (false)

    .EXAMPLE
        Show-WindowPinIndicator -WindowTitle "File Manager" -IsPinned $true
        Shows notification that window is now pinned
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$WindowTitle,

        [Parameter(Mandatory=$true)]
        [bool]$IsPinned
    )

    $icon = if ($IsPinned) { "📌" } else { "📍" }
    $status = if ($IsPinned) { "PINNED ON TOP" } else { "UNPINNED" }
    $color = if ($IsPinned) { "Cyan" } else { "Yellow" }

    Write-Host ""
    Write-Host "$icon ═══════════════════════════════════════════════════" -ForegroundColor $color
    Write-Host "$icon  WINDOW $status" -ForegroundColor $color
    Write-Host "$icon  Window: $WindowTitle" -ForegroundColor $color
    Write-Host "$icon ═══════════════════════════════════════════════════" -ForegroundColor $color
    Write-Host ""
}


# Export module members
Export-ModuleMember -Function Set-WindowAlwaysOnTop, Switch-WindowAlwaysOnTop, `
    Get-WindowTopMostStatus, Show-WindowPinIndicator
