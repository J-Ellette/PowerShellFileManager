#Requires -Version 7.0

# Security Operations Module - ACL management and secure delete

function Get-FileACL {
    <#
    .SYNOPSIS
        Gets file ACL (Access Control List)
    .DESCRIPTION
        Displays file permissions and security descriptors
    .PARAMETER Path
        File or folder path
    .EXAMPLE
        Get-FileACL -Path C:\file.txt
        Shows file permissions
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        Write-Error "Path not found: $Path"
        return
    }
    
    Write-Host "`nACL for: $Path" -ForegroundColor Cyan
    
    $acl = Get-Acl -Path $Path
    
    Write-Host "`nOwner: $($acl.Owner)" -ForegroundColor Green
    Write-Host "Group: $($acl.Group)" -ForegroundColor Green
    
    Write-Host "`nAccess Rules:" -ForegroundColor Yellow
    foreach ($rule in $acl.Access) {
        $color = if ($rule.AccessControlType -eq 'Allow') { 'Green' } else { 'Red' }
        Write-Host "  [$($rule.AccessControlType)] $($rule.IdentityReference) - $($rule.FileSystemRights)" -ForegroundColor $color
    }
    
    return $acl
}

function Set-FileACL {
    <#
    .SYNOPSIS
        Sets file ACL permissions
    .DESCRIPTION
        Modifies file permissions and security descriptors
    .PARAMETER Path
        File or folder path
    .PARAMETER Principal
        User or group to grant permissions
    .PARAMETER Rights
        File system rights to grant
    .PARAMETER Type
        Allow or Deny
    .EXAMPLE
        Set-FileACL -Path C:\file.txt -Principal "DOMAIN\User" -Rights Read -Type Allow
        Grants read permission
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [string]$Principal,
        
        [Parameter(Mandatory=$true)]
        [System.Security.AccessControl.FileSystemRights]$Rights,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Allow', 'Deny')]
        [string]$Type = 'Allow'
    )
    
    if (-not (Test-Path $Path)) {
        Write-Error "Path not found: $Path"
        return
    }
    
    Write-Host "Setting ACL for: $Path" -ForegroundColor Cyan
    
    try {
        $acl = Get-Acl -Path $Path
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $Principal,
            $Rights,
            $Type
        )
        
        $acl.SetAccessRule($accessRule)
        Set-Acl -Path $Path -AclObject $acl
        
        Write-Host "ACL updated successfully" -ForegroundColor Green
        Write-Host "  Principal: $Principal" -ForegroundColor Gray
        Write-Host "  Rights: $Rights" -ForegroundColor Gray
        Write-Host "  Type: $Type" -ForegroundColor Gray
    } catch {
        Write-Error "Failed to set ACL: $_"
    }
}

function Remove-SecureFile {
    <#
    .SYNOPSIS
        Securely wipes files with multi-pass delete
    .DESCRIPTION
        Overwrites file content before deletion for security
    .PARAMETER Path
        File path to securely delete
    .PARAMETER Passes
        Number of overwrite passes (default: 3)
    .EXAMPLE
        Remove-SecureFile -Path sensitive.txt -Passes 7
        Securely deletes file with 7 passes
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$false)]
        [int]$Passes = 3
    )
    
    if (-not (Test-Path $Path)) {
        Write-Error "File not found: $Path"
        return
    }
    
    $file = Get-Item $Path
    
    if ($file.PSIsContainer) {
        Write-Error "Cannot securely delete directories"
        return
    }
    
    if ($PSCmdlet.ShouldProcess($Path, "Securely delete with $Passes passes")) {
        Write-Host "Securely deleting: $($file.Name)" -ForegroundColor Yellow
        Write-Host "Passes: $Passes" -ForegroundColor Gray
        
        try {
            $fileSize = $file.Length
            
            for ($pass = 1; $pass -le $Passes; $pass++) {
                Write-Host "  Pass $pass/$Passes..." -ForegroundColor Cyan
                
                # Overwrite with random data
                $randomData = New-Object byte[] $fileSize
                $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
                $rng.GetBytes($randomData)
                
                [System.IO.File]::WriteAllBytes($Path, $randomData)
            }
            
            # Final overwrite with zeros
            Write-Host "  Final pass (zeros)..." -ForegroundColor Cyan
            $zeroData = New-Object byte[] $fileSize
            [System.IO.File]::WriteAllBytes($Path, $zeroData)
            
            # Delete the file
            Remove-Item -Path $Path -Force
            
            Write-Host "File securely deleted" -ForegroundColor Green
        } catch {
            Write-Error "Failed to securely delete file: $_"
        }
    }
}

