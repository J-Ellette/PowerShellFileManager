#Requires -Version 7.0

<#
.SYNOPSIS
    Quick Accent - Special character and accent input helper
    PowerToys Integration

.DESCRIPTION
    Provides quick access to accented characters and special symbols
    for various languages and character sets.

.NOTES
    Author: PowerShell File Manager V2.0
    Version: 1.0.0
#>

$script:AccentMap = @{
    'a' = @('à', 'á', 'â', 'ã', 'ä', 'å', 'ā', 'ă', 'ą', 'æ')
    'e' = @('è', 'é', 'ê', 'ë', 'ē', 'ĕ', 'ė', 'ę', 'ě')
    'i' = @('ì', 'í', 'î', 'ï', 'ĩ', 'ī', 'ĭ', 'į', 'ı')
    'o' = @('ò', 'ó', 'ô', 'õ', 'ö', 'ø', 'ō', 'ŏ', 'ő', 'œ')
    'u' = @('ù', 'ú', 'û', 'ü', 'ũ', 'ū', 'ŭ', 'ů', 'ű', 'ų')
    'c' = @('ç', 'ć', 'ĉ', 'ċ', 'č')
    'n' = @('ñ', 'ń', 'ņ', 'ň', 'ŉ')
    's' = @('ß', 'ś', 'ŝ', 'ş', 'š')
    'y' = @('ý', 'ÿ', 'ŷ')
    'z' = @('ź', 'ż', 'ž')
}

$script:SymbolCategories = @{
    'Currency' = @('$', '€', '£', '¥', '₹', '₽', '¢', '₩', '₪', '₦')
    'Math' = @('±', '×', '÷', '≠', '≈', '≤', '≥', '∞', '∑', '√', '∫', '∂', 'π')
    'Arrows' = @('←', '→', '↑', '↓', '↔', '↕', '⇐', '⇒', '⇔', '↖', '↗', '↘', '↙')
    'Symbols' = @('©', '®', '™', '°', '§', '¶', '†', '‡', '•', '…', '‰', '‱')
    'Quotes' = @('"', '"', ''', ''', '«', '»', '‹', '›')
}

function Get-AccentedCharacter {
    <#
    .SYNOPSIS
        Get accented variations of a character
    
    .DESCRIPTION
        Returns all available accented versions of a base character
    
    .PARAMETER Character
        Base character (a-z)
    
    .EXAMPLE
        Get-AccentedCharacter -Character 'a'
        Returns: à, á, â, ã, ä, å, ā, ă, ą, æ
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [char]$Character
    )
    
    $char = $Character.ToString().ToLower()
    
    if ($script:AccentMap.ContainsKey($char)) {
        $script:AccentMap[$char]
    } else {
        Write-Warning "No accents available for character: $Character"
    }
}

function Get-SpecialSymbol {
    <#
    .SYNOPSIS
        Get special symbols by category
    
    .DESCRIPTION
        Returns special symbols organized by category
    
    .PARAMETER Category
        Symbol category (Currency, Math, Arrows, Symbols, Quotes)
    
    .EXAMPLE
        Get-SpecialSymbol -Category Currency
        Returns currency symbols
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Currency', 'Math', 'Arrows', 'Symbols', 'Quotes', 'All')]
        [string]$Category = 'All'
    )
    
    if ($Category -eq 'All') {
        $script:SymbolCategories.GetEnumerator() | ForEach-Object {
            [PSCustomObject]@{
                Category = $_.Key
                Symbols = $_.Value
            }
        }
    } else {
        [PSCustomObject]@{
            Category = $Category
            Symbols = $script:SymbolCategories[$Category]
        }
    }
}

function Show-QuickAccentMenu {
    <#
    .SYNOPSIS
        Display interactive quick accent menu
    
    .DESCRIPTION
        Shows an interactive menu to select accented characters and special symbols
    
    .EXAMPLE
        Show-QuickAccentMenu
        Launch the quick accent selector
    #>
    [CmdletBinding()]
    param()
    
    Write-Host "`nQuick Accent Character Selector" -ForegroundColor Cyan
    Write-Host "=" * 50
    
    while ($true) {
        Write-Host "`nOptions:" -ForegroundColor Yellow
        Write-Host "1. Accented characters (a-z)"
        Write-Host "2. Currency symbols"
        Write-Host "3. Math symbols"
        Write-Host "4. Arrow symbols"
        Write-Host "5. Special symbols"
        Write-Host "6. Quote symbols"
        Write-Host "Q. Quit"
        
        $choice = Read-Host "`nSelect option"
        
        switch ($choice.ToLower()) {
            '1' {
                $char = Read-Host "Enter base character (a-z)"
                $accents = Get-AccentedCharacter -Character $char
                if ($accents) {
                    Write-Host "`nAvailable accents for '$char':" -ForegroundColor Green
                    $accents | ForEach-Object { Write-Host $_ -NoNewline; Write-Host " " -NoNewline }
                    Write-Host ""
                    $selected = Read-Host "`nEnter character to copy (or press Enter to skip)"
                    if ($selected) {
                        try {
                            Set-Clipboard -Value $selected
                            Write-Host "Copied to clipboard: $selected" -ForegroundColor Green
                        } catch {
                            Write-Warning "Could not copy to clipboard"
                        }
                    }
                }
            }
            '2' { Show-SymbolList -Category 'Currency' }
            '3' { Show-SymbolList -Category 'Math' }
            '4' { Show-SymbolList -Category 'Arrows' }
            '5' { Show-SymbolList -Category 'Symbols' }
            '6' { Show-SymbolList -Category 'Quotes' }
            'q' { return }
            default { Write-Host "Invalid option" -ForegroundColor Red }
        }
    }
}

function Show-SymbolList {
    param([string]$Category)
    
    $symbols = (Get-SpecialSymbol -Category $Category).Symbols
    Write-Host "`n$Category Symbols:" -ForegroundColor Green
    $symbols | ForEach-Object { Write-Host $_ -NoNewline; Write-Host " " -NoNewline }
    Write-Host ""
    
    $selected = Read-Host "`nEnter symbol to copy (or press Enter to skip)"
    if ($selected) {
        try {
            Set-Clipboard -Value $selected
            Write-Host "Copied to clipboard: $selected" -ForegroundColor Green
        } catch {
            Write-Warning "Could not copy to clipboard"
        }
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Get-AccentedCharacter'
    'Get-SpecialSymbol'
    'Show-QuickAccentMenu'
)
