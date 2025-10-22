# GUI Menu Structure - PowerShell File Manager V2.0

## Complete Menu Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│ PowerShell File Manager V2.0                                │
├─────────────────────────────────────────────────────────────┤
│ File │ View │ Operations │ Tools │ Help                     │
└─────────────────────────────────────────────────────────────┘

FILE MENU
├── 🎯 Open Command Palette (Ctrl+P)          [EXISTING]
├── 🔧 Query Builder                          [EXISTING]
├── 📝 Script Workspace                       [EXISTING]
├── ─────────────────
└── ❌ Exit                                   [EXISTING]

VIEW MENU
├── 🔍 Object Inspector                       [EXISTING]
├── ⚙️  Runspace Manager                      [EXISTING]
└── 🔄 Refresh (F5)                          [EXISTING]

OPERATIONS MENU
├── 📦 Batch Operations                       [EXISTING - ADDED HANDLER ✨]
├── 🔍 Find Duplicates                        [EXISTING]
├── 🔄 Sync Directories                       [EXISTING - ADDED HANDLER ✨]
├── 💾 Disk Space Analyzer                    [EXISTING]
├── ─────────────────
├── 📚 Archive Operations                     [NEW ✨]
│   ├── ➕ Create Archive
│   ├── 📂 Extract Archive
│   └── 👁️  View Archive Contents
└── 🔎 Advanced Search                        [NEW ✨]

TOOLS MENU
├── 🔀 Git Status                             [EXISTING]
├── 🌐 Connect FTP/SFTP                       [EXISTING - ADDED HANDLER ✨]
├── ✏️  Metadata Editor                       [NEW ✨]
├── ─────────────────
├── 🔧 PowerToys                              [NEW ✨]
│   ├── 🖼️  Image Resizer
│   ├── 📝 Text Extractor (OCR)
│   ├── 🎨 Color Picker
│   ├── 🌐 Hosts File Editor
│   ├── ✏️  Quick Accent
│   ├── ⌨️  Keyboard Shortcuts
│   ├── 🗂️  Workspace Layouts
│   ├── 📄 Template Manager
│   ├── ☕ Awake Mode
│   └── 🔄 PowerRename
├── ─────────────────
├── 🔒 Security                               [NEW ✨]
│   ├── 👀 View File ACL
│   ├── ✏️  Edit File ACL
│   └── 🗑️  Secure Delete
├── ─────────────────
└── 🧩 Plugins                                [EXISTING - ADDED HANDLER ✨]

HELP MENU
├── ℹ️  About                                 [EXISTING]
└── 📖 Documentation                          [EXISTING - ADDED HANDLER ✨]
```

## Legend

- **[EXISTING]** - Menu item existed but may not have had handler
- **[NEW ✨]** - Newly added menu item with handler
- **[ADDED HANDLER ✨]** - Menu item existed, handler was added

## What Changed

### Previously Missing Handlers (Now Added)
1. ✅ MenuBatchOps - Opens batch operations for selected files
2. ✅ MenuSyncDirs - Directory synchronization with folder browser
3. ✅ MenuConnect - FTP/SFTP connection dialog
4. ✅ MenuPlugins - Plugin manager display
5. ✅ MenuDocs - Opens README.md documentation

### Newly Added Menus & Handlers
1. ✅ Archive Operations submenu (3 items)
   - Create Archive - ZIP/TAR/7Z creation
   - Extract Archive - Archive extraction
   - View Archive Contents - Archive content viewer

2. ✅ Security submenu (3 items)
   - View File ACL - Display file permissions
   - Edit File ACL - Modify file permissions
   - Secure Delete - Secure file deletion

3. ✅ PowerToys submenu (10 items)
   - Image Resizer - Batch image processing
   - Text Extractor (OCR) - Extract text from images
   - Color Picker - Pick colors from screen
   - Hosts File Editor - Manage system hosts file
   - Quick Accent - Access accented characters
   - Keyboard Shortcuts - View shortcut guide
   - Workspace Layouts - Manage window arrangements
   - Template Manager - Create files from templates
   - Awake Mode - Keep system awake
   - PowerRename - Advanced batch renaming

4. ✅ Individual menu items (2 items)
   - Metadata Editor - Edit file attributes
   - Advanced Search - Fuzzy and regex search

### Removed Features
- ❌ Task Manager - Removed per requirements (functionality and menu entry)

## Total Changes
- **18 new menu items** added (10 PowerToys + 8 others)
- **3 new submenus** created (Archive Operations, Security, PowerToys)
- **5 existing menu items** now have working handlers
- **23 total new event handlers** implemented
- **1 feature removed** (Task Manager)

## Code Changes
- Only 1 file modified: `src/Scripts/Start-FileManager.ps1`
- Lines added: ~800 lines of XAML menu definitions and event handler code
- No breaking changes to existing functionality
- All changes are additive except Task Manager removal
