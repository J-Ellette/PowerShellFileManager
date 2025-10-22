# Getting Started with PowerShell File Manager V2.0

This guide will help you get started with the PowerShell File Manager V2.0.

## Installation

### Prerequisites

1. **PowerShell 7.0 or later** - Download from [PowerShell GitHub](https://github.com/PowerShell/PowerShell/releases)
2. **Windows 10/11** or Windows Server 2016+
3. **.NET Framework 4.7.2+** (usually pre-installed on modern Windows)

### Install PowerShell 7

```powershell
# Using winget
winget install Microsoft.PowerShell

# Or download installer from GitHub
# https://github.com/PowerShell/PowerShell/releases
```

### Import the Module

```powershell
# Navigate to the module directory
cd PowerShellFileManagerV2.0

# Import the module
Import-Module .\PowerShellFileManager.psd1

# Verify installation
Get-Module PowerShellFileManager
```

## First Launch

### Start the File Manager

```powershell
# Launch the GUI
Start-FileManager
```

This will open the main file manager window with:

- Menu bar (File, View, Operations, Tools, Help)
- Toolbar with quick access buttons
- Address bar for path navigation
- Main file list view
- Side panel with Preview/Properties/History tabs
- Console output panel at the bottom
- Status bar

## Basic Navigation

### Using the GUI

1. **Navigate folders** - Double-click folders in the file list
2. **Go back/forward** - Use the Back/Forward buttons in the toolbar
3. **Go up** - Click the "Up" button to go to parent directory
4. **Type path** - Enter a path in the address bar and click "Go"

### Using Navigation History

```powershell
# Get navigation history
Get-NavigationHistory

# Navigate back
Invoke-NavigationBack

# Navigate forward
Invoke-NavigationForward
```

## Command Palette (Ctrl+P)

The Command Palette is the primary interface for the file manager.

### Open Command Palette

- Press `Ctrl+P` anywhere in the application
- Or click the "🔍 Command Palette" button in the toolbar

### Natural Language Mode

Type queries in plain English:

- "find large files" - Shows files larger than 100MB
- "show images modified today" - Filters today's image files
- "find duplicate files" - Runs duplicate file finder
- "recent files" - Shows files modified in last 7 days

### PowerShell Syntax Mode

Switch to PowerShell mode and use actual PowerShell commands:

```powershell
Get-ChildItem -Filter "*.log"
Search-Files -Pattern "error"
Find-DuplicateFiles -Method Hash
```

## Query Builder

Build complex searches visually without writing code.

### Open Query Builder

```powershell
New-QueryBuilder
```

Or click "Query Builder" in the toolbar.

### Building a Query

1. Click "Add Filter" to add search criteria
2. Select property (Name, Size, Modified, etc.)
3. Choose operator (Equals, Contains, Greater Than, etc.)
4. Enter value
5. Add multiple filters - they combine with AND logic
6. See generated PowerShell query in real-time
7. Preview results before executing

### Example Queries

**Find large PDF files:**

- Property: Extension
- Operator: Equals
- Value: .pdf

AND

- Property: Size
- Operator: Greater Than
- Value: 10485760 (10MB)

**Find recently modified images:**

- Property: Extension
- Operator: Equals
- Value: .jpg

AND

- Property: Modified
- Operator: Greater Than
- Value: 2025-01-01

## Script Workspace

Write and execute PowerShell scripts with full IDE-like experience.

### Open Script Workspace

```powershell
New-ScriptWorkspace
```

Or select "Script Workspace" from the File menu.

### Features

- Syntax highlighting for PowerShell code
- Line numbers
- Run scripts with F5
- Stop running scripts
- Separate output panes (Output, Errors, Warnings, Verbose)
- Save/Load scripts
- Auto-refresh line numbers

### Example Script

```powershell
# Find all files larger than 100MB
Get-ChildItem -Path C:\ -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -gt 100MB } |
    Select-Object Name, Length, LastWriteTime |
    Sort-Object Length -Descending |
    Format-Table -AutoSize
```

## Common Operations

### Find Duplicate Files

```powershell
# Find duplicates by content hash (most accurate)
Find-DuplicateFiles -Path "C:\MyFiles" -Method Hash

# Find duplicates by file name
Find-DuplicateFiles -Path "C:\MyFiles" -Method Name

# Find duplicates by size (fastest, less accurate)
Find-DuplicateFiles -Path "C:\MyFiles" -Method Size
```

### Calculate Folder Sizes

```powershell
# Get size of a specific folder
Get-FolderSize -Path "C:\Windows"

# Analyze disk space with tree view
Get-DiskSpace -Path "C:\" -Depth 3
```

### Batch Rename Files

```powershell
# Preview rename operation
Rename-FileBatch -Path "C:\Photos" -Pattern "IMG_" -Replacement "Photo_" -WhatIf

# Execute rename
Rename-FileBatch -Path "C:\Photos" -Pattern "IMG_" -Replacement "Photo_"
```

### Synchronize Directories

```powershell
# Update mode - only copy new/changed files
Sync-Directories -Source "C:\Projects" -Destination "D:\Backup" -Mode Update

# Mirror mode - make exact copy, delete extra files
Sync-Directories -Source "C:\Projects" -Destination "D:\Backup" -Mode Mirror

# Preview with WhatIf
Sync-Directories -Source "C:\Projects" -Destination "D:\Backup" -Mode Mirror -WhatIf
```

### File Checksums

```powershell
# Calculate SHA256 checksum
Get-FileChecksum -Path "file.iso" -Algorithm SHA256

# Calculate MD5 checksum
Get-FileChecksum -Path "file.zip" -Algorithm MD5
```

### Archive Operations

```powershell
# Create ZIP archive
New-Archive -Path "C:\MyFolder" -Destination "archive.zip" -Format ZIP

# Extract archive
Expand-Archive -Path "archive.zip" -Destination "C:\Extracted"

# List archive contents
Get-ArchiveContent -Path "archive.zip"
```

## Advanced Features

### Object Inspector

Inspect any file or PowerShell object to see all properties.

```powershell
# Inspect a file
Show-ObjectInspector -Path "C:\file.txt"

# Inspect any PowerShell object
Get-Process | Select-Object -First 1 | Show-ObjectInspector
```

### Runspace Manager

Manage multiple PowerShell sessions.

```powershell
Start-RunspaceManager
```

Features:

- View active runspaces
- Create new runspaces
- Import modules
- View loaded modules and variables
- Monitor performance

### Git Integration

```powershell
# Show git status for repository
Get-GitStatus -Path "C:\MyRepo"

# Show file diff
Invoke-GitDiff -File "README.md"
```

### Security Operations

```powershell
# View file permissions
Get-FileACL -Path "C:\file.txt"

# Set file permissions
Set-FileACL -Path "C:\file.txt" -Principal "DOMAIN\User" -Rights Read -Type Allow

# Secure delete (7-pass wipe)
Remove-SecureFile -Path "sensitive.txt" -Passes 7
```

## Tips and Tricks

### Keyboard Shortcuts

- `Ctrl+P` - Command Palette
- `F5` - Refresh current directory
- `Alt+Left` - Navigate back
- `Alt+Right` - Navigate forward
- `Backspace` - Go to parent directory

### Quick Filter

Type in the file list to filter files in real-time:

```powershell
Invoke-QuickFilter -Filter "log"
```

### Background Operations

Long-running operations run in the background:

```powershell
# Start background copy
Start-BackgroundCopy -Source "C:\Large" -Destination "D:\Backup"

# View background operations
Get-BackgroundOperations

# Stop an operation
Stop-BackgroundOperation -Id <guid>
```

### Saved Searches

Save frequently used searches as reusable queries:

```powershell
# Save a search
Save-SearchQuery -Name "FindLogs" -Query {
    Get-ChildItem -Filter "*.log" -Recurse | 
    Where-Object { $_.Length -gt 1MB }
}

# List saved searches
Get-SavedSearches
```

## Troubleshooting

### Module Not Loading

```powershell
# Check PowerShell version
$PSVersionTable.PSVersion

# Should be 7.0 or higher
```

### GUI Not Opening

```powershell
# Verify .NET Framework
Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse |
    Get-ItemProperty -Name Version -ErrorAction SilentlyContinue |
    Where-Object { $_.PSChildName -match '^(?!S)\p{L}' } |
    Select-Object PSChildName, Version
```

### Permission Errors

Some operations require administrator privileges:

```powershell
# Run PowerShell as Administrator
# Right-click PowerShell icon -> Run as Administrator
```

## Next Steps

- Explore the [README](../README.md) for complete feature list
- Check out example scripts in the `Examples` directory
- Install plugins from the plugin marketplace
- Customize themes and keyboard shortcuts
- Join the community discussions

## Getting Help

```powershell
# Get help for any command
Get-Help Start-FileManager -Full
Get-Help Find-DuplicateFiles -Examples
Get-Help Sync-Directories -Detailed

# List all available commands
Get-Command -Module PowerShellFileManager
```

---

Happy file managing! 🚀
