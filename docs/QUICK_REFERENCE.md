# PowerShell File Manager V2.0 - Quick Reference

## 🚀 Quick Start

```powershell
# Import the module
Import-Module PowerShellFileManager

# Launch the GUI
Start-FileManager
```

## 📋 Essential Commands

### File Operations

```powershell
# Find duplicate files
Find-DuplicateFiles -Path "C:\Data" -Method Hash

# Get folder size
Get-FolderSize -Path "C:\Projects"

# Calculate checksum
Get-FileChecksum -Path "file.iso" -Algorithm SHA256

# Batch rename
Rename-FileBatch -Path "C:\Photos" -Pattern "IMG_" -Replacement "Photo_"

# Create symlink
New-Symlink -Path "C:\link" -Target "C:\target" -Type SymbolicLink

# Sync directories
Sync-Directories -Source "C:\Source" -Destination "D:\Backup" -Mode Mirror
```

### Search & Analysis

```powershell
# Search files by pattern
Search-Files -Path "C:\Code" -Pattern "\.cs$"

# Search in file contents
Search-Files -Path "C:\Docs" -Pattern "TODO" -ContentSearch

# Analyze disk space
Get-DiskSpace -Path "C:\" -Depth 3
```

### Archives

```powershell
# Create archive
New-Archive -Path "C:\Files" -Destination "archive.zip"

# Extract archive
Expand-Archive -Path "archive.zip" -Destination "C:\Extracted"

# List archive contents
Get-ArchiveContent -Path "archive.zip"
```

### Security

```powershell
# View file ACL
Get-FileACL -Path "C:\file.txt"

# Set permissions
Set-FileACL -Path "C:\file.txt" -Principal "DOMAIN\User" -Rights Read -Type Allow

# Secure delete (7-pass wipe)
Remove-SecureFile -Path "sensitive.txt" -Passes 7
```

### Git Integration

```powershell
# Get git status
Get-GitStatus -Path "C:\MyRepo"

# Show diff
Invoke-GitDiff -File "README.md"
```

### GUI Components

```powershell
# Open Command Palette
Invoke-CommandPalette

# Open Query Builder
New-QueryBuilder -InitialPath "C:\Data"

# Open Script Workspace
New-ScriptWorkspace

# Inspect file properties
Show-ObjectInspector -Path "C:\file.txt"

# Manage runspaces
Start-RunspaceManager
```

### Network Operations

```powershell
# Connect to FTP
Connect-FTP -Server "ftp.example.com"

# Connect to SFTP  
Connect-SFTP -Server "sftp.example.com"
```

### Batch Operations

```powershell
# Start batch operation
Get-ChildItem *.txt | Start-BatchOperation -Operation Copy

# View background operations
Get-BackgroundOperations

# Stop operation
Stop-BackgroundOperation -Id <guid>
```

### Metadata & Preview

```powershell
# Show file preview (basic)
Show-FilePreview -Path "file.txt"

# Enhanced preview (auto-detects format)
Show-EnhancedPreview -Path "document.docx"

# Preview Word documents (.docx)
Show-WordDocumentPreview -Path "report.docx"
# Shows: pages, words, characters, title, author, content preview

# Preview Excel spreadsheets (.xlsx)
Show-ExcelPreview -Path "data.xlsx" -MaxRows 20
# Shows: worksheets, dimensions, data preview, metadata

# Preview PDFs
Show-PDFPreview -Path "manual.pdf"
# Shows: version, page count, title, author, metadata

# Preview videos (.mp4, .avi, .mkv, .mov, .wmv, .flv)
Show-VideoPreview -Path "video.mp4"
# Shows: resolution, codec, duration, bitrate, frame rate

# Preview audio files (.mp3, .wav, .flac, .aac, .ogg, .wma, .m4a)
Show-AudioPreview -Path "song.mp3"
# Shows: ID3 tags (title, artist, album), bitrate, duration

# Preview SVG vector graphics (.svg)
Show-SVGPreview -Path "image.svg"
# Shows: dimensions, viewBox, element counts, structure, CSS/JavaScript

# Preview Markdown files (.md, .markdown)
Show-MarkdownPreview -Path "README.md"
# Shows: heading counts, links, images, table of contents, content preview

# Preview STL 3D models (.stl)
Show-STLPreview -Path "model.stl"
# Shows: binary/ASCII format, triangle/vertex counts, complexity, file integrity

# Preview G-code files (.gcode, .gco, .g)
Show-GCodePreview -Path "print.gcode"
# Shows: layer count, temperatures, filament usage, slicer info, print time

# Get metadata
Get-FileMetadata -Path "photo.jpg"

# Edit metadata
Edit-FileMetadata -Path "file.txt" -Properties @{
    ReadOnly = $true
    CreationTime = "2025-01-01"
}
```