function Protect-FileWithPassword {
    <#
    .SYNOPSIS
        Encrypts a file with AES encryption
    .DESCRIPTION
        Implements AES encryption for file protection with password-based key derivation
    .PARAMETER FilePath
        Path to file to encrypt
    .PARAMETER Password
        Password for encryption (converted to secure key)
    .PARAMETER OutputPath
        Optional output path for encrypted file
    .EXAMPLE
        $securePassword = ConvertTo-SecureString "MyPassword123" -AsPlainText -Force
        Protect-FileWithPassword -FilePath "C:\secret.txt" -Password $securePassword
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path $_})]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [SecureString]$Password,
        
        [Parameter(Mandatory=$false)]
        [string]$OutputPath
    )
    )
    
    if (-not $OutputPath) {
        $OutputPath = "$FilePath.encrypted"
    }
    
    if ($PSCmdlet.ShouldProcess($FilePath, "Encrypt file")) {
        try {
            # Read file content
            $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
            
            # Create AES encryption
            $aes = [System.Security.Cryptography.Aes]::Create()
            $aes.KeySize = 256
            $aes.BlockSize = 128
            $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
            # Derive key from password using PBKDF2
            $salt = New-Object byte[] 32
            $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
            $rng.GetBytes($salt)

            # Convert SecureString to plain text for cryptographic operations
            $passwordPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
            try {
                $passwordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPtr)
                $pbkdf2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($passwordPlain, $salt, 100000, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
                $aes.Key = $pbkdf2.GetBytes(32)
            }
            finally {
                # Clear password from memory immediately
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPtr)
            }
            $aes.GenerateIV()
            
            # Encrypt
            $encryptor = $aes.CreateEncryptor()
            $encryptedBytes = $encryptor.TransformFinalBlock($fileBytes, 0, $fileBytes.Length)
            
            # Write encrypted file with salt and IV prepended
            $outputStream = [System.IO.File]::Create($OutputPath)
            $outputStream.Write($salt, 0, $salt.Length)
            $outputStream.Write($aes.IV, 0, $aes.IV.Length)
            $outputStream.Write($encryptedBytes, 0, $encryptedBytes.Length)
            $outputStream.Close()
            
            # Cleanup
            $aes.Dispose()
            $pbkdf2.Dispose()
            
            Write-Host "File encrypted successfully: $OutputPath" -ForegroundColor Green
            Write-Host "  Original: $FilePath" -ForegroundColor Gray
            Write-Host "  Encrypted: $OutputPath" -ForegroundColor Gray
            Write-Host "  Algorithm: AES-256-CBC" -ForegroundColor Gray
            
            return [PSCustomObject]@{
                Success = $true
                OriginalPath = $FilePath
                EncryptedPath = $OutputPath
                Algorithm = "AES-256-CBC"
            }
        }
        catch {
            Write-Error "Failed to encrypt file: $_"
            return [PSCustomObject]@{
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }
}

