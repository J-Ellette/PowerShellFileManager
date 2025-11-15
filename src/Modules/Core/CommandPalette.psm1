#Requires -Version 7.0

# Command Palette Module - Primary Interface for File Manager
# Supports natural language and PowerShell syntax with autocomplete

<#
.SYNOPSIS
    Command Palette for PowerShell File Manager
.DESCRIPTION
    Provides a command-centric interface with fuzzy search, autocomplete,
    and support for both natural language queries and PowerShell syntax.
#>

# Command history and cache
$script:CommandHistory = [System.Collections.ArrayList]::new()
$script:CommandCache = @{}
$script:NaturalLanguagePatterns = @{
    'find large pdf files from last month' = { Get-ChildItem -Path $pwd -Recurse -Filter "*.pdf" | Where-Object { $_.Length -gt 10MB -and $_.LastWriteTime -gt (Get-Date).AddMonths(-1) } }
    'show images modified today' = { Get-ChildItem -Path $pwd -Recurse -Include "*.jpg","*.png","*.gif" | Where-Object { $_.LastWriteTime.Date -eq (Get-Date).Date } }
    'find duplicate files' = { Find-DuplicateFiles -Path $pwd }
    'large files' = { Get-ChildItem -Path $pwd -Recurse | Where-Object { $_.Length -gt 100MB } | Sort-Object Length -Descending }
    'recent files' = { Get-ChildItem -Path $pwd -Recurse | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) } | Sort-Object LastWriteTime -Descending }
    'empty folders' = { Get-ChildItem -Path $pwd -Recurse -Directory | Where-Object { (Get-ChildItem $_.FullName).Count -eq 0 } }
    
    # Enhanced Background Operations
    'copy with robocopy' = { 
        $source = Read-Host "Source path"
        $destination = Read-Host "Destination path"
        Start-EnhancedBackgroundCopy -Source $source -Destination $destination -UseRobocopy
    }
    'enhanced copy' = { 
        $source = Read-Host "Source path"
        $destination = Read-Host "Destination path"
        Start-EnhancedBackgroundCopy -Source $source -Destination $destination
    }
    'fast copy' = { 
        $source = Read-Host "Source path"
        $destination = Read-Host "Destination path"
        Start-EnhancedBackgroundCopy -Source $source -Destination $destination -UseRobocopy -BufferSize 2MB
    }
    'background operations' = { Get-EnhancedOperationStatus -IncludeCompleted }
    'active operations' = { Get-EnhancedOperationStatus }
    'operation status' = { 
        $id = Read-Host "Operation ID (or press Enter for all)"
        if ($id) { Get-EnhancedOperationStatus -OperationId $id } else { Get-EnhancedOperationStatus }
    }
    'stop operation' = { 
        $id = Read-Host "Operation ID to stop"
        if ($id) { Stop-EnhancedOperation -OperationId $id }
    }
    'cleanup operations' = { Clear-CompletedEnhancedOperations }
    'initialize runspace pool' = { Initialize-RunspacePool }
    
    # Caching & Indexing Operations
    'build file index' = { 
        $path = Read-Host "Path to index (Enter for current directory)"
        if (-not $path) { $path = $PWD.Path }
        Update-FileIndex -Path $path
    }
    'build index with hashes' = { 
        $path = Read-Host "Path to index (Enter for current directory)"
        if (-not $path) { $path = $PWD.Path }
        Update-FileIndex -Path $path -IncludeHash
    }
    'search indexed files' = { 
        $pattern = Read-Host "Search pattern (Enter for all)"
        if ($pattern) { Search-IndexedFiles -Pattern $pattern } else { Search-IndexedFiles }
    }
    'search by extension' = { 
        $ext = Read-Host "File extension (e.g., .txt, .pdf)"
        if ($ext) { Search-IndexedFiles -Extension $ext }
    }
    'search large files' = { 
        $size = Read-Host "Minimum size in MB (default: 100)"
        $sizeBytes = if ($size) { [long]$size * 1MB } else { 100MB }
        Search-IndexedFiles -SizeMin $sizeBytes
    }
    'search recent files' = { 
        $days = Read-Host "Files modified within X days (default: 7)"
        $daysInt = if ($days) { [int]$days } else { 7 }
        $date = (Get-Date).AddDays(-$daysInt)
        Search-IndexedFiles -ModifiedAfter $date
    }
    'index statistics' = { Get-FileIndexStatistics }
    'clear file cache' = { Clear-FileCache }
    'optimize cache' = { Optimize-FileCache }
    'sync directories' = { 
        $source = Read-Host "Source directory"
        $dest = Read-Host "Destination directory"
        if ($source -and $dest) { 
            Sync-Directories -Source $source -Destination $dest -WhatIf
        }
    }
    
    # Advanced Search Capabilities
    'fuzzy search' = { 
        $query = Read-Host "Search query"
        $threshold = Read-Host "Fuzzy threshold (0.1-1.0, default: 0.7)"
        $thresholdValue = if ($threshold) { [double]$threshold } else { 0.7 }
        if ($query) { Search-FilesFuzzy -Query $query -FuzzyThreshold $thresholdValue -UseIndex }
    }
    'fuzzy search files' = { 
        $query = Read-Host "Search query"
        if ($query) { Search-FilesFuzzy -Query $query -FuzzyThreshold 0.7 -UseIndex }
    }
    'smart search' = { 
        $query = Read-Host "Search query (try partial names)"
        if ($query) { Search-FilesFuzzy -Query $query -FuzzyThreshold 0.6 -UseIndex }
    }
    'search suggestions' = { 
        $partial = Read-Host "Partial query (or Enter for all suggestions)"
        Get-SearchSuggestions -PartialQuery $partial
    }
    'search history' = { Get-SearchHistory }
    'clear search history' = { 
        $confirm = Read-Host "Clear all search history? (y/N)"
        if ($confirm -eq 'y' -or $confirm -eq 'Y') { Clear-SearchHistory }
    }
    'similar files' = { 
        $name = Read-Host "File name to find similar files for"
        if ($name) { Search-FilesFuzzy -Query $name -FuzzyThreshold 0.8 -UseIndex }
    }
    'typo search' = {
        $query = Read-Host "Search query (handles typos)"
        if ($query) { Search-FilesFuzzy -Query $query -FuzzyThreshold 0.5 -UseIndex -MaxResults 20 }
    }

    # Enhanced Preview System
    'preview file' = {
        $path = Read-Host "File path to preview"
        if ($path -and (Test-Path $path)) { Show-EnhancedPreview -Path $path }
    }
    'enhanced preview' = {
        $path = Read-Host "File path to preview"
        if ($path -and (Test-Path $path)) { Show-EnhancedPreview -Path $path }
    }
    'preview word document' = {
        $path = Read-Host "Path to .docx file"
        if ($path -and (Test-Path $path)) { Show-WordDocumentPreview -Path $path }
    }
    'preview excel' = {
        $path = Read-Host "Path to .xlsx file"
        if ($path -and (Test-Path $path)) { Show-ExcelPreview -Path $path }
    }
    'preview spreadsheet' = {
        $path = Read-Host "Path to .xlsx file"
        if ($path -and (Test-Path $path)) { Show-ExcelPreview -Path $path }
    }
    'preview pdf' = {
        $path = Read-Host "Path to PDF file"
        if ($path -and (Test-Path $path)) { Show-PDFPreview -Path $path }
    }
    'preview video' = {
        $path = Read-Host "Path to video file"
        if ($path -and (Test-Path $path)) { Show-VideoPreview -Path $path }
    }
    'preview audio' = {
        $path = Read-Host "Path to audio file"
        if ($path -and (Test-Path $path)) { Show-AudioPreview -Path $path }
    }
    'preview music' = {
        $path = Read-Host "Path to audio file"
        if ($path -and (Test-Path $path)) { Show-AudioPreview -Path $path }
    }
    'show document' = {
        $path = Read-Host "Document path"
        if ($path -and (Test-Path $path)) { Show-EnhancedPreview -Path $path }
    }
    'quick preview' = {
        $path = Read-Host "File path"
        if ($path -and (Test-Path $path)) { Show-EnhancedPreview -Path $path }
    }

    # Extended Preview Support (Item 43)
    'preview svg' = {
        $path = Read-Host "Path to SVG file"
        if ($path -and (Test-Path $path)) { Show-SVGPreview -Path $path }
    }
    'preview markdown' = {
        $path = Read-Host "Path to Markdown file"
        if ($path -and (Test-Path $path)) { Show-MarkdownPreview -Path $path }
    }
    'preview 3d model' = {
        $path = Read-Host "Path to STL file"
        if ($path -and (Test-Path $path)) { Show-STLPreview -Path $path }
    }
    'preview stl' = {
        $path = Read-Host "Path to STL file"
        if ($path -and (Test-Path $path)) { Show-STLPreview -Path $path }
    }
    'preview gcode' = {
        $path = Read-Host "Path to G-code file"
        if ($path -and (Test-Path $path)) { Show-GCodePreview -Path $path }
    }
    'preview 3d print' = {
        $path = Read-Host "Path to G-code file"
        if ($path -and (Test-Path $path)) { Show-GCodePreview -Path $path }
    }

    # File Locksmith - PowerToys Integration
    "what's using this file" = {
        $path = Read-Host "File path to check"
        if ($path -and (Test-Path $path)) { Get-FileLock -Path $path -ShowDetails }
    }
    'unlock file' = {
        $path = Read-Host "File path to unlock"
        if ($path -and (Test-Path $path)) {
            $processes = Get-FileLock -Path $path
            if ($processes) {
                $force = Read-Host "Force termination? (y/N)"
                if ($force -eq 'y' -or $force -eq 'Y') {
                    Unlock-File -Path $path -Force
                } else {
                    Unlock-File -Path $path
                }
            }
        }
    }
    'show file locks' = {
        $path = Read-Host "File path"
        if ($path -and (Test-Path $path)) { Get-FileLock -Path $path -ShowDetails }
    }
    'file in use' = {
        $path = Read-Host "File path"
        if ($path -and (Test-Path $path)) { Get-FileLock -Path $path -ShowDetails }
    }
    "can't delete" = {
        $path = Read-Host "File path that won't delete"
        if ($path -and (Test-Path $path)) {
            Get-FileLock -Path $path -ShowDetails
            Write-Host "`nTo unlock, use: Unlock-File -Path `"$path`" -Force" -ForegroundColor Yellow
        }
    }
    'check file lock' = {
        $path = Read-Host "File path"
        if ($path -and (Test-Path $path)) {
            $isLocked = Test-FileLocked -Path $path
            if ($isLocked) {
                Write-Host "File is LOCKED" -ForegroundColor Red
                Get-FileLock -Path $path -ShowDetails
            } else {
                Write-Host "File is NOT locked" -ForegroundColor Green
            }
        }
    }

    # Always On Top - PowerToys Integration (Item 46)
    'pin window' = {
        $result = Toggle-WindowAlwaysOnTop
        if ($result) {
            Show-WindowPinIndicator -WindowTitle $result.WindowTitle -IsPinned $result.IsTopMost
        }
    }
    'always on top' = {
        $result = Toggle-WindowAlwaysOnTop
        if ($result) {
            Show-WindowPinIndicator -WindowTitle $result.WindowTitle -IsPinned $result.IsTopMost
        }
    }
    'pin on top' = {
        $result = Set-WindowAlwaysOnTop -Enable
        if ($result) {
            Show-WindowPinIndicator -WindowTitle $result.WindowTitle -IsPinned $result.IsTopMost
        }
    }
    'unpin window' = {
        $result = Set-WindowAlwaysOnTop
        if ($result) {
            Show-WindowPinIndicator -WindowTitle $result.WindowTitle -IsPinned $result.IsTopMost
        }
    }
    'window status' = {
        $status = Get-WindowTopMostStatus
        if ($status) {
            Write-Host "`n═══════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "Window Status" -ForegroundColor Cyan
            Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "Title:      $($status.WindowTitle)" -ForegroundColor White
            Write-Host "Process ID: $($status.ProcessId)" -ForegroundColor White
            Write-Host "Status:     $($status.Status)" -ForegroundColor $(if ($status.IsTopMost) { 'Green' } else { 'Yellow' })
            Write-Host "═══════════════════════════════════════`n" -ForegroundColor Cyan
        }
    }
}

