# GitHub Copilot Instructions for PowerShell File Manager

This repository contains a command-centric file manager built with PowerShell 7, featuring rich GUI integration, advanced file operations, and extensive PowerShell scripting capabilities.

## Security Policy

This project follows strict security guidelines to ensure safe file operations and protect user data. All code must adhere to these security requirements.

### Security Headers and Configuration

For any web-based components or HTTP endpoints, implement these mandatory security headers:
- **Content-Security-Policy**: `default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'`
- **X-Frame-Options**: `DENY`
- **X-Content-Type-Options**: `nosniff`
- **X-XSS-Protection**: `1; mode=block`
- **Strict-Transport-Security**: `max-age=31536000; includeSubDomains`
- **Referrer-Policy**: `strict-origin-when-cross-origin`

### Input Validation and Sanitization Library

All user input must be validated and sanitized using these PowerShell security functions:

#### Core Security Functions

1. **Naming Conventions**
   - Use approved PowerShell verbs (Get-, Set-, New-, Remove-, Invoke-, Start-, Stop-, etc.)
   - Follow PascalCase for function names: `Get-FolderSize`, `Start-FileManager`
   - Use PascalCase for parameters: `-InitialPath`, `-WhatIf`, `-Confirm`
   - Use lowercase for variables with descriptive names: `$folderSize`, `$currentPath`

2. **Function Structure**
   - Always include parameter validation using `[Parameter()]` attributes
   - Support `-WhatIf` and `-Confirm` for destructive operations via `[CmdletBinding(SupportsShouldProcess=$true)]`
   - Include comprehensive comment-based help with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`
   - Use proper error handling with `try/catch` blocks and meaningful error messages

3. **Code Organization**
   - Keep functions focused and single-purpose
   - Use advanced functions with proper cmdlet binding
   - Export only public functions; keep helper functions private
   - Follow the existing module structure under `src/Modules/`

### Module Structure

The project is organized into functional modules:

```
src/
├── Modules/
│   ├── Core/                    # Core functionality (CommandPalette, QueryBuilder, etc.)
│   ├── FileOperations/          # File operations (Batch, Archive, etc.)
│   ├── Navigation/              # Navigation features
│   ├── Search/                  # Search functionality
│   ├── Integration/             # External integrations (Git, Cloud, Network)
│   ├── Preview/                 # Preview and metadata
│   ├── Security/                # Security operations
│   ├── PowerToys/               # PowerToys integration features
│   └── System/                  # System features (Background ops, Plugins)
├── Scripts/
│   └── Start-FileManager.ps1    # Main application entry point
├── UI/                          # WPF UI components
└── Resources/                   # Icons, themes, localization
```

When adding new functionality:
- Place code in the appropriate module directory
- Create new modules following the existing pattern
- Update `PowerShellFileManager.psd1` to export new functions
- Update `PowerShellFileManager.psm1` to import new modules

## Security Best Practices

### Security Considerations

1. **File Operations**
   - Validate all file paths to prevent directory traversal attacks
   - Use `Test-SafePath` for path validation
   - Normalize paths using `Resolve-NormalizedPath`
   - Handle symlinks and reparse points carefully

2. **Credentials and Secrets**
   - Never hardcode passwords or API keys
   - Use SecureString for password parameters
   - Use credential management features when available
   - Support Windows Credential Manager integration

3. **Encryption**
   - Use AES-256 for file encryption
   - Implement secure file deletion (DOD 5220.22-M standard)
   - Support digital signatures for file authentication

4. **User Input Validation and Sanitization**
   - **String sanitization**: Escape special characters using `[System.Management.Automation.WildcardPattern]::Escape()`
   - **Script injection prevention**: Use `-Command` parameter with string arrays instead of concatenated strings
   - **File name validation**: Check for illegal characters using `[System.IO.Path]::GetInvalidFileNameChars()`
   - **Size limits**: Implement maximum file size and path length checks
   - **Content type validation**: Verify file extensions match actual file content
   - **Path traversal prevention**: Use `Test-SecureInput` function for all user-provided paths
   - **Command injection prevention**: Never use `Invoke-Expression` with user input
   - **Parameter validation**: Always use `[ValidateScript()]` attributes for complex validation
   - Check file permissions before operations
   - Request UAC elevation when necessary
   - Respect ACLs and security descriptors

## Platform-Specific Considerations

### Cross-Platform Compatibility

1. **Windows-Specific Features**
   - WPF GUI components (only on Windows)
   - Windows API calls (via Add-Type or .NET)
   - Registry access
   - COM objects (Word, Excel integration)
   - Recycle Bin operations
   - PowerToys features

2. **Linux/macOS Support**
   - Use platform-agnostic PowerShell cmdlets when possible
   - Check platform with `$PSVersionTable.Platform` or `$IsWindows`, `$IsLinux`, `$IsMacOS`
   - Provide fallbacks for Windows-only features
   - Use cross-platform path separators

3. **Platform Detection Pattern**
   ```powershell
   if ($IsWindows) {
       # Windows-specific code
   } elseif ($IsLinux) {
       # Linux-specific code
   } elseif ($IsMacOS) {
       # macOS-specific code
   }
   ```

## Dependency Management

### Required Dependencies

- **PowerShell 7.0+** (PowerShell Core)
- **.NET Framework 4.7.2+** (for WPF on Windows)

### Optional Dependencies

- **FFprobe** (for video/audio metadata extraction)
- **Tesseract OCR** (for text extraction from images)
- **7-Zip** (for advanced archive operations)
- **Robocopy** (enterprise file copying on Windows)

### Dependency Handling

- Check for optional dependencies before use
- Provide graceful degradation when dependencies are missing
- Include helpful error messages guiding users to install missing components
- Document dependency requirements in function help

## Performance Considerations

### Optimization Patterns

1. **Caching**
   - Use concurrent dictionaries for thread-safe caching
   - Implement 30-minute cache refresh cycles
   - Provide cache statistics and management functions

2. **Background Operations**
   - Use runspace pools for parallel operations
   - Implement progress reporting for long-running tasks
   - Support operation queuing with pause/resume

3. **Memory Management**
   - Dispose of IDisposable objects properly
   - Clear large data structures when no longer needed
   - Monitor memory usage in long-running operations

4. **File Operations**
   - Use streaming for large file operations
   - Implement batching for bulk operations
   - Use Robocopy integration for enterprise-level copying

## GUI Development

### WPF Guidelines (Windows Only)

1. **XAML Structure**
   - Keep XAML definitions in separate files or strings
   - Use data binding for dynamic updates
   - Follow MVVM pattern where applicable

2. **Event Handling**
   - Use event handlers for user interactions
   - Implement proper cleanup on window close
   - Handle threading properly (UI thread vs background)

3. **User Experience**
   - Provide real-time feedback for operations
   - Show progress indicators for long tasks
   - Implement keyboard shortcuts consistently
   - Support command palette (Ctrl+P) as primary interface

## Error Handling

### Error Handling Patterns

1. **Try/Catch Blocks**
   ```powershell
   try {
       # Operation code
   }
   catch {
       Write-Error "Failed to perform operation: $_"
       throw
   }
   ```

2. **Meaningful Error Messages**
   - Provide context about what failed
   - Include suggestions for resolution
   - Use structured error tracking

3. **Logging**
   - Use centralized logging system
   - Include correlation IDs for tracking
   - Support log rotation and filtering
   - Provide log analysis capabilities

## Documentation Standards

### Function Documentation

Include comprehensive comment-based help for all exported functions:

```powershell
<#
.SYNOPSIS
    Brief description of the function.