function Unprotect-FileWithPassword {
    <#
    .SYNOPSIS
        Decrypts an AES-encrypted file
    .DESCRIPTION
        Decrypts a file that was encrypted with AES encryption using password-based key derivation
    .PARAMETER FilePath
        Path to encrypted file
    .PARAMETER Password
        Password used for encryption (as SecureString)
    .PARAMETER OutputPath
        Optional output path for decrypted file
    .EXAMPLE
        $securePassword = ConvertTo-SecureString "MyPassword123" -AsPlainText -Force
        Unprotect-FileWithPassword -FilePath "C:\secret.txt.encrypted" -Password $securePassword
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path $_})]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [SecureString]$Password,
        
        [Parameter(Mandatory=$false)]
        [string]$OutputPath
    )
    
    if (-not $OutputPath) {
        $OutputPath = $FilePath -replace '\.encrypted$', '.decrypted'
    }
    
    if ($PSCmdlet.ShouldProcess($FilePath, "Decrypt file")) {
        try {
            # Read encrypted file
            $fileStream = [System.IO.File]::OpenRead($FilePath)
            
            # Read salt (32 bytes)
            $salt = New-Object byte[] 32
            $fileStream.Read($salt, 0, 32) | Out-Null
            
            # Read IV (16 bytes)
            $iv = New-Object byte[] 16
            $fileStream.Read($iv, 0, 16) | Out-Null
            
            # Read encrypted data
            $encryptedBytes = New-Object byte[] ($fileStream.Length - 48)
            $fileStream.Read($encryptedBytes, 0, $encryptedBytes.Length) | Out-Null
            $fileStream.Close()
            # Create AES encryption
            $aes = [System.Security.Cryptography.Aes]::Create()
            $aes.KeySize = 256
            $aes.BlockSize = 128
            $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
            $aes.IV = $iv
            
            # Derive key from password using PBKDF2
            # Convert SecureString to plain text for cryptographic operations
            $passwordPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
            try {
                $passwordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPtr)
                $pbkdf2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($passwordPlain, $salt, 100000, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
                $aes.Key = $pbkdf2.GetBytes(32)
            }
            finally {
                # Clear password from memory immediately
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPtr)
            }
            
            # Decrypt
            $decryptor = $aes.CreateDecryptor()
            $decryptedBytes = $decryptor.TransformFinalBlock($encryptedBytes, 0, $encryptedBytes.Length)
            
            # Write decrypted file
            [System.IO.File]::WriteAllBytes($OutputPath, $decryptedBytes)
            
            # Cleanup
            $aes.Dispose()
            $pbkdf2.Dispose()
            
            Write-Host "File decrypted successfully: $OutputPath" -ForegroundColor Green
            
            return [PSCustomObject]@{
                Success = $true
                EncryptedPath = $FilePath
                DecryptedPath = $OutputPath
            }
        }
        catch {
            Write-Error "Failed to decrypt file (wrong password or corrupted file): $_"
            return [PSCustomObject]@{
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }
}