function Invoke-CommandPalette {
    <#
    .SYNOPSIS
        Launches the command palette interface
    .DESCRIPTION
        Opens an interactive command palette that accepts natural language
        queries and PowerShell commands with autocomplete support
    .PARAMETER InitialQuery
        Optional initial query to populate the command palette
    .EXAMPLE
        Invoke-CommandPalette
        Opens the command palette
    .EXAMPLE
        Invoke-CommandPalette -InitialQuery "find large files"
        Opens with pre-populated query
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$InitialQuery = ""
    )
    
    # Create the command palette window
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Command Palette - PowerShell File Manager"
        Height="600" Width="800"
        WindowStartupLocation="CenterScreen"
        Background="#1E1E1E">
    <Window.Resources>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="#CCCCCC"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="CaretBrush" Value="#CCCCCC"/>
        </Style>
        <Style TargetType="RadioButton">
            <Setter Property="Foreground" Value="#CCCCCC"/>
        </Style>
        <Style TargetType="ListBox">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
        </Style>
        <Style TargetType="ListBoxItem">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Style.Triggers>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#007ACC"/>
                    <Setter Property="Foreground" Value="White"/>
                </Trigger>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#3E3E42"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Search Box -->
        <Border Grid.Row="0" Background="#2D2D30" CornerRadius="4" Padding="10" Margin="0,0,0,10">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="Search" FontSize="20" Margin="0,0,10,0"/>
                <TextBox Grid.Column="1" Name="SearchBox" FontSize="16" Background="Transparent" BorderThickness="0"/>
            </Grid>
        </Border>

        <!-- Mode Selector -->
        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,10">
            <RadioButton Name="NaturalLanguageMode" Content="Natural Language" IsChecked="True" Margin="0,0,20,0"/>
            <RadioButton Name="PowerShellMode" Content="PowerShell Syntax"/>
        </StackPanel>

        <!-- Results List -->
        <Border Grid.Row="2" Background="#252526" CornerRadius="4">
            <ListBox Name="ResultsList" Background="Transparent" BorderThickness="0" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                <ListBox.ItemTemplate>
                    <DataTemplate>
                        <StackPanel Margin="5">
                            <TextBlock Text="{Binding Name}" FontWeight="Bold" FontSize="14"/>
                            <TextBlock Text="{Binding Description}" FontSize="12" Foreground="#999999"/>
                        </StackPanel>
                    </DataTemplate>
                </ListBox.ItemTemplate>
            </ListBox>
        </Border>
        
        <!-- Status Bar -->
        <Border Grid.Row="3" Background="#007ACC" CornerRadius="4" Padding="5" Margin="0,10,0,0">
            <TextBlock Name="StatusText" Text="Type to search commands and files..." 
                       Foreground="White" FontSize="12"/>
        </Border>
    </Grid>