.DESCRIPTION
    Detailed description of what the function does.

.PARAMETER ParameterName
    Description of the parameter.

.EXAMPLE
    Example-Function -ParameterName "Value"
    Description of what this example does.

.NOTES
    Additional information about the function.

.LINK
    Related functions or documentation.
    
function Example-Function {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ParameterName
    )
    
    # Function implementation
}
```

## Integration Features

### External Tool Integration

- Use tool registry system for external applications
- Support file type associations
- Track tool execution statistics
- Persist tool configurations

### Version Control Integration

- Provide Git status indicators
- Support branch information display
- Detect merge conflicts
- Show file modification states

### Cloud Storage Integration

- Support OneDrive and Dropbox sync status
- Implement real-time status updates
- Handle sync conflicts gracefully

## Contribution Guidelines

When contributing to this project:

### Parameter Validation and Input Sanitization
2. **Follow existing patterns** in the codebase
3. **Update documentation** for new features
4. **Check code style** follows PowerShell best practices
5. **Platform testing** - Test on multiple platforms when possible
### Parameter Validation and Input Sanitization

Always use the security functions for input validation:
```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,
    
    [Parameter()]
    [ValidateSet('Copy', 'Move', 'Delete')]
    [string]$Operation = 'Copy'
)
```

### Pipeline Support

```powershell
begin {
    # Initialize
}
process {
    # Process each pipeline item
}
end {
    # Cleanup
}
```

### WhatIf/Confirm Support

For destructive operations, always implement WhatIf and Confirm support:
