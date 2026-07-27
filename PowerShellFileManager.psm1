#Requires -Version 7.0

# PowerShell File Manager V2.0 - Root Module
# Command-centric file manager with rich PowerShell integration

# Import required assemblies (only on Windows)
if ($IsWindows) {
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
        Add-Type -AssemblyName PresentationCore -ErrorAction SilentlyContinue
        Add-Type -AssemblyName WindowsBase -ErrorAction SilentlyContinue
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Some GUI assemblies could not be loaded. GUI features may be limited."
    }
}

# Module-level variables
$script:FileManagerConfig = @{
    Version = '2.1.0'
    Theme = 'Dark'
    Language = 'en-US'
    MaxHistoryItems = 100
    DefaultRunspaces = 3
    EnableTelemetry = $false
    PluginDirectory = Join-Path $PSScriptRoot "Plugins"
    ConfigDirectory = if ($IsWindows) {
        Join-Path $env:APPDATA "PowerShellFileManager"
    } else {
        Join-Path $HOME ".config/PowerShellFileManager"
    }
}

# Initialize configuration directory
if (-not (Test-Path $script:FileManagerConfig.ConfigDirectory)) {
    try {
        New-Item -Path $script:FileManagerConfig.ConfigDirectory -ItemType Directory -Force | Out-Null
    } catch {
        Write-Warning "Could not create configuration directory: $_"
    }
}

# Dot-source every feature file into this module's scope. Keeping all functions
# in one session state lets features call each other without polluting the
# caller's session, makes each file's Export-ModuleMember apply to this module,
# and lets Remove-Module unload everything. The manifest's FunctionsToExport is
# the final public API filter.
$modulePath = Join-Path $PSScriptRoot "src/Modules"
if (Test-Path $modulePath) {
    foreach ($featureFile in Get-ChildItem -Path $modulePath -Filter "*.ps1" -Recurse | Sort-Object FullName) {
        try {
            . $featureFile.FullName
        } catch {
            Write-Warning "Failed to load feature file: $($featureFile.Name) - $_"
        }
    }
}

# Dot-source the main application script (defines Start-FileManager; needs WPF)
$scriptPath = Join-Path $PSScriptRoot "src/Scripts/Start-FileManager.ps1"
if (Test-Path $scriptPath) {
    try {
        . $scriptPath
    } catch {
        Write-Warning "Failed to load Start-FileManager script: $_"
    }
}

# Simple self-test for PowerToys integrations
function Test-PowerToysIntegrations {
    [CmdletBinding()]
    param(
        [string]$SamplePath = $PSCommandPath
    )
    $results = @()
    $cmds = @(
        'Get-FileLock','Unlock-File','Show-FileLockInfo','Test-FileLocked',
        'Set-WindowAlwaysOnTop','Switch-WindowAlwaysOnTop','Get-WindowTopMostStatus','Show-WindowPinIndicator'
    )
    foreach ($c in $cmds) {
        $exists = [bool](Get-Command -Name $c -ErrorAction SilentlyContinue)
        $results += [pscustomobject]@{ Component='Command'; Name=$c; Available=$exists }
    }
    if (Test-Path -LiteralPath $SamplePath -PathType Leaf) {
        $locked = $false
        if (Get-Command Test-FileLocked -ErrorAction SilentlyContinue) { $locked = Test-FileLocked -Path $SamplePath }
        $results += [pscustomobject]@{ Component='FileLocksmith'; Name='Test-FileLocked'; Available=$true; Detail=("Locked={0}" -f $locked) }
    }
    return $results
}

Export-ModuleMember -Function Test-PowerToysIntegrations