</Window>
"@
    
    try {
        $window = [Windows.Markup.XamlReader]::Parse($xaml)
        $searchBox = $window.FindName("SearchBox")
        $searchBox.Text = $InitialQuery
        $resultsList = $window.FindName("ResultsList")
        $statusText = $window.FindName("StatusText")
        $naturalMode = $window.FindName("NaturalLanguageMode")
        
        # Populate with available commands
        $commands = Get-AvailableCommands
        $resultsList.ItemsSource = $commands
        
        # Search box text changed handler
        $searchBox.Add_TextChanged({
            $query = $searchBox.Text
            if ([string]::IsNullOrWhiteSpace($query)) {
                $resultsList.ItemsSource = Get-AvailableCommands
                $statusText.Text = "Type to search commands and files..."
                return
            }
            
            if ($naturalMode.IsChecked) {
                $results = Search-NaturalLanguage -Query $query
                $statusText.Text = "Natural Language: Found $($results.Count) matches"
            } else {
                $results = Search-PowerShellCommands -Query $query
                $statusText.Text = "PowerShell Syntax: Found $($results.Count) matches"
            }
            
            $resultsList.ItemsSource = $results
        })
        
        # Handle Enter key
        $searchBox.Add_KeyDown({
            param($Source, $e)
            if ($e.Key -eq 'Return') {
                $selected = $resultsList.SelectedItem
                if ($selected) {
                    Invoke-PaletteCommand -Command $selected
                    $script:CommandHistory.Add($selected) | Out-Null
                    $window.Close()
                }
            } elseif ($e.Key -eq 'Escape') {
                $window.Close()
            }
        })
        
        # Handle list selection
        $resultsList.Add_MouseDoubleClick({
            $selected = $resultsList.SelectedItem
            if ($selected) {
                Invoke-PaletteCommand -Command $selected
                $script:CommandHistory.Add($selected) | Out-Null
                $window.Close()
            }
        })
        
        $searchBox.Focus()
        $window.ShowDialog() | Out-Null
        
    } catch [System.Management.Automation.RuntimeException] {
        Write-Error "PowerShell runtime error in command palette: $($_.Exception.Message)"
        Write-Host "Try restarting PowerShell if the issue persists." -ForegroundColor Yellow
    } catch [System.Windows.Markup.XamlParseException] {
        Write-Error "XAML parsing error: $($_.Exception.Message)"
        Write-Host "The command palette UI definition is corrupted." -ForegroundColor Red
    } catch [System.InvalidOperationException] {
        Write-Error "Invalid operation: $($_.Exception.Message)"
        Write-Host "This may be caused by UI threading issues." -ForegroundColor Yellow
    } catch [System.UnauthorizedAccessException] {
        Write-Error "Access denied creating command palette window."
        Write-Host "Try running with elevated privileges." -ForegroundColor Yellow
    } catch {
        Write-Error "Failed to create command palette: $($_.Exception.Message)"
        Write-Host "Error type: $($_.Exception.GetType().Name)" -ForegroundColor Red
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
        
        # Provide fallback text-based command palette
        Write-Host "`nFalling back to text-based command palette..." -ForegroundColor Yellow
        try {
            $textQuery = Read-Host "Enter command query (or 'exit' to cancel)"
            if ($textQuery -and $textQuery -ne 'exit') {
                $commands = Get-AvailableCommands | Where-Object { $_.Name -like "*$textQuery*" -or $_.Description -like "*$textQuery*" }
                if ($commands) {
                    Write-Host "`nMatching commands:" -ForegroundColor Green
                    $commands | ForEach-Object { Write-Host "  $($_.Name): $($_.Description)" -ForegroundColor Gray }
                    
                    $choice = Read-Host "Enter command number to execute (1-$($commands.Count), or 'exit')"
                    if ($choice -match '^\d+$' -and [int]$choice -le $commands.Count -and [int]$choice -gt 0) {
                        $selectedCommand = $commands[[int]$choice - 1]
                        Invoke-PaletteCommand -Command $selectedCommand
                    }
                } else {
                    Write-Host "No matching commands found." -ForegroundColor Yellow
                }
            }
        } catch {
            Write-Error "Fallback command palette also failed: $($_.Exception.Message)"
        }
    }
}

