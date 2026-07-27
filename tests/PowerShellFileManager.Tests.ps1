#Requires -Version 7.0

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '',
    Justification = 'Test fixtures require deterministic plaintext passwords')]
param()

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:ManifestPath = Join-Path $RepoRoot 'PowerShellFileManager.psd1'

    Import-Module $ManifestPath -Force -WarningVariable script:ImportWarnings
    $script:Manifest = Import-PowerShellDataFile $ManifestPath
    $script:Exported = (Get-Command -Module PowerShellFileManager).Name
}

AfterAll {
    Remove-Module PowerShellFileManager -ErrorAction SilentlyContinue
}

Describe 'Module manifest' {
    It 'is a valid manifest' {
        { Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop } | Should -Not -Throw
    }

    It 'does not use the placeholder GUID' {
        $Manifest.GUID | Should -Not -Be 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    }
}

Describe 'Source files' {
    It 'parse without syntax errors' {
        $files = Get-ChildItem -Path $RepoRoot -Include *.ps1, *.psm1, *.psd1 -Recurse |
            Where-Object FullName -NotMatch '[\\/]\.git[\\/]'
        $bad = foreach ($f in $files) {
            $tokens = $null; $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors) | Out-Null
            if ($errors) { "$($f.Name): $($errors[0].Message)" }
        }
        $bad | Should -BeNullOrEmpty
    }
}

Describe 'Module import and exports' {
    It 'imports without warnings' {
        $ImportWarnings | Should -BeNullOrEmpty
    }

    It 'actually exports every function declared in the manifest' {
        $missing = $Manifest.FunctionsToExport | Where-Object { $_ -notin $Exported }
        $missing | Should -BeNullOrEmpty
    }

    It 'declares every exported function in the manifest' {
        $extra = $Exported | Where-Object { $_ -notin $Manifest.FunctionsToExport }
        $extra | Should -BeNullOrEmpty
    }

    It 'does not shadow built-in cmdlets' {
        Import-Module Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility,
            Microsoft.PowerShell.Archive, Microsoft.PowerShell.Security -ErrorAction SilentlyContinue
        $builtins = (Get-Command -Module Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility,
            Microsoft.PowerShell.Archive, Microsoft.PowerShell.Security -ErrorAction SilentlyContinue).Name
        $collisions = $Exported | Where-Object { $_ -in $builtins }
        $collisions | Should -BeNullOrEmpty
    }

    It 'keeps private helpers private' {
        $Exported | Should -Not -Contain 'Format-FileSize'
        $Exported | Should -Not -Contain 'Read-StreamBytes'
    }
}

Describe 'Protect/Unprotect-FileWithPassword' {
    BeforeAll {
        $script:Password = ConvertTo-SecureString 'test-password' -AsPlainText -Force
    }

    It 'round-trips an encrypted file' {
        $src = Join-Path $TestDrive 'plain.txt'
        Set-Content -Path $src -Value 'secret payload'

        $enc = Protect-FileWithPassword -FilePath $src -Password $Password
        $enc.Success | Should -BeTrue
        Test-Path "$src.encrypted" | Should -BeTrue

        $dec = Unprotect-FileWithPassword -FilePath "$src.encrypted" -Password $Password
        $dec.Success | Should -BeTrue
        Get-Content "$src.decrypted" | Should -Be 'secret payload'
    }

    It 'encrypted output differs from the plaintext' {
        $src = Join-Path $TestDrive 'plain-b.txt'
        Set-Content -Path $src -Value 'secret payload'
        Protect-FileWithPassword -FilePath $src -Password $Password | Out-Null
        $cipherBytes = [System.IO.File]::ReadAllBytes("$src.encrypted")
        $plainBytes = [System.IO.File]::ReadAllBytes($src)
        # 32-byte salt + 16-byte IV prepended, then ciphertext
        $cipherBytes.Length | Should -BeGreaterThan ($plainBytes.Length + 47)
    }

    It 'fails with the wrong password' {
        $src = Join-Path $TestDrive 'plain2.txt'
        Set-Content -Path $src -Value 'secret payload'
        Protect-FileWithPassword -FilePath $src -Password $Password | Out-Null

        $wrong = ConvertTo-SecureString 'not-the-password' -AsPlainText -Force
        $result = Unprotect-FileWithPassword -FilePath "$src.encrypted" -Password $wrong -ErrorAction SilentlyContinue
        $result.Success | Should -BeFalse
    }
}

Describe 'Archive operations' {
    It 'creates and extracts a ZIP archive' {
        $src = Join-Path $TestDrive 'archive-me.txt'
        Set-Content -Path $src -Value 'zipdata'
        $zip = Join-Path $TestDrive 'roundtrip.zip'

        New-Archive -Path $src -Destination $zip -Format ZIP
        Test-Path $zip | Should -BeTrue

        $out = Join-Path $TestDrive 'extracted'
        Expand-ArchiveFile -Path $zip -Destination $out
        Get-Content (Join-Path $out 'archive-me.txt') | Should -Be 'zipdata'
    }
}

Describe 'GUI collection safety' {
    It 'never binds a raw pipeline result to ItemsSource' {
        # A single-item pipeline unrolls to a scalar PSCustomObject, which WPF
        # rejects ("Cannot convert ... to System.Collections.IEnumerable").
        # Every ItemsSource assignment must be an @()-wrapped expression or one
        # of the variables that are @()-built upstream ($items, $filtered).
        $gui = Join-Path $RepoRoot 'src/Scripts/Start-FileManager.ps1'
        $offenders = Select-String -Path $gui -Pattern 'ItemsSource\s*=' | Where-Object {
            $_.Line -notmatch 'ItemsSource\s*=\s*@\(' -and
            $_.Line -notmatch 'ItemsSource\s*=\s*\$(items|filtered|script:AllItems)\s*$'
        }
        $offenders | ForEach-Object { "$($_.LineNumber): $($_.Line.Trim())" } | Should -BeNullOrEmpty
    }
}

Describe 'Sync-Directories' {
    It 'exposes the documented -Mode parameter' {
        (Get-Command Sync-Directories).Parameters.Keys | Should -Contain 'Mode'
    }

    It 'copies new files' {
        $srcDir = Join-Path $TestDrive 'sync-src'
        $dstDir = Join-Path $TestDrive 'sync-dst'
        New-Item -ItemType Directory -Path $srcDir | Out-Null
        Set-Content -Path (Join-Path $srcDir 'f.txt') -Value 'sync'

        Sync-Directories -Source $srcDir -Destination $dstDir -Mode Update
        Get-Content (Join-Path $dstDir 'f.txt') | Should -Be 'sync'
    }
}