### File Locksmith (PowerToys Integration)

```powershell
# Check which processes are locking a file
Get-FileLock -Path "C:\file.txt"

# Show detailed process information
Get-FileLock -Path "C:\file.txt" -ShowDetails

# Quick test if file is locked
Test-FileLocked -Path "C:\file.txt"
# Returns: $true if locked, $false if not

# Unlock file (requires Administrator)
Unlock-File -Path "C:\file.txt" -ProcessId 1234

# Force unlock by terminating process
Unlock-File -Path "C:\file.txt" -Force
# Prompts for confirmation before terminating

# Show GUI dialog with lock information
Show-FileLockInfo -Path "C:\file.txt"

# Example: Check and unlock in one operation
$locks = Get-FileLock -Path "C:\file.txt"
if ($locks) {
    Write-Host "File is locked by: $($locks.ProcessName -join ', ')"
    Unlock-File -Path "C:\file.txt" -Force
}
```

### Always On Top (PowerToys Integration)

```powershell
# Toggle current window on/off top
Switch-WindowAlwaysOnTop
# Toggles between pinned and unpinned (approved verb)

# Pin current foreground window on top
Set-WindowAlwaysOnTop -Enable

# Unpin current window
Set-WindowAlwaysOnTop
# Without -Enable, it unpins the window

# Pin a specific window by title
Set-WindowAlwaysOnTop -WindowTitle "PowerShell" -Enable

# Pin window by process ID
Set-WindowAlwaysOnTop -ProcessId 1234 -Enable

# Toggle a specific window
Switch-WindowAlwaysOnTop -WindowTitle "File Manager"

# Check if window is pinned
Get-WindowTopMostStatus
# Shows current foreground window status

# Check specific window status
Get-WindowTopMostStatus -WindowTitle "Notepad"
# Returns: WindowHandle, WindowTitle, IsTopMost, ProcessId, Status

# Example: Pin current window with visual feedback
$result = Set-WindowAlwaysOnTop -Enable
Show-WindowPinIndicator -WindowTitle $result.WindowTitle -IsPinned $result.IsTopMost

# Natural language commands (via Command Palette):
# - "pin window" - Toggle current window
# - "always on top" - Toggle current window
# - "pin on top" - Enable pinning
# - "unpin window" - Disable pinning
# - "window status" - Show current status
```

### PowerToys Features

```powershell
# Image Resizer - Batch resize images
Resize-Image -Path "photo.jpg" -Width 800 -KeepAspectRatio
Resize-Image -Path "photo.jpg" -Height 600 -KeepAspectRatio
Convert-ImageFormat -Path "image.png" -Format JPG -Quality 90

# Text Extractor (OCR) - Extract text from images
Start-ScreenTextExtractor  # Interactive screen capture
Get-TextFromImage -Path "screenshot.png"  # Extract from file
Get-TextFromImage -Path "document.png" -Language "en-US"

# Color Picker - Pick colors from screen
Get-ColorFromScreen -Format HEX
Get-ColorFromScreen -Format RGB
Get-ColorFromScreen -Format HSL
Convert-ColorFormat -Color "#FF5733" -From HEX -To RGB

# Hosts File Editor - Manage system hosts file
Get-HostsEntry  # List all entries
Add-HostsEntry -IPAddress "127.0.0.1" -Hostname "local.test"
Add-HostsEntry -IPAddress "192.168.1.100" -Hostname "dev.example.com"
Remove-HostsEntry -Hostname "local.test"
Backup-HostsFile  # Create backup
Restore-HostsFile -BackupPath "C:\hosts.backup"

# Quick Accent - Access accented characters
Show-QuickAccentMenu  # Display accent menu
Get-AccentCharacter -BaseChar "a" -Accent "acute"  # Returns: á
Get-AccentCharacter -BaseChar "e" -Accent "grave"  # Returns: è

# Keyboard Shortcut Guide
Show-ShortcutGuide  # Display comprehensive shortcut guide
Get-ShortcutList  # Get list of all shortcuts
Get-ShortcutList -Category "FileManager"  # Filter by category

# Workspace Layouts - Window arrangement (FancyZones)
Save-WorkspaceLayout -Name "Development"
Apply-WorkspaceLayout -Name "Development"
Get-WorkspaceLayout  # List all saved layouts
Remove-WorkspaceLayout -Name "OldLayout"

# Template Manager - Create files from templates
New-FileFromTemplate -Template "PowerShellScript" -Path "script.ps1"
New-FileFromTemplate -Template "MarkdownDoc" -Path "README.md" -Variables @{Title="My Project"}
Get-Template  # List available templates
Add-Template -Name "CustomTemplate" -Content "template content" -Variables @("Name", "Date")

# Awake Mode - Keep system awake
Enable-AwakeMode -Duration 3600  # Keep awake for 1 hour (in seconds)
Enable-AwakeMode -Indefinite  # Keep awake indefinitely
Disable-AwakeMode  # Stop awake mode
Get-AwakeModeStatus  # Check current status

# PowerRename - Advanced batch renaming
Invoke-PowerRename -Path "C:\Photos" -Find "IMG_" -Replace "Photo_"
Invoke-PowerRename -Path "C:\Files" -Find "(\d+)" -Replace "File_$1" -UseRegex
Invoke-PowerRename -Path "C:\Docs" -CaseConversion "TitleCase"
Invoke-PowerRename -Path "C:\Items" -AddNumbering -StartNumber 1 -Padding 3
```