function Set-FileDigitalSignature {
    <#
    .SYNOPSIS
        Signs a file digitally using a certificate
    .DESCRIPTION
        Creates a digital signature for a file using X.509 certificate
    .PARAMETER FilePath
        Path to file to sign
    .PARAMETER Certificate
        Certificate object or thumbprint
    .EXAMPLE
        $cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object {$_.Subject -like "*Code*"}
        Set-FileDigitalSignature -FilePath "C:\file.ps1" -Certificate $cert
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path $_})]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        $Certificate
    )
    
    if ($PSCmdlet.ShouldProcess($FilePath, "Sign file")) {
        try {
            # Get certificate if thumbprint provided
            if ($Certificate -is [string]) {
                $cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object {$_.Thumbprint -eq $Certificate}
                if (-not $cert) {
                    Write-Error "Certificate with thumbprint $Certificate not found"
                    return
                }
            } else {
                $cert = $Certificate
            }
            
            # For PowerShell scripts, use Set-AuthenticodeSignature
            if ($FilePath -match '\.(ps1|psm1|psd1)$') {
                $result = Set-AuthenticodeSignature -FilePath $FilePath -Certificate $cert
                
                if ($result.Status -eq 'Valid') {
                    Write-Host "File signed successfully" -ForegroundColor Green
                    Write-Host "  File: $FilePath" -ForegroundColor Gray
                    Write-Host "  Certificate: $($cert.Subject)" -ForegroundColor Gray
                    Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
                    
                    return [PSCustomObject]@{
                        Success = $true
                        FilePath = $FilePath
                        Status = $result.Status
                        Certificate = $cert.Subject
                    }
                } else {
                    Write-Error "Signing failed: $($result.StatusMessage)"
                }
            }
            else {
                # For other files, create detached signature
                $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
                
                # Create CMS message
                $contentInfo = New-Object System.Security.Cryptography.Pkcs.ContentInfo(,$fileBytes)
                $signedCms = New-Object System.Security.Cryptography.Pkcs.SignedCms($contentInfo, $true)
                $signer = New-Object System.Security.Cryptography.Pkcs.CmsSigner($cert)
                
                $signedCms.ComputeSignature($signer)
                $signature = $signedCms.Encode()
                
                # Save signature to file
                $signaturePath = "$FilePath.sig"
                [System.IO.File]::WriteAllBytes($signaturePath, $signature)
                
                Write-Host "Signature created successfully" -ForegroundColor Green
                Write-Host "  File: $FilePath" -ForegroundColor Gray
                Write-Host "  Signature: $signaturePath" -ForegroundColor Gray
                
                return [PSCustomObject]@{
                    Success = $true
                    FilePath = $FilePath
                    SignaturePath = $signaturePath
                    Certificate = $cert.Subject
                }
            }
        }
        catch {
            Write-Error "Failed to sign file: $_"
            return [PSCustomObject]@{
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }
}

function Test-FileDigitalSignature {
    <#
    .SYNOPSIS
        Verifies a file's digital signature
    .DESCRIPTION
        Validates the digital signature of a signed file
    .PARAMETER FilePath
        Path to signed file
    .EXAMPLE
        Test-FileDigitalSignature -FilePath "C:\file.ps1"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path $_})]
        [string]$FilePath
    )
    
    try {
        if ($FilePath -match '\.(ps1|psm1|psd1)$') {
            # For PowerShell scripts
            $signature = Get-AuthenticodeSignature -FilePath $FilePath
            
            $isValid = $signature.Status -eq 'Valid'
            $statusColor = if ($isValid) { 'Green' } else { 'Red' }
            
            Write-Host "Signature Status: $($signature.Status)" -ForegroundColor $statusColor
            if ($signature.SignerCertificate) {
                Write-Host "  Signer: $($signature.SignerCertificate.Subject)" -ForegroundColor Gray
                Write-Host "  Valid From: $($signature.SignerCertificate.NotBefore)" -ForegroundColor Gray
                Write-Host "  Valid Until: $($signature.SignerCertificate.NotAfter)" -ForegroundColor Gray
            }
            
            return [PSCustomObject]@{
                IsValid = $isValid
                Status = $signature.Status
                Signer = $signature.SignerCertificate.Subject
                TimeStamp = $signature.TimeStamperCertificate
            }
        }
        else {
            # For other files with detached signature
            $signaturePath = "$FilePath.sig"
            if (-not (Test-Path $signaturePath)) {
                Write-Warning "Signature file not found: $signaturePath"
                return [PSCustomObject]@{
                    IsValid = $false
                    Status = "NoSignature"
                }
            }
            
            $signatureBytes = [System.IO.File]::ReadAllBytes($signaturePath)
            
            $signedCms = New-Object System.Security.Cryptography.Pkcs.SignedCms
            $signedCms.Decode($signatureBytes)
            
            try {
                $signedCms.CheckSignature($true)
                Write-Host "Signature is valid" -ForegroundColor Green
                
                return [PSCustomObject]@{
                    IsValid = $true
                    Status = "Valid"
                    Signer = $signedCms.SignerInfos[0].Certificate.Subject
                }
            }
            catch {
                Write-Host "Signature is invalid" -ForegroundColor Red
                return [PSCustomObject]@{
                    IsValid = $false
                    Status = "Invalid"
                    Error = $_.Exception.Message
                }
            }
        }
    }
    catch {
        Write-Error "Failed to verify signature: $_"
        return [PSCustomObject]@{
            IsValid = $false
            Status = "Error"
            Error = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function Get-FileACL, Set-FileACL, Remove-SecureFile, Protect-FileWithPassword, Unprotect-FileWithPassword, Set-FileDigitalSignature, Test-FileDigitalSignature
