#Requires -Version 7.0

# PowerShell File Manager V2.0 - Root Module
# Command-centric file manager with rich PowerShell integration

# Import required assemblies (only on Windows)
if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
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
    Version = '2.0.0'
    Theme = 'Dark'
    Language = 'en-US'
    MaxHistoryItems = 100
    DefaultRunspaces = 3
    EnableTelemetry = $false
    PluginDirectory = Join-Path $PSScriptRoot "Plugins"
    ConfigDirectory = if ($IsWindows -or $PSVersionTable.PSVersion.Major -lt 6) {
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

# Import all module files
$modulePath = Join-Path $PSScriptRoot "src/Modules"
if (Test-Path $modulePath) {
    Get-ChildItem -Path $modulePath -Filter "*.psm1" -Recurse | ForEach-Object {
        try {
            Import-Module $_.FullName -Global -ErrorAction Stop
        } catch {
            Write-Warning "Failed to load module: $($_.Name) - $_"
        }
    }
}

# Dot-source the main application script
$scriptPath = Join-Path $PSScriptRoot "src/Scripts/Start-FileManager.ps1"
if (Test-Path $scriptPath) {
    try {
        . $scriptPath
    } catch {
        # GUI components may not be available on all platforms
        if ($_.Exception.Message -notlike "*PresentationFramework*") {
            Write-Warning "Failed to load Start-FileManager script: $_"
        }
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
    if (Test-Path -LiteralPath $SamplePath -PathType Leaf -ErrorAction SilentlyContinue) {
        $locked = $false
        if (Get-Command Test-FileLocked -ErrorAction SilentlyContinue) { $locked = Test-FileLocked -Path $SamplePath }
        $results += [pscustomobject]@{ Component='FileLocksmith'; Name='Test-FileLocked'; Available=$true; Detail=("Locked={0}" -f $locked) }
    }
    return $results
}

# Export module members
Export-ModuleMember -Function @(
    'Start-FileManager'
    'Invoke-CommandPalette'
    'New-QueryBuilder'
    'Show-ObjectInspector'
    'Start-BatchOperation'
    'Find-DuplicateFiles'
    'Get-FolderSize'
    'Search-Files'
    'Invoke-FileComparison'
    'Get-FileChecksum'
    'New-Symlink'
    'Sync-Directories'
    'Get-NavigationHistory'
    'Get-DiskSpace'
    'Connect-FTP'
    'Connect-SFTP'
    'Get-GitStatus'
    'Show-FilePreview'
    'Edit-FileMetadata'
    'Get-FileACL'
    'Set-FileACL'
    'Remove-SecureFile'
    'Get-PluginList'
    'Install-Plugin'
    # PowerToys integrations
    'Set-WindowAlwaysOnTop'
    'Switch-WindowAlwaysOnTop'
    'Get-WindowTopMostStatus'
    'Show-WindowPinIndicator'
    'Get-FileLock'
    'Unlock-File'
    'Show-FileLockInfo'
    'Test-FileLocked'
    'Test-PowerToysIntegrations'
    # PowerToys - Image Resizer
    'Resize-Image'
    'Get-ImageInfo'
    # PowerToys - Text Extractor
    'Get-TextFromImage'
    'Start-ScreenTextExtractor'
    # PowerToys - Color Picker
    'Get-ColorFromScreen'
    'Convert-ColorFormat'
    # PowerToys - Hosts File Editor
    'Get-HostsEntry'
    'Add-HostsEntry'
    'Remove-HostsEntry'
    'Backup-HostsFile'
    # PowerToys - Quick Accent
    'Get-AccentedCharacter'
    'Get-SpecialSymbol'
    'Show-QuickAccentMenu'
    # PowerToys - Shortcut Guide
    'Get-KeyboardShortcut'
    'Show-ShortcutGuide'
    'Find-Shortcut'
    # PowerToys - Workspace Layouts
    'Get-WorkspaceLayout'
    'Set-WindowLayout'
    'Save-WorkspaceSnapshot'
    'Show-WorkspaceLayoutMenu'
    # PowerToys - Template Manager
    'Get-FileTemplate'
    'New-FileFromTemplate'
    'Show-TemplateMenu'
    # PowerToys - Awake Mode
    'Enable-AwakeMode'
    'Disable-AwakeMode'
    'Get-AwakeStatus'
    'Invoke-WithAwakeMode'
    # PowerToys - PowerRename
    'Invoke-PowerRename'
    'New-RenamePattern'
) -Variable FileManagerConfig

# Simple self-test for PowerToys integrations
function Test-PowerToysIntegrations {
    [CmdletBinding()]
    param(
        [string]$SamplePath = $PSCommandPath
    )
    $results = @()
    try {
        $cmds = @(
            'Get-FileLock','Unlock-File','Show-FileLockInfo','Test-FileLocked',
            'Set-WindowAlwaysOnTop','Switch-WindowAlwaysOnTop','Get-WindowTopMostStatus','Show-WindowPinIndicator'
        )
        foreach ($c in $cmds) {
            $exists = [bool](Get-Command -Name $c -ErrorAction SilentlyContinue)
            $results += [pscustomobject]@{ Component='Command'; Name=$c; Available=$exists }
        }

        # Functional smoke checks
        $pathExists = Test-Path -LiteralPath $SamplePath -PathType Leaf
        $locked = $false
        if ($pathExists -and (Get-Command Test-FileLocked -ErrorAction SilentlyContinue)) {
            $locked = Test-FileLocked -Path $SamplePath
        }
        $results += [pscustomobject]@{ Component='FileLocksmith'; Name='Test-FileLocked'; Available=$true; Detail=("Locked={0}" -f $locked) }

        return $results
    } catch {
        Write-Error $_
    }
}

Export-ModuleMember -Function Test-PowerToysIntegrations -Variable FileManagerConfig