### Navigation

```powershell
# Get navigation history
Get-NavigationHistory

# Navigate back
Invoke-NavigationBack

# Navigate forward
Invoke-NavigationForward

# Quick filter
Invoke-QuickFilter -Filter "log"
```

### Saved Searches

```powershell
# Save search query
Save-SearchQuery -Name "FindLogs" -Query {
    Get-ChildItem -Filter "*.log" -Recurse | Where-Object { $_.Length -gt 1MB }
}

# List saved searches
Get-SavedSearches
```

### Plugins

```powershell
# List plugins
Get-PluginList

# Install plugin
Install-Plugin -Path "C:\MyPlugin.psm1"

# Uninstall plugin
Uninstall-Plugin -Name "MyPlugin"
```

## ⌨️ Keyboard Shortcuts (GUI)

| Shortcut | Action |
|----------|--------|
| `Ctrl+P` | Open Command Palette |
| `F5` | Refresh current directory |
| `Alt+←` | Navigate back |
| `Alt+→` | Navigate forward |
| `Backspace` | Go to parent directory |
| `Del` | Delete selected items |
| `F2` | Rename selected item |

## 💡 Tips

### Command Pipeline

```powershell
# Chain commands together
Get-ChildItem -Filter "*.log" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
    Start-BatchOperation -Operation Delete
```

### WhatIf Mode

```powershell
# Preview operations before executing
Sync-Directories -Source "C:\Source" -Destination "D:\Backup" -WhatIf
Rename-FileBatch -Path "C:\Files" -Pattern "old" -Replacement "new" -WhatIf
```

### Background Operations

```powershell
# Start long-running copy in background
$job = Start-BackgroundCopy -Source "C:\Large" -Destination "D:\Backup"

# Continue working...

# Check status later
Get-BackgroundOperations | Where-Object { $_.Id -eq $job.Id }
```

### Error Handling

```powershell
# Robust error handling
try {
    Find-DuplicateFiles -Path "C:\Data" -Method Hash
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
```

## 📖 Help System

```powershell
# Get help for any command
Get-Help Find-DuplicateFiles -Full
Get-Help Sync-Directories -Examples
Get-Help Get-FileACL -Detailed

# List all commands
Get-Command -Module PowerShellFileManager

# Search for commands
Get-Command *Duplicate*
Get-Command *Archive*
```

## 🔧 Configuration

Module config is stored at:

- Windows: `$env:APPDATA\PowerShellFileManager`
- Linux: `~/.config/PowerShellFileManager`

## 📚 More Resources

- [README](../README.md) - Full documentation
- [Getting Started](GETTING_STARTED.md) - Tutorials
- [Examples](EXAMPLES.md) - 10 practical scripts
- [GitHub Issues](https://github.com/Heathen-Volholl/PowerShellFileManagerV2.0/issues) - Support

---

**PowerShell File Manager V2.0** | Command-centric file management for PowerShell 7
