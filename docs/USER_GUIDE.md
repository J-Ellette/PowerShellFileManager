# User Guide: Accessing New Features in the GUI

This guide shows you how to access all the newly integrated features in the PowerShell File Manager V2.0 GUI.

## Quick Access Guide

### 1. Archive Operations 📚

**Menu Path:** Operations > Archive Operations

**Create Archive:**

1. Select files or folders in the file list
2. Click Operations > Archive Operations > Create Archive
3. Choose archive format (ZIP, TAR, or 7Z)
4. Select destination and click Save

**Extract Archive:**

1. Select an archive file (.zip, .tar, .7z)
2. Click Operations > Archive Operations > Extract Archive
3. Choose destination folder
4. Archive will be extracted to the selected location

**View Archive Contents:**

1. Select an archive file
2. Click Operations > Archive Operations > View Archive Contents
3. A dialog will show all files contained in the archive

### 2. Security Operations 🔒

**Menu Path:** Tools > Security

**View File ACL:**

1. Select a file or folder
2. Click Tools > Security > View File ACL
3. A dialog shows owner, group, and access rules

**Edit File ACL:**

1. Select a file or folder
2. Click Tools > Security > Edit File ACL
3. Enter user/group identity (e.g., DOMAIN\User)
4. Enter rights (e.g., FullControl, Read, Write)
5. ACL will be updated

**Secure Delete:**

1. Select files to delete
2. Click Tools > Security > Secure Delete
3. Confirm the deletion
4. Files will be securely overwritten and deleted

### 3. Advanced Search 🔎

**Menu Path:** Operations > Advanced Search

1. Click Operations > Advanced Search
2. Enter search term (supports wildcards and regex)
3. Results will be displayed in the file grid
4. You can navigate to found files directly

### 4. Metadata Editor ✏️

**Menu Path:** Tools > Metadata Editor

1. Select a file (not a folder)
2. Click Tools > Metadata Editor
3. Choose attribute to modify (ReadOnly, Hidden, Archive, System)
4. Choose True or False for the attribute
5. File metadata will be updated

### 5. PowerToys Features 🔧

**Menu Path:** Tools > PowerToys

**Image Resizer:**

1. Select one or more image files (.jpg, .png, .bmp, .gif, .tiff)
2. Click Tools > PowerToys > Image Resizer
3. Enter target width (leave empty to keep aspect ratio)
4. Images will be resized

**Text Extractor (OCR):**

1. Click Tools > PowerToys > Text Extractor (OCR)
2. Use the screen capture to select text
3. Extracted text will be displayed

**Color Picker:**

1. Click Tools > PowerToys > Color Picker
2. Pick a color from anywhere on screen
3. Color code will be displayed in HEX format

**Hosts File Editor:**

1. Click Tools > PowerToys > Hosts File Editor
2. View current hosts file entries
3. Use Get-HostsEntry, Add-HostsEntry, Remove-HostsEntry cmdlets for editing

**Quick Accent:**

1. Click Tools > PowerToys > Quick Accent
2. Select accented characters from the menu

**Keyboard Shortcuts:**

1. Click Tools > PowerToys > Keyboard Shortcuts
2. View comprehensive keyboard shortcut guide

**Workspace Layouts:**

1. Click Tools > PowerToys > Workspace Layouts
2. Save or apply window arrangements

**Template Manager:**

1. Click Tools > PowerToys > Template Manager
2. Create files from predefined templates

**Awake Mode:**

1. Click Tools > PowerToys > Awake Mode
2. Keep system awake during long operations

**PowerRename:**

1. Click Tools > PowerToys > PowerRename
2. Perform advanced batch renaming with regex support

### 6. Batch Operations 📦

**Menu Path:** Operations > Batch Operations

1. Select multiple files
2. Click Operations > Batch Operations
3. The batch operations window opens
4. Configure your batch operation
5. Execute the operation on all selected files

### 7. Directory Synchronization 🔄

**Menu Path:** Operations > Sync Directories

1. Navigate to the source directory
2. Click Operations > Sync Directories
3. Choose destination directory in the folder browser
4. The sync operation runs with WhatIf preview
5. Review changes before applying

### 8. Network Operations 🌐

**Menu Path:** Tools > Connect FTP/SFTP

**FTP Connection:**

1. Click Tools > Connect FTP/SFTP
2. Click "Yes" for FTP
3. Enter FTP server address
4. Enter credentials when prompted
5. Connection details are stored for the session

**SFTP Connection:**

1. Click Tools > Connect FTP/SFTP
2. Click "No" for SFTP
3. Enter SFTP server address
4. Enter credentials when prompted
5. Connection details are stored for the session

### 9. Plugin Manager 🧩

**Menu Path:** Tools > Plugins

1. Click Tools > Plugins
2. View list of installed plugins
3. See plugin names and versions

### 10. Documentation 📖

**Menu Path:** Help > Documentation

1. Click Help > Documentation
2. README.md opens in your default text editor
3. Browse complete documentation

## Already Available Features

These features were already accessible in the GUI and remain unchanged:

### File Menu

- **Command Palette (Ctrl+P)** - Quick command access
- **Query Builder** - Visual query construction
- **Script Workspace** - PowerShell script editor

### View Menu

- **Object Inspector** - View file properties and metadata
- **Runspace Manager** - Manage PowerShell sessions
- **Refresh (F5)** - Reload current directory

### Operations Menu

- **Find Duplicates** - Find duplicate files by hash/name/size
- **Disk Space Analyzer** - Analyze folder sizes

### Tools Menu

- **Git Status** - View git repository status

## Keyboard Shortcuts

- **Ctrl+P** - Open Command Palette
- **F5** - Refresh current directory
- **Double-click** - Open folder or file

## Tips

1. **Selection Required:** Many operations require selecting files first
2. **Console Output:** Watch the console output pane for operation progress
3. **Error Messages:** Informative dialogs appear for errors or missing selections
4. **WhatIf Support:** Some operations (like Sync) use WhatIf preview
5. **Background Operations:** Long-running tasks appear in the Background Operations tab

## Troubleshooting

**"No Selection" Message:**

- Make sure you've selected files in the file grid before using file-specific operations

**"Access Denied":**

- Some operations (ACL editing, secure delete) may require administrator privileges

**"Function Not Found":**

- Ensure all modules are properly loaded (restart the application)

**Archive Operations Not Working:**

- Ensure 7-Zip is installed for TAR and 7Z formats
- ZIP format uses built-in PowerShell functionality

## Getting Help

- Use the Command Palette (Ctrl+P) for quick command access
- Check the Documentation (Help > Documentation) for detailed information
- Use Object Inspector to examine file properties and metadata

---

**All features are now accessible from both the GUI and PowerShell command line!**
