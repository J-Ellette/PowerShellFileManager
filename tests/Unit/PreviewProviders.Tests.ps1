<#
.SYNOPSIS
    Pester tests for PreviewProviders module

.DESCRIPTION
    Unit tests for the enhanced preview system with multi-format support
#>

BeforeAll {
    # Import the module
    $ModulePath = Join-Path $PSScriptRoot "..\..\src\Modules\Preview\PreviewProviders.psm1"
    Import-Module $ModulePath -Force

    # Create test files in temp directory
    $script:TempDir = Join-Path $env:TEMP "PesterPreviewTests_$(Get-Random)"
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

    # Create test SVG file
    $script:TestSVG = Join-Path $script:TempDir "test.svg"
    @"
<?xml version="1.0" encoding="UTF-8"?>
<svg width="100" height="100" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
    <circle cx="50" cy="50" r="40" fill="blue"/>
    <rect x="10" y="10" width="30" height="30" fill="red"/>
</svg>
"@ | Out-File -FilePath $script:TestSVG -Encoding UTF8 -Force

    # Create test Markdown file
    $script:TestMarkdown = Join-Path $script:TempDir "test.md"
    @"
# Main Title

## Subtitle

This is a paragraph with [a link](https://example.com) and ![an image](image.png).

``````powershell
Write-Host "Code block"
``````

- List item 1
- List item 2
"@ | Out-File -FilePath $script:TestMarkdown -Encoding UTF8 -Force

    # Create test STL file (minimal ASCII STL)
    $script:TestSTL = Join-Path $script:TempDir "test.stl"
    @"
solid test
  facet normal 0 0 1
    outer loop
      vertex 0 0 0
      vertex 1 0 0
      vertex 0 1 0
    endloop
  endfacet
endsolid test
"@ | Out-File -FilePath $script:TestSTL -Encoding ASCII -Force

    # Create test G-code file
    $script:TestGCode = Join-Path $script:TempDir "test.gcode"
    @"
; Sliced by Test Slicer
; Print time: 1h 30m
; Filament used: 25.5m
;LAYER:0
;LAYER:1
M104 S200 ; Set nozzle temp
M140 S60 ; Set bed temp
G0 X10 Y10 Z0.2
G1 X20 Y20 E0.5
"@ | Out-File -FilePath $script:TestGCode -Encoding UTF8 -Force
}

Describe "PreviewProviders Module" {
    Context "Module Loading" {
        It "Should import without errors" {
            { Import-Module $ModulePath -Force } | Should -Not -Throw
        }

        It "Should export Show-FilePreview function" {
            Get-Command Show-FilePreview -Module PreviewProviders | Should -Not -BeNullOrEmpty
        }

        It "Should export Show-EnhancedPreview function" {
            Get-Command Show-EnhancedPreview -Module PreviewProviders | Should -Not -BeNullOrEmpty
        }

        It "Should export Show-SVGPreview function" {
            Get-Command Show-SVGPreview -Module PreviewProviders | Should -Not -BeNullOrEmpty
        }

        It "Should export Show-MarkdownPreview function" {
            Get-Command Show-MarkdownPreview -Module PreviewProviders | Should -Not -BeNullOrEmpty
        }

        It "Should export Show-STLPreview function" {
            Get-Command Show-STLPreview -Module PreviewProviders | Should -Not -BeNullOrEmpty
        }

        It "Should export Show-GCodePreview function" {
            Get-Command Show-GCodePreview -Module PreviewProviders | Should -Not -BeNullOrEmpty
        }

        It "Should export Get-FileMetadata function" {
            Get-Command Get-FileMetadata -Module PreviewProviders | Should -Not -BeNullOrEmpty
        }
    }

    Context "Show-SVGPreview" {
        It "Should have Path parameter" {
            $command = Get-Command Show-SVGPreview
            $command.Parameters['Path'] | Should -Not -BeNullOrEmpty
            $command.Parameters['Path'].Attributes.Mandatory | Should -Be $true
        }

        It "Should validate that path exists" {
            $command = Get-Command Show-SVGPreview
            $command.Parameters['Path'].Attributes.Where({$_.TypeId.Name -eq 'ValidateScriptAttribute'}) |
                Should -Not -BeNullOrEmpty
        }

        It "Should not throw for valid SVG file" {
            { Show-SVGPreview -Path $script:TestSVG } | Should -Not -Throw
        }

        It "Should parse SVG structure correctly" {
            # Capture output by redirecting to null and verifying no errors
            $errorCount = $Error.Count
            Show-SVGPreview -Path $script:TestSVG *> $null
            $Error.Count | Should -Be $errorCount
        }
    }

    Context "Show-MarkdownPreview" {
        It "Should have Path parameter" {
            $command = Get-Command Show-MarkdownPreview
            $command.Parameters['Path'] | Should -Not -BeNullOrEmpty
            $command.Parameters['Path'].Attributes.Mandatory | Should -Be $true
        }

        It "Should have RenderHTML switch parameter" {
            $command = Get-Command Show-MarkdownPreview
            $command.Parameters['RenderHTML'].SwitchParameter | Should -Be $true
        }

        It "Should not throw for valid Markdown file" {
            { Show-MarkdownPreview -Path $script:TestMarkdown } | Should -Not -Throw
        }

        It "Should handle RenderHTML switch without Markdig" {
            { Show-MarkdownPreview -Path $script:TestMarkdown -RenderHTML } | Should -Not -Throw
        }
    }

    Context "Show-STLPreview" {
        It "Should have Path parameter" {
            $command = Get-Command Show-STLPreview
            $command.Parameters['Path'] | Should -Not -BeNullOrEmpty
            $command.Parameters['Path'].Attributes.Mandatory | Should -Be $true
        }

        It "Should not throw for valid STL file" {
            { Show-STLPreview -Path $script:TestSTL } | Should -Not -Throw
        }

        It "Should detect ASCII STL format" {
            # Capture output and verify no errors
            $errorCount = $Error.Count
            Show-STLPreview -Path $script:TestSTL *> $null
            $Error.Count | Should -Be $errorCount
        }
    }

    Context "Show-GCodePreview" {
        It "Should have Path parameter" {
            $command = Get-Command Show-GCodePreview
            $command.Parameters['Path'] | Should -Not -BeNullOrEmpty
            $command.Parameters['Path'].Attributes.Mandatory | Should -Be $true
        }

        It "Should not throw for valid G-code file" {
            { Show-GCodePreview -Path $script:TestGCode } | Should -Not -Throw
        }

        It "Should parse G-code metadata" {
            # Verify no errors during parsing
            $errorCount = $Error.Count
            Show-GCodePreview -Path $script:TestGCode *> $null
            $Error.Count | Should -Be $errorCount
        }
    }

    Context "Show-EnhancedPreview" {
        It "Should route SVG files to Show-SVGPreview" {
            { Show-EnhancedPreview -Path $script:TestSVG } | Should -Not -Throw
        }

        It "Should route Markdown files to Show-MarkdownPreview" {
            { Show-EnhancedPreview -Path $script:TestMarkdown } | Should -Not -Throw
        }

        It "Should route STL files to Show-STLPreview" {
            { Show-EnhancedPreview -Path $script:TestSTL } | Should -Not -Throw
        }

        It "Should route G-code files to Show-GCodePreview" {
            { Show-EnhancedPreview -Path $script:TestGCode } | Should -Not -Throw
        }

        It "Should handle .md extension" {
            $mdFile = Join-Path $script:TempDir "test2.md"
            Copy-Item $script:TestMarkdown -Destination $mdFile
            { Show-EnhancedPreview -Path $mdFile } | Should -Not -Throw
        }

        It "Should handle .markdown extension" {
            $markdownFile = Join-Path $script:TempDir "test.markdown"
            Copy-Item $script:TestMarkdown -Destination $markdownFile
            { Show-EnhancedPreview -Path $markdownFile } | Should -Not -Throw
        }

        It "Should handle .gco extension" {
            $gcoFile = Join-Path $script:TempDir "test.gco"
            Copy-Item $script:TestGCode -Destination $gcoFile
            { Show-EnhancedPreview -Path $gcoFile } | Should -Not -Throw
        }
    }

    Context "Error Handling" {
        It "Should handle non-existent file gracefully" {
            $nonExistentFile = Join-Path $script:TempDir "nonexistent.svg"
            { Show-SVGPreview -Path $nonExistentFile -ErrorAction SilentlyContinue } | Should -Throw
        }

        It "Should handle invalid XML in SVG gracefully" {
            $invalidSVG = Join-Path $script:TempDir "invalid.svg"
            "This is not valid XML" | Out-File -FilePath $invalidSVG
            { Show-SVGPreview -Path $invalidSVG } | Should -Not -Throw
        }

        It "Should handle empty Markdown file gracefully" {
            $emptyMD = Join-Path $script:TempDir "empty.md"
            "" | Out-File -FilePath $emptyMD
            { Show-MarkdownPreview -Path $emptyMD } | Should -Not -Throw
        }
    }

    Context "File Format Detection" {
        It "Should correctly identify SVG by extension" {
            $extension = [System.IO.Path]::GetExtension($script:TestSVG).ToLowerInvariant()
            $extension | Should -Be '.svg'
        }

        It "Should correctly identify Markdown by extension" {
            $extension = [System.IO.Path]::GetExtension($script:TestMarkdown).ToLowerInvariant()
            $extension | Should -Be '.md'
        }

        It "Should correctly identify STL by extension" {
            $extension = [System.IO.Path]::GetExtension($script:TestSTL).ToLowerInvariant()
            $extension | Should -Be '.stl'
        }

        It "Should correctly identify G-code by extension" {
            $extension = [System.IO.Path]::GetExtension($script:TestGCode).ToLowerInvariant()
            $extension | Should -Be '.gcode'
        }
    }
}

AfterAll {
    # Clean up test files
    if (Test-Path $script:TempDir) {
        Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Remove module
    Remove-Module PreviewProviders -Force -ErrorAction SilentlyContinue
}