function Get-AvailableCommands {
    <#
    .SYNOPSIS
        Gets list of available commands for the command palette
    #>
    return @(
        [PSCustomObject]@{ Name = "Find Duplicate Files"; Description = "Search for duplicate files by hash"; Command = "Find-DuplicateFiles" }
        [PSCustomObject]@{ Name = "Calculate Folder Size"; Description = "Calculate and display folder sizes"; Command = "Get-FolderSize" }
        [PSCustomObject]@{ Name = "Search Files"; Description = "Advanced file search with regex"; Command = "Search-Files" }
        [PSCustomObject]@{ Name = "Compare Files"; Description = "Compare two files side-by-side"; Command = "Invoke-FileComparison" }
        [PSCustomObject]@{ Name = "Get Checksum"; Description = "Calculate file checksum (SHA256/SHA512)"; Command = "Get-FileChecksum" }
        [PSCustomObject]@{ Name = "Batch Rename"; Description = "Rename multiple files with patterns"; Command = "Rename-FileBatch" }
        [PSCustomObject]@{ Name = "Sync Directories"; Description = "Synchronize two directories"; Command = "Sync-Directories" }
        [PSCustomObject]@{ Name = "Disk Space Analyzer"; Description = "Analyze disk space usage"; Command = "Get-DiskSpace" }
        [PSCustomObject]@{ Name = "Git Status"; Description = "Show git status for files"; Command = "Get-GitStatus" }
        [PSCustomObject]@{ Name = "Show File Preview"; Description = "Preview file contents"; Command = "Show-FilePreview" }
        [PSCustomObject]@{ Name = "Enhanced Preview"; Description = "Enhanced preview with multi-format support"; Command = "Show-EnhancedPreview" }
        [PSCustomObject]@{ Name = "Preview Word Document"; Description = "Preview .docx files with metadata"; Command = "Show-WordDocumentPreview" }
        [PSCustomObject]@{ Name = "Preview Excel Spreadsheet"; Description = "Preview .xlsx files with data"; Command = "Show-ExcelPreview" }
        [PSCustomObject]@{ Name = "Preview PDF"; Description = "Preview PDF files with metadata"; Command = "Show-PDFPreview" }
        [PSCustomObject]@{ Name = "Preview Video"; Description = "Preview video files with codec info"; Command = "Show-VideoPreview" }
        [PSCustomObject]@{ Name = "Preview Audio"; Description = "Preview audio files with ID3 tags"; Command = "Show-AudioPreview" }
        [PSCustomObject]@{ Name = "Preview SVG"; Description = "Preview SVG vector graphics with structure analysis"; Command = "Show-SVGPreview" }
        [PSCustomObject]@{ Name = "Preview Markdown"; Description = "Preview Markdown files with TOC and statistics"; Command = "Show-MarkdownPreview" }
        [PSCustomObject]@{ Name = "Preview STL/3D Model"; Description = "Preview STL 3D model files with mesh statistics"; Command = "Show-STLPreview" }
        [PSCustomObject]@{ Name = "Preview G-code"; Description = "Preview 3D print G-code with metadata"; Command = "Show-GCodePreview" }
        [PSCustomObject]@{ Name = "Check File Lock"; Description = "See which processes are locking a file"; Command = "Get-FileLock" }
        [PSCustomObject]@{ Name = "Unlock File"; Description = "Close file handles or terminate locking processes"; Command = "Unlock-File" }
        [PSCustomObject]@{ Name = "Test If File Locked"; Description = "Quick check if file is locked"; Command = "Test-FileLocked" }
        [PSCustomObject]@{ Name = "Pin Window On Top"; Description = "Toggle window always on top status"; Command = "Toggle-WindowAlwaysOnTop" }
        [PSCustomObject]@{ Name = "Set Always On Top"; Description = "Pin window to stay on top of others"; Command = "Set-WindowAlwaysOnTop" }
        [PSCustomObject]@{ Name = "Get Window Status"; Description = "Check if window is pinned on top"; Command = "Get-WindowTopMostStatus" }
        [PSCustomObject]@{ Name = "Edit Metadata"; Description = "Edit file metadata and properties"; Command = "Edit-FileMetadata" }
        [PSCustomObject]@{ Name = "Manage Permissions"; Description = "View and edit file permissions"; Command = "Get-FileACL" }
        [PSCustomObject]@{ Name = "Secure Delete"; Description = "Securely wipe files"; Command = "Remove-SecureFile" }
        [PSCustomObject]@{ Name = "Create Symlink"; Description = "Create symbolic link"; Command = "New-Symlink" }
        [PSCustomObject]@{ Name = "Connect to FTP"; Description = "Connect to FTP server"; Command = "Connect-FTP" }
        [PSCustomObject]@{ Name = "Connect to SFTP"; Description = "Connect to SFTP server"; Command = "Connect-SFTP" }
    )
}

