#Requires -Version 7.0

<#
.SYNOPSIS
    File Locksmith - Detect and unlock files held by processes
.DESCRIPTION
    Uses Windows Restart Manager to identify processes that lock a file.
    Returns structured objects. Console chatter uses Write-Verbose/Information.
.NOTES
    - Admin is required for forced unlock operations
    - ASCII-only messages
#>

# Load PresentationFramework for MessageBox (Windows only)
if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
    if (-not ([System.Management.Automation.PSTypeName]'System.Windows.MessageBox').Type) {
        try {
            Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        } catch {
            Write-Verbose "PresentationFramework not available: $($_.Exception.Message)"
        }
    }
}

# Interop: Restart Manager
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class RmNative {
    [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
    public static extern int RmStartSession(out uint pSessionHandle, int dwSessionFlags, string strSessionKey);

    [DllImport("rstrtmgr.dll")] public static extern int RmEndSession(uint pSessionHandle);

    [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
    public static extern int RmRegisterResources(uint pSessionHandle, uint nFiles, string[] rgsFilenames,
        uint nApplications, IntPtr rgApplications, uint nServices, string[] rgsServiceNames);

    [DllImport("rstrtmgr.dll")]
    public static extern int RmGetList(uint dwSessionHandle, out uint pnProcInfoNeeded, ref uint pnProcInfo,
        [In, Out] RM_PROCESS_INFO[] rgAffectedApps, ref uint lpdwRebootReasons);

    [StructLayout(LayoutKind.Sequential)]
    public struct RM_UNIQUE_PROCESS {
        public int dwProcessId;
        public System.Runtime.InteropServices.ComTypes.FILETIME ProcessStartTime;
    }

    public enum RM_APP_TYPE {
        RmUnknownApp = 0,
        RmMainWindow = 1,
        RmOtherWindow = 2,
        RmService = 3,
        RmExplorer = 4,
        RmConsole = 5,
        RmCritical = 1000
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct RM_PROCESS_INFO {
        public RM_UNIQUE_PROCESS Process;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string strAppName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)] public string strServiceShortName;
        public RM_APP_TYPE ApplicationType;
        public uint AppStatus;
        public uint TSSessionId;
        [MarshalAs(UnmanagedType.Bool)] public bool bRestartable;
    }
}
"@ -ErrorAction SilentlyContinue

# Define FileLocksmith class with nested structs for test compatibility
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class FileLocksmith {
    [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
    public static extern int RmStartSession(out uint pSessionHandle, int dwSessionFlags, string strSessionKey);

    [DllImport("rstrtmgr.dll")]
    public static extern int RmEndSession(uint pSessionHandle);

    [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
    public static extern int RmRegisterResources(uint pSessionHandle, uint nFiles, string[] rgsFilenames,
        uint nApplications, IntPtr rgApplications, uint nServices, string[] rgsServiceNames);

    [DllImport("rstrtmgr.dll")]
    public static extern int RmGetList(uint dwSessionHandle, out uint pnProcInfoNeeded, ref uint pnProcInfo,
        [In, Out] RM_PROCESS_INFO[] rgAffectedApps, ref uint lpdwRebootReasons);

    [StructLayout(LayoutKind.Sequential)]
    public struct RM_UNIQUE_PROCESS {
        public int dwProcessId;
        public System.Runtime.InteropServices.ComTypes.FILETIME ProcessStartTime;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct RM_PROCESS_INFO {
        public RM_UNIQUE_PROCESS Process;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]
        public string strAppName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
        public string strServiceShortName;
        public uint ApplicationType;
        public uint AppStatus;
        public uint TSSessionId;
        [MarshalAs(UnmanagedType.Bool)]
        public bool bRestartable;
    }
}
"@ -ErrorAction SilentlyContinue

function Get-FileLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position=0)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path,

        [switch]$ShowDetails
    )

    try {
        $fullPath = (Get-Item -LiteralPath $Path).FullName
        Write-Verbose ("Analyzing locks for: {0}" -f $fullPath)

        $session = 0u
        $key = [guid]::NewGuid().ToString()
        $rc = [RmNative]::RmStartSession([ref]$session, 0, $key)
        if ($rc -ne 0) { throw "RmStartSession failed: $rc" }
        try {
            $files = @($fullPath)
            $rc = [RmNative]::RmRegisterResources($session, [uint32]$files.Length, $files, 0, [IntPtr]::Zero, 0, $null)
            if ($rc -ne 0) { throw "RmRegisterResources failed: $rc" }

            $needed = 0u; $count = 0u; $reboot = 0u
            $rc = [RmNative]::RmGetList($session, [ref]$needed, [ref]$count, $null, [ref]$reboot)
            if ($needed -eq 0) { return @() }

            $arr = New-Object RmNative+RM_PROCESS_INFO[] $needed
            $count = $needed
            $rc = [RmNative]::RmGetList($session, [ref]$needed, [ref]$count, $arr, [ref]$reboot)
            if ($rc -ne 0) { throw "RmGetList failed: $rc" }

            $out = @()
            foreach ($info in $arr) {
                $processId = $info.Process.dwProcessId
                $p = Get-Process -Id $processId -ErrorAction SilentlyContinue
                if (-not $p) { continue }
                $procPath = $null; try { $procPath = $p.Path } catch {}
                $start = $null; try { $start = $p.StartTime } catch {}
                $ws = $null; try { $ws = $p.WorkingSet64 } catch {}
                $name = if ([string]::IsNullOrWhiteSpace($info.strAppName)) { $p.ProcessName } else { $info.strAppName }
                $obj = [pscustomobject]@{
                    ProcessId       = $processId
                    ProcessName     = $name
                    ProcessPath     = $procPath
                    ApplicationType = $info.ApplicationType.ToString()
                    ServiceName     = $info.strServiceShortName
                    Restartable     = $info.bRestartable
                    SessionId       = $info.TSSessionId
                    StartTime       = $start
                    WorkingSet      = $ws
                }
                if ($ShowDetails) { $obj }
                $out += $obj
            }
            return $out
        }
        finally {
            if ($session -ne 0) { [RmNative]::RmEndSession($session) | Out-Null }
        }
    }
    catch {
        Write-Error ("Get-FileLock failed: {0}" -f $_)
    }
}

