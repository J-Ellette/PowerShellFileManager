@{
    RootModule = 'PowerShellFileManager.psm1'
    ModuleVersion = '2.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author = 'Heathen-Volholl'
    CompanyName = 'Community'
    Copyright = '(c) 2025 Heathen-Volholl. All rights reserved. MIT License.'
    Description = 'Advanced PowerShell 7 File Manager with command-centric design, rich metadata display, and extensive PowerShell integration'
    PowerShellVersion = '7.0'
    
    # Functions to export
    FunctionsToExport = @(
        'Start-FileManager'
        'Invoke-CommandPalette'
        'New-QueryBuilder'
        'New-ScriptWorkspace'
        'Show-ObjectInspector'
        'Start-RunspaceManager'
        'Start-BatchOperation'
        'Find-DuplicateFiles'
        'Get-FolderSize'
        'Search-Files'
        'Invoke-FileComparison'
        'Get-FileChecksum'
        'New-Symlink'
        'Sync-Directories'
        'Rename-FileBatch'
        'New-Archive'
        'Expand-Archive'
        'Get-ArchiveContent'
        'Add-NavigationHistory'
        'Get-NavigationHistory'
        'Invoke-NavigationBack'
        'Invoke-NavigationForward'
        'Invoke-QuickFilter'
        'Save-SearchQuery'
        'Get-SavedSearches'
        'Get-DiskSpace'
        'Get-GitStatus'
        'Invoke-GitDiff'
        'Get-CloudSyncStatus'
        'Connect-FTP'
        'Connect-SFTP'
        'Show-FilePreview'
        'Get-FileMetadata'
        'Edit-FileMetadata'
        'Get-FileACL'
        'Set-FileACL'
        'Remove-SecureFile'
        'Start-BackgroundCopy'
        'Get-BackgroundOperations'
        'Stop-BackgroundOperation'
        'Get-PluginList'
        'Install-Plugin'
        'Uninstall-Plugin'
        # Task Manager functions
        'Get-TaskInfo'
        'Stop-TaskProcess'
        'Get-TaskPerformance'
        'Start-TaskMonitor'
        'Get-TaskRelationship'
    )
    
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    
    PrivateData = @{
        PSData = @{
            Tags = @('FileManager', 'PowerShell', 'GUI', 'FileOperations', 'Metadata', 'Search')
            LicenseUri = 'https://github.com/Heathen-Volholl/PowerShellFileManagerV2.0/blob/main/LICENSE'
            ProjectUri = 'https://github.com/Heathen-Volholl/PowerShellFileManagerV2.0'
            RequireLicenseAcceptance = $false
        }
    }
}