function Search-NaturalLanguage {
    <#
    .SYNOPSIS
        Searches using natural language patterns
    #>
    param([string]$Query)
    
    $commands = Get-AvailableCommands
    $query = $Query.ToLower()
    
    # Fuzzy search in command names and descriptions
    $results = $commands | Where-Object {
        $_.Name.ToLower() -like "*$query*" -or 
        $_.Description.ToLower() -like "*$query*"
    }
    
    return $results
}

function Search-PowerShellCommands {
    <#
    .SYNOPSIS
        Searches PowerShell commands and provides autocomplete
    #>
    param([string]$Query)
    
    $commands = Get-Command -Name "*$Query*" -ErrorAction SilentlyContinue | 
        Select-Object -First 20 |
        ForEach-Object {
            [PSCustomObject]@{
                Name = $_.Name
                Description = "PowerShell command: $($_.ModuleName)"
                Command = $_.Name
            }
        }
    
    return $commands
}

function Invoke-PaletteCommand {
    <#
    .SYNOPSIS
        Executes the selected command with comprehensive error handling
    .DESCRIPTION
        Safely executes palette commands with detailed error reporting and recovery
    .PARAMETER Command
        The command object to execute
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Command
    )
    
    try {
        if (-not $Command) {
            Write-Warning "No command provided to execute."
            return
        }
        
        if (-not $Command.Command) {
            Write-Warning "Command object does not contain executable code."
            return
        }
        
        Write-Host "Executing: $($Command.Name ?? 'Unknown Command')" -ForegroundColor Green
        Write-Verbose "Command details: $($Command.Command)"
        
        # Validate command is a scriptblock or valid command
        $commandToExecute = $null
        if ($Command.Command -is [scriptblock]) {
            $commandToExecute = $Command.Command
        } elseif ($Command.Command -is [string]) {
            try {
                $commandToExecute = [scriptblock]::Create($Command.Command)
            } catch {
                throw [System.Management.Automation.ParseException]::new("Invalid command syntax: $($_.Exception.Message)")
            }
        } else {
            throw [System.ArgumentException]::new("Command must be a scriptblock or valid PowerShell string")
        }
        
        # Execute with timeout protection
        $job = Start-Job -ScriptBlock $commandToExecute -ErrorAction Stop
        $completed = Wait-Job -Job $job -Timeout 300 # 5 minute timeout
        
        if ($completed) {
            $result = Receive-Job -Job $job -ErrorAction Stop
            $errors = Receive-Job -Job $job -ErrorAction SilentlyContinue | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
            
            if ($errors) {
                Write-Warning "Command completed with errors:"
                $errors | ForEach-Object { Write-Warning $_.Exception.Message }
            } else {
                Write-Host "Command completed successfully." -ForegroundColor Green
            }
            
            Remove-Job -Job $job -Force
            return $result
        } else {
            Stop-Job -Job $job -Force
            Remove-Job -Job $job -Force
            throw [System.TimeoutException]::new("Command execution timed out after 5 minutes")
        }
        
    } catch [System.Management.Automation.ParseException] {
        Write-Error "Command syntax error: $($_.Exception.Message)"
        Write-Host "Please check the command syntax and try again." -ForegroundColor Yellow
    } catch [System.UnauthorizedAccessException] {
        Write-Error "Access denied executing command. You may need elevated privileges."
        Write-Host "Try running as administrator if required." -ForegroundColor Yellow
    } catch [System.TimeoutException] {
        Write-Error "Command execution timed out: $($_.Exception.Message)"
        Write-Host "The command may be taking too long or has entered an infinite loop." -ForegroundColor Yellow
    } catch [System.Management.Automation.CommandNotFoundException] {
        Write-Error "Command not found: $($_.Exception.Message)"
        Write-Host "Please verify the command exists and is available in the current session." -ForegroundColor Yellow
    } catch {
        Write-Error "Failed to execute command: $($_.Exception.Message)"
        Write-Host "Error type: $($_.Exception.GetType().Name)" -ForegroundColor Red
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
        
        # Provide helpful suggestions based on error type
        if ($_.Exception.Message -like "*not recognized*") {
            Write-Host "Suggestion: Check if the required module is imported." -ForegroundColor Yellow
        } elseif ($_.Exception.Message -like "*access*denied*") {
            Write-Host "Suggestion: Try running with elevated privileges." -ForegroundColor Yellow
        }
    }
}

function Get-CommandHistory {
    <#
    .SYNOPSIS
        Gets the command palette history
    .DESCRIPTION
        Returns the history of commands executed via the command palette
    .EXAMPLE
        Get-CommandHistory
        Returns all command history
    #>
    [CmdletBinding()]
    param()
    
    return $script:CommandHistory
}

function Add-CommandToHistory {
    <#
    .SYNOPSIS
        Adds a command to the command palette history
    .DESCRIPTION
        Records a command in the palette command history
    .PARAMETER Command
        The command string to add to history
    .EXAMPLE
        Add-CommandToHistory -Command "Get-ChildItem"
        Adds the command to history
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command
    )
    
    $script:CommandHistory.Add($Command) | Out-Null
}

Export-ModuleMember -Function Invoke-CommandPalette, Get-CommandHistory, Add-CommandToHistory