function Unlock-File {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory, Position=0)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path,

        [int]$ProcessId,
        [switch]$Force
    )

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($Force -and -not $isAdmin) { Write-Error "Administrator privileges are required for -Force"; return }

    try {
        $fullPath = (Get-Item -LiteralPath $Path).FullName
        $procs = Get-FileLock -Path $fullPath
        if (-not $procs -or $procs.Count -eq 0) { Write-Information "File is not locked" -InformationAction Continue; return }
        if ($ProcessId) { $procs = $procs | Where-Object { $_.ProcessId -eq $ProcessId } }
        if (-not $procs -or $procs.Count -eq 0) { Write-Error "Specified process is not locking this file"; return }

        foreach ($p in $procs) {
            if (-not $Force) {
                Write-Information ("Process {0} (PID {1}) is locking the file. Use -Force to terminate." -f $p.ProcessName, $p.ProcessId) -InformationAction Continue
                continue
            }
            if ($PSCmdlet.ShouldProcess($p.ProcessName, "Terminate process $($p.ProcessId)")) {
                try {
                    Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
                    Start-Sleep -Milliseconds 500
                } catch { Write-Error ("Failed to terminate PID {0}: {1}" -f $p.ProcessId, $_.Exception.Message) }
            }
        }
    }
    catch { Write-Error ("Unlock-File failed: {0}" -f $_) }
}

function Show-FileLockInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path
    )
    try {
        $fullPath = (Get-Item -LiteralPath $Path).FullName
        $locks = Get-FileLock -Path $fullPath
        if (-not $locks -or $locks.Count -eq 0) {
            [System.Windows.MessageBox]::Show("File is not locked by any process.", "File Locksmith", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
            return
        }
        $lines = ($locks | ForEach-Object { "{0} (PID {1})" -f $_.ProcessName, $_.ProcessId }) -join "`n"
        $msg = "The following processes are locking this file:`n`n$lines"
        [System.Windows.MessageBox]::Show($msg, "File Locksmith - $fullPath", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show(("Error: {0}" -f $_.Exception.Message), "File Locksmith Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
    }
}

function Test-FileLocked {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path
    )
    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $stream.Dispose()
        return $false
    } catch { return $true }
}

Export-ModuleMember -Function Get-FileLock, Unlock-File, Show-FileLockInfo, Test-FileLocked

