#Requires -Version 7.0

<#
.SYNOPSIS
    Template Manager - File template creation (New+ integration)
    PowerToys Integration

.DESCRIPTION
    Provides template-based file creation functionality.
    Allows creating files from predefined templates with variable substitution.

.NOTES
    Author: PowerShell File Manager V2.0
    Version: 1.0.0
#>

$script:BuiltInTemplates = @{
    'PowerShellScript' = @{
        Extension = '.ps1'
        Content = @'
#Requires -Version 7.0

<#
.SYNOPSIS
    {{DESCRIPTION}}

.DESCRIPTION
    Detailed description

.EXAMPLE
    .\{{FILENAME}}
#>

[CmdletBinding()]
param()

# Script implementation
Write-Host "Hello from {{FILENAME}}!"
'@
    }
    'PowerShellModule' = @{
        Extension = '.psm1'
        Content = @'
#Requires -Version 7.0

<#
.SYNOPSIS
    {{DESCRIPTION}}
#>

function Get-Example {
    [CmdletBinding()]
    param()
    
    Write-Output "Example function"
}

Export-ModuleMember -Function Get-Example
'@
    }
    'Markdown' = @{
        Extension = '.md'
        Content = @'
# {{TITLE}}

## Overview

{{DESCRIPTION}}

## Usage

### Example

```powershell
# Example code here
```

## Notes

Created: {{DATE}}
'@
    }
    'JsonConfig' = @{
        Extension = '.json'
        Content = @'
{
  "name": "{{NAME}}",
  "version": "1.0.0",
  "description": "{{DESCRIPTION}}",
  "createdDate": "{{DATE}}"
}
'@
    }
    'HtmlPage' = @{
        Extension = '.html'
        Content = @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{TITLE}}</title>
</head>
<body>
    <h1>{{TITLE}}</h1>
    <p>{{DESCRIPTION}}</p>
</body>
</html>
'@
    }
}

function Get-FileTemplate {
    <#
    .SYNOPSIS
        Get available file templates
    
    .DESCRIPTION
        Returns list of available file templates
    
    .PARAMETER Name
        Specific template name
    
    .EXAMPLE
        Get-FileTemplate
        List all available templates
    #>
    [CmdletBinding()]
    param(
        [string]$Name
    )
    
    if ($Name) {
        if ($script:BuiltInTemplates.ContainsKey($Name)) {
            $template = $script:BuiltInTemplates[$Name]
            [PSCustomObject]@{
                Name = $Name
                Extension = $template.Extension
                HasVariables = $template.Content -match '\{\{.+?\}\}'
            }
        } else {
            Write-Error "Template not found: $Name"
        }
    } else {
        $script:BuiltInTemplates.Keys | ForEach-Object {
            $template = $script:BuiltInTemplates[$_]
            [PSCustomObject]@{
                Name = $_
                Extension = $template.Extension
                Description = "Create $_ file"
            }
        }
    }
}

function New-FileFromTemplate {
    <#
    .SYNOPSIS
        Create a new file from a template
    
    .DESCRIPTION
        Creates a new file based on a template with variable substitution
    
    .PARAMETER TemplateName
        Name of the template to use
    
    .PARAMETER FileName
        Name for the new file (without extension)
    
    .PARAMETER Path
        Directory path where file should be created
    
    .PARAMETER Variables
        Hashtable of variables to substitute in template
    
    .EXAMPLE
        New-FileFromTemplate -TemplateName PowerShellScript -FileName "MyScript" -Path "C:\Scripts"
        Create a new PowerShell script from template
    
    .EXAMPLE
        New-FileFromTemplate -TemplateName Markdown -FileName "README" -Variables @{TITLE="My Project"; DESCRIPTION="A cool project"}
        Create markdown file with custom variables
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('PowerShellScript', 'PowerShellModule', 'Markdown', 'JsonConfig', 'HtmlPage')]
        [string]$TemplateName,
        
        [Parameter(Mandatory=$true)]
        [string]$FileName,
        
        [string]$Path = $pwd,
        
        [hashtable]$Variables = @{}
    )
    
    if (-not $script:BuiltInTemplates.ContainsKey($TemplateName)) {
        Write-Error "Template not found: $TemplateName"
        return
    }
    
    $template = $script:BuiltInTemplates[$TemplateName]
    
    # Build full filename
    $fullFileName = if ($FileName -like "*$($template.Extension)") {
        $FileName
    } else {
        "$FileName$($template.Extension)"
    }
    
    $fullPath = Join-Path $Path $fullFileName
    
    # Check if file exists
    if (Test-Path $fullPath) {
        Write-Error "File already exists: $fullPath"
        return
    }
    
    # Prepare default variables
    $defaultVars = @{
        'FILENAME' = $FileName
        'DATE' = Get-Date -Format "yyyy-MM-dd"
        'TIME' = Get-Date -Format "HH:mm:ss"
        'AUTHOR' = $env:USERNAME
        'TITLE' = $FileName
        'NAME' = $FileName
        'DESCRIPTION' = "Description for $FileName"
    }
    
    # Merge with provided variables (provided variables take precedence)
    foreach ($key in $Variables.Keys) {
        $defaultVars[$key] = $Variables[$key]
    }
    
    # Substitute variables in template
    $content = $template.Content
    foreach ($key in $defaultVars.Keys) {
        $content = $content -replace "\{\{$key\}\}", $defaultVars[$key]
    }
    
    if ($PSCmdlet.ShouldProcess($fullPath, "Create file from template")) {
        try {
            $content | Out-File -FilePath $fullPath -Encoding UTF8 -ErrorAction Stop
            Write-Host "Created file from template: $fullPath" -ForegroundColor Green
            
            [PSCustomObject]@{
                TemplateName = $TemplateName
                FileName = $fullFileName
                Path = $fullPath
                Status = 'Success'
            }
        } catch {
            Write-Error "Failed to create file: $_"
        }
    }
}

function Show-TemplateMenu {
    <#
    .SYNOPSIS
        Display interactive template selection menu
    
    .DESCRIPTION
        Shows menu to select template and create new file
    
    .EXAMPLE
        Show-TemplateMenu
        Launch template selector
    #>
    [CmdletBinding()]
    param()
    
    Write-Host "`nFile Template Creator" -ForegroundColor Cyan
    Write-Host "=" * 50
    
    $templates = Get-FileTemplate
    
    Write-Host "`nAvailable Templates:" -ForegroundColor Yellow
    $index = 1
    foreach ($template in $templates) {
        Write-Host "$index. $($template.Name) ($($template.Extension))"
        $index++
    }
    Write-Host "Q. Quit"
    
    $choice = Read-Host "`nSelect template (1-$($templates.Count))"
    
    if ($choice -match '^\d+$' -and [int]$choice -le $templates.Count) {
        $selectedTemplate = $templates[[int]$choice - 1]
        
        $fileName = Read-Host "Enter file name (without extension)"
        $path = Read-Host "Enter path (press Enter for current directory)"
        
        if ([string]::IsNullOrWhiteSpace($path)) {
            $path = Get-Location
        }
        
        $params = @{
            TemplateName = $selectedTemplate.Name
            FileName = $fileName
            Path = $path
        }
        
        # Prompt for common variables
        $title = Read-Host "Enter title (press Enter to use filename)"
        if ($title) { $params.Variables = @{ TITLE = $title } }
        
        New-FileFromTemplate @params
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Get-FileTemplate'
    'New-FileFromTemplate'
    'Show-TemplateMenu'
)
