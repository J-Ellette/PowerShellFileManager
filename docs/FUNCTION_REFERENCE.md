# PowerShell File Manager V2.1 - Function Reference

## Quick Reference: New Functions

This document provides a quick reference for all new functions added in V2.1.

## Configuration Management (ConfigurationManager.psm1)

```powershell
Get-FileManagerConfig              # Get current configuration
Set-FileManagerConfig              # Update configuration settings
Reset-FileManagerConfig            # Reset configuration to defaults
```

## Result Models (ResultModels.psm1)

```powershell
New-DirectoryEntry                 # Create DirectoryEntry from FileSystemInfo
New-OperationRecord                # Create OperationRecord for tracking
```

**Classes Available**:

- `DirectoryEntry` - File/directory information
- `OperationRecord` - Operation tracking
- `SearchResult` - Search results with scoring
- `FileIntegrityRecord` - Integrity baselines
- `PluginInfo` - Plugin metadata
- `CacheEntry` - Cache management
- `PerformanceMetric` - Performance data

## Path Validation & Safety (PathValidation.psm1)

```powershell
Resolve-NormalizedPath            # Normalize and validate paths
Test-PathTraversal                # Detect path traversal attempts
Test-SafePath                     # Comprehensive path safety check
Convert-PathFormat                # Convert paths between OS formats
Test-ReparsePoint                 # Detect symlinks and junctions
Get-ReparsePointTarget            # Get symlink target path
```

## Recycle Bin Operations (RecycleBinOperations.psm1)

```powershell
Remove-ItemToRecycleBin           # Safe deletion via Recycle Bin
Get-RecycleBinItems               # List Recycle Bin contents
Restore-RecycleBinItem            # Restore deleted item
Clear-RecycleBin                  # Empty Recycle Bin
```

## File Integrity Monitoring (IntegrityMonitoring.psm1)

```powershell
Enable-IntegrityMonitoring        # Create integrity baseline
Test-FileIntegrity                # Verify files against baseline
Remove-FileSecurely               # DOD-compliant secure deletion
```

## Performance Monitoring (PerformanceMonitoring.psm1)

```powershell
Start-PerformanceTracking         # Begin operation tracking
Stop-PerformanceTracking          # End tracking and record metrics
Get-FileManagerMetrics            # Retrieve performance metrics
Get-OperationStatistics           # Get aggregated statistics
Clear-PerformanceMetrics          # Clear stored metrics
Export-PerformanceReport          # Export metrics to JSON/CSV
Show-PerformanceSummary           # Display formatted summary
```

## External Tool Integration (ExternalToolIntegration.psm1)

```powershell
Register-ExternalTool             # Register external tool
Invoke-ExternalTool               # Execute tool on files
Get-ExternalTool                  # List/get registered tools
Update-ExternalTool               # Modify tool configuration
Unregister-ExternalTool           # Remove tool from registry
```

## Health Monitoring & Diagnostics (HealthMonitoring.psm1)

```powershell
Get-FileManagerHealth             # Perform health check
Export-DiagnosticData             # Create diagnostic bundle
Test-StartupHealth                # Validate startup conditions
```

## Enhanced Logging (Logging.psm1)

```powershell
Write-Log                         # Simplified logging with correlation IDs
Initialize-FileManagerLogging     # Initialize logging system (existing)
Write-FileManagerLog              # Write detailed log entry (existing)
Get-FileManagerLogs               # Retrieve log entries (existing)
```

## Enhanced Batch Operations (BatchOperations.psm1)

```powershell
New-BatchOperationTemplate        # Create reusable template
Get-BatchOperationTemplate        # Retrieve saved template
Start-ConditionalBatchOperation   # Execute conditional batch operations
Start-BatchOperation              # Start batch operation (existing)
```

## Enhanced Security Operations (SecurityOperations.psm1)

```powershell
Protect-FileWithPassword          # AES-256 encryption
Unprotect-FileWithPassword        # AES decryption
Set-FileDigitalSignature          # Digitally sign file
Test-FileDigitalSignature         # Verify digital signature
Get-FileACL                       # Get file ACL (existing)
Set-FileACL                       # Set file ACL (existing)
Remove-SecureFile                 # Secure deletion (existing)
```

---

## Function Categories

### Security Functions (11 total)

- File encryption/decryption (2)
- Digital signatures (2)
- Integrity monitoring (3)
- ACL management (2)
- Secure deletion (2)

### Performance & Monitoring (8 total)

- Performance tracking (7)
- Health monitoring (3)
- Diagnostics (1)

### File Operations (9 total)

- Recycle Bin operations (4)
- Batch operations (3)
- Path validation (6)

### Configuration & Tools (8 total)

- Configuration management (3)
- External tools (5)
- Logging enhancements (1)

---

## Total Count: 45+ New Functions

**New Modules**: 8  
**Enhanced Modules**: 3  
**Total Modules**: 11

---

## Common Usage Patterns

### Secure File Handling

```powershell
# Encrypt → Process → Decrypt
Protect-FileWithPassword -FilePath "data.txt" -Password "pass"
# ... transfer or store ...
Unprotect-FileWithPassword -FilePath "data.txt.encrypted" -Password "pass"

# Sign → Verify
Set-FileDigitalSignature -FilePath "script.ps1" -Certificate $cert
Test-FileDigitalSignature -FilePath "script.ps1"
```

### Performance Tracking

```powershell
# Track → Execute → Stop → Analyze
$tracker = Start-PerformanceTracking -Operation "BatchCopy"
# ... perform operations ...
Stop-PerformanceTracking -Tracker $tracker -ItemsProcessed 1000
Show-PerformanceSummary
```

### Safe Operations

```powershell
# Validate → Execute → Verify
if (Test-SafePath -Path $userInput) {
    Remove-ItemToRecycleBin -Path $userInput
}
```

### Integrity Monitoring

```powershell
# Baseline → Monitor → Verify
Enable-IntegrityMonitoring -Path "C:\Critical" -Algorithm SHA256
# ... time passes ...
Test-FileIntegrity -Path "C:\Critical"
```

### Health Checks

```powershell
# Check → Diagnose → Export
$health = Get-FileManagerHealth
if ($health.OverallStatus -ne "Healthy") {
    Export-DiagnosticData -OutputPath "diagnostics.zip"
}
```

---

## Parameter Patterns

### Common Parameters

- `-Path` / `-FilePath` - File or directory path
- `-Password` - Encryption password
- `-Algorithm` - Hash algorithm (MD5, SHA1, SHA256, SHA512)
- `-Recurse` - Process subdirectories
- `-Force` - Bypass confirmations
- `-WhatIf` - Preview changes
- `-Confirm` - Request confirmation
- `-Verbose` - Detailed output

### Return Objects

Most functions return `PSCustomObject` with:

- `Success` (bool) - Operation success status
- `Error` (string) - Error message if failed
- Additional properties specific to the operation

---

## See Also

- **ADVANCED_FEATURES.md** - Detailed feature documentation
- **README.md** - General usage and examples
- **USER_GUIDE.md** - Comprehensive user guide
- **EXAMPLES.md** - Additional usage examples

---

**Version**: 2.1.0  
**Last Updated**: January 2025
