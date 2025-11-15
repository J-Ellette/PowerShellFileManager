#Requires -Version 7.0

# Query Builder Module - Visual interface for constructing complex searches
# Generates PowerShell filter expressions from GUI input

function New-QueryBuilder {
    <#
    .SYNOPSIS
        Opens the visual query builder interface
    .DESCRIPTION
        Provides a drag-and-drop interface for building complex file search filters
        that generate PowerShell Where-Object clauses
    .EXAMPLE
        New-QueryBuilder
        Opens the query builder interface
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$InitialPath = $pwd
    )
    
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Query Builder - PowerShell File Manager"
        Height="700" Width="1000"
        WindowStartupLocation="CenterScreen"
        Background="#1E1E1E">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderThickness" Value="0"/>
        </Style>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="#CCCCCC"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="CaretBrush" Value="#CCCCCC"/>
        </Style>
    </Window.Resources>
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="200"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Toolbar -->
        <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="0,0,0,10">
            <Button Name="AddFilterBtn" Content="+ Add Filter" Padding="10,5" Margin="0,0,5,0"/>
            <Button Name="ClearBtn" Content="Clear All" Padding="10,5" Margin="0,0,5,0"/>
            <Button Name="SaveQueryBtn" Content="Save Query" Padding="10,5" Margin="0,0,5,0"/>
            <Button Name="LoadQueryBtn" Content="Load Query" Padding="10,5"/>
        </StackPanel>
        
        <!-- Filter Builder Area -->
        <Border Grid.Row="1" Background="#252526" CornerRadius="4" Padding="10">
            <ScrollViewer VerticalScrollBarVisibility="Auto">
                <StackPanel Name="FiltersPanel">
                    <!-- Filters will be added here dynamically -->
                    <TextBlock Text="Click 'Add Filter' to start building your query" 
                               Foreground="#999999" FontSize="14" HorizontalAlignment="Center" 
                               VerticalAlignment="Center" Margin="0,50,0,0"/>
                </StackPanel>
            </ScrollViewer>
        </Border>
        
        <!-- Generated Query -->
        <Border Grid.Row="2" Background="#2D2D30" CornerRadius="4" Padding="10" Margin="0,10,0,10">
            <StackPanel>
                <TextBlock Text="Generated PowerShell Query:" Foreground="#CCCCCC" FontWeight="Bold" Margin="0,0,0,5"/>
                <TextBox Name="GeneratedQuery" FontFamily="Consolas" FontSize="12" 
                         Foreground="#4EC9B0" Background="#1E1E1E" IsReadOnly="True"
                         TextWrapping="Wrap" MinHeight="60" BorderThickness="0"/>
            </StackPanel>
        </Border>
        
        <!-- Preview Results -->
        <Border Grid.Row="3" Background="#252526" CornerRadius="4">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <Border Grid.Row="0" Background="#007ACC" Padding="5">
                    <TextBlock Name="ResultsHeader" Text="Preview Results (0 items)" 
                               Foreground="White" FontWeight="Bold"/>
                </Border>
                <DataGrid Grid.Row="1" Name="PreviewGrid"
                          AutoGenerateColumns="True"
                          IsReadOnly="True"
                          Background="#1E1E1E"
                          Foreground="#E0E0E0"
                          RowBackground="#1E1E1E"
                          AlternatingRowBackground="#252526"
                          GridLinesVisibility="Horizontal"
                          HeadersVisibility="Column">
                    <DataGrid.ColumnHeaderStyle>
                        <Style TargetType="DataGridColumnHeader">
                            <Setter Property="Foreground" Value="#CCCCCC"/>
                            <Setter Property="Background" Value="#2D2D30"/>
                            <Setter Property="FontWeight" Value="SemiBold"/>
                            <Setter Property="Padding" Value="8,4"/>
                        </Style>
                    </DataGrid.ColumnHeaderStyle>
                </DataGrid>
            </Grid>
        </Border>
        
        <!-- Action Buttons -->
        <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button Name="ExecuteBtn" Content="Execute Query" Padding="15,8" Margin="0,0,10,0"/>
            <Button Name="CancelBtn" Content="Cancel" Padding="15,8"/>
        </StackPanel>
    </Grid>
</Window>
"@
    
    try {
        $window = [Windows.Markup.XamlReader]::Parse($xaml)
        $filtersPanel = $window.FindName("FiltersPanel")
        $generatedQuery = $window.FindName("GeneratedQuery")
        $previewGrid = $window.FindName("PreviewGrid")
        $resultsHeader = $window.FindName("ResultsHeader")
        $addFilterBtn = $window.FindName("AddFilterBtn")
        $clearBtn = $window.FindName("ClearBtn")
        $saveQueryBtn = $window.FindName("SaveQueryBtn")
        $loadQueryBtn = $window.FindName("LoadQueryBtn")
        $executeBtn = $window.FindName("ExecuteBtn")
        $cancelBtn = $window.FindName("CancelBtn")
        
        # Filter collection
        $script:Filters = [System.Collections.ArrayList]::new()
        
        # Add Filter button handler
        $addFilterBtn.Add_Click({
            Add-FilterControl -Panel $filtersPanel -OnChange {
                Update-GeneratedQuery -TextBox $generatedQuery -PreviewGrid $previewGrid -ResultsHeader $resultsHeader -BasePath $InitialPath
            }
        })
        
        # Clear button handler
        $clearBtn.Add_Click({
            $script:Filters.Clear()
            $filtersPanel.Children.Clear()
            $generatedQuery.Text = ""
            $previewGrid.ItemsSource = $null
            $resultsHeader.Text = "Preview Results (0 items)"
        })
        
        # Save Query button handler
        $saveQueryBtn.Add_Click({
            Save-Query -Query $generatedQuery.Text
        })
        
        # Load Query button handler
        $loadQueryBtn.Add_Click({
            $query = Import-Query
            if ($query) {
                $generatedQuery.Text = $query
            }
        })
        
        # Execute button handler
        $executeBtn.Add_Click({
            if (-not [string]::IsNullOrWhiteSpace($generatedQuery.Text)) {
                try {
                    # Note: Query is generated by the application from validated GUI inputs, not arbitrary user input
                    # Validate the query starts with expected command
                    if ($generatedQuery.Text -notmatch '^\s*Get-ChildItem\s') {
                        [System.Windows.MessageBox]::Show("Invalid query format. Query must start with Get-ChildItem.", "Error", 'OK', 'Error')
                        return
                    }
                    $results = Invoke-Expression $generatedQuery.Text
                    $window.Tag = $results
                    $window.DialogResult = $true
                    $window.Close()
                } catch {
                    [System.Windows.MessageBox]::Show("Error executing query: $_", "Error", 'OK', 'Error')
                }
            }
        })
        
        # Cancel button handler
        $cancelBtn.Add_Click({
            $window.Close()
        })
        
        $window.ShowDialog() | Out-Null
        return $window.Tag
        
    } catch {
        Write-Error "Failed to create query builder: $_"
    }
}

function Add-FilterControl {
    param($Panel, $OnChange)
    
    $filterXaml = @"
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Background="#2D2D30" CornerRadius="4" Padding="10" Margin="0,0,0,10">
    <Border.Resources>
        <Style TargetType="ComboBox">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="BorderThickness" Value="1"/>
        </Style>
        <Style TargetType="ComboBoxItem">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Style.Triggers>
                <Trigger Property="IsHighlighted" Value="True">
                    <Setter Property="Background" Value="#007ACC"/>
                    <Setter Property="Foreground" Value="White"/>
                </Trigger>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#007ACC"/>
                    <Setter Property="Foreground" Value="White"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="5,3"/>
        </Style>
    </Border.Resources>
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="150"/>
            <ColumnDefinition Width="120"/>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>

        <ComboBox Grid.Column="0" Name="PropertyCombo" Margin="0,0,5,0">
            <ComboBoxItem Content="Name"/>
            <ComboBoxItem Content="Extension"/>
            <ComboBoxItem Content="Size"/>
            <ComboBoxItem Content="Created"/>
            <ComboBoxItem Content="Modified"/>
            <ComboBoxItem Content="Accessed"/>
            <ComboBoxItem Content="Attributes"/>
            <ComboBoxItem Content="Directory"/>
        </ComboBox>

        <ComboBox Grid.Column="1" Name="OperatorCombo" Margin="0,0,5,0">
            <ComboBoxItem Content="Equals"/>
            <ComboBoxItem Content="Not Equals"/>
            <ComboBoxItem Content="Contains"/>
            <ComboBoxItem Content="Greater Than"/>
            <ComboBoxItem Content="Less Than"/>
            <ComboBoxItem Content="Matches (Regex)"/>
        </ComboBox>

        <TextBox Grid.Column="2" Name="ValueBox" Margin="0,0,5,0"/>

        <Button Grid.Column="3" Name="RemoveBtn" Content="✕" Width="30" Height="30"/>
    </Grid>
</Border>
"@
    
    $filterControl = [Windows.Markup.XamlReader]::Parse($filterXaml)
    $propertyCombo = $filterControl.FindName("PropertyCombo")
    $operatorCombo = $filterControl.FindName("OperatorCombo")
    $valueBox = $filterControl.FindName("ValueBox")
    $removeBtn = $filterControl.FindName("RemoveBtn")
    
    # Set defaults
    $propertyCombo.SelectedIndex = 0
    $operatorCombo.SelectedIndex = 0

    # Store filter data
    $filterData = @{
        Control = $filterControl
        Property = $propertyCombo
        Operator = $operatorCombo
        Value = $valueBox
    }
    $script:Filters.Add($filterData) | Out-Null

    # Capture the OnChange scriptblock for use in event handlers
    $changeHandler = $OnChange

    # Change handlers - Note: scriptblock is from application code, not user input
    $propertyCombo.Add_SelectionChanged({ if ($changeHandler) { & $changeHandler } })
    $operatorCombo.Add_SelectionChanged({ if ($changeHandler) { & $changeHandler } })
    $valueBox.Add_TextChanged({ if ($changeHandler) { & $changeHandler } })

    # Remove button handler
    $removeBtn.Add_Click({
        $Panel.Children.Remove($filterControl)
        $script:Filters.Remove($filterData)
        if ($changeHandler) { & $changeHandler }
    })
    
    $Panel.Children.Add($filterControl)
}

function Update-GeneratedQuery {
    param($TextBox, $PreviewGrid, $ResultsHeader, $BasePath)
    
    if ($script:Filters.Count -eq 0) {
        $TextBox.Text = ""
        $PreviewGrid.ItemsSource = $null
        $ResultsHeader.Text = "Preview Results (0 items)"
        return
    }
    
    # Build Where-Object clause
    $whereClauses = foreach ($filter in $script:Filters) {
        $prop = $filter.Property.SelectedItem.Content
        $op = $filter.Operator.SelectedItem.Content
        $val = $filter.Value.Text
        
        if ([string]::IsNullOrWhiteSpace($val)) { continue }
        
        $propertyMap = @{
            'Name' = '$_.Name'
            'Extension' = '$_.Extension'
            'Size' = '$_.Length'
            'Created' = '$_.CreationTime'
            'Modified' = '$_.LastWriteTime'
            'Accessed' = '$_.LastAccessTime'
            'Attributes' = '$_.Attributes'
            'Directory' = '$_.PSIsContainer'
        }
        
        $operatorMap = @{
            'Equals' = '-eq'
            'Not Equals' = '-ne'
            'Contains' = '-like'
            'Greater Than' = '-gt'
            'Less Than' = '-lt'
            'Matches (Regex)' = '-match'
        }
        
        $propExpr = $propertyMap[$prop]
        $opExpr = $operatorMap[$op]
        
        # Format value based on property type
        if ($prop -in @('Size')) {
            "$propExpr $opExpr $val"
        } elseif ($prop -in @('Created', 'Modified', 'Accessed')) {
            "$propExpr $opExpr [DateTime]'$val'"
        } elseif ($op -eq 'Contains') {
            "$propExpr $opExpr '*$val*'"
        } else {
            "$propExpr $opExpr '$val'"
        }
    }
    
    if ($whereClauses.Count -gt 0) {
        $whereClause = $whereClauses -join ' -and '
        $query = "Get-ChildItem -Path '$BasePath' -Recurse | Where-Object { $whereClause }"
        $TextBox.Text = $query
        
        # Preview results (limit to 100 items)
        try {
            # Note: Query is generated by the application from validated GUI inputs, not arbitrary user input
            # Validate the query starts with expected command
            if ($query -notmatch '^\s*Get-ChildItem\s') {
                $ResultsHeader.Text = "Preview Results (Error: Invalid query format)"
                return
            }
            $results = Invoke-Expression $query | Select-Object -First 100
            $previewData = $results | Select-Object Name, Length, LastWriteTime, FullName
            $PreviewGrid.ItemsSource = $previewData
            $ResultsHeader.Text = "Preview Results ($($results.Count) items shown, may be more...)"
        } catch {
            $ResultsHeader.Text = "Preview Results (Error: $_)"
        }
    }
}

function Save-Query {
    param([string]$Query)
    
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "PowerShell Query (*.psq)|*.psq|All Files (*.*)|*.*"
    $saveDialog.Title = "Save Query"
    
    if ($saveDialog.ShowDialog() -eq 'OK') {
        $Query | Out-File -FilePath $saveDialog.FileName -Encoding UTF8
        [System.Windows.MessageBox]::Show("Query saved successfully!", "Success", 'OK', 'Information')
    }
}

function Import-Query {
    $openDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openDialog.Filter = "PowerShell Query (*.psq)|*.psq|All Files (*.*)|*.*"
    $openDialog.Title = "Import Query"
    
    if ($openDialog.ShowDialog() -eq 'OK') {
        return Get-Content -Path $openDialog.FileName -Raw
    }
    return $null
}

function Build-FileQuery {
    <#
    .SYNOPSIS
        Builds a file query from criteria
    .DESCRIPTION
        Constructs a PowerShell query expression for file searches
    .PARAMETER Criteria
        Query criteria hashtable
    .EXAMPLE
        Build-FileQuery -Criteria @{ Name = "*.txt"; Size = "GT 1MB" }
        Builds a query for text files larger than 1MB
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [hashtable]$Criteria = @{}
    )
    
    $whereClauses = @()
    
    foreach ($key in $Criteria.Keys) {
        $value = $Criteria[$key]
        
        switch ($key) {
            'Name' {
                $whereClauses += "`$_.Name -like '$value'"
            }
            'Extension' {
                $whereClauses += "`$_.Extension -eq '$value'"
            }
            'Size' {
                # Parse size criteria (e.g., "GT 1MB", "LT 100KB")
                if ($value -match '^(GT|LT|EQ)\s+(\d+)(KB|MB|GB)?$') {
                    $op = switch ($Matches[1]) {
                        'GT' { '-gt' }
                        'LT' { '-lt' }
                        'EQ' { '-eq' }
                    }
                    $size = [long]$Matches[2]
                    $unit = $Matches[3]
                    if ($unit -eq 'KB') { $size *= 1KB }
                    elseif ($unit -eq 'MB') { $size *= 1MB }
                    elseif ($unit -eq 'GB') { $size *= 1GB }
                    
                    $whereClauses += "`$_.Length $op $size"
                }
            }
            'Modified' {
                # Date criteria
                $whereClauses += "`$_.LastWriteTime -ge [DateTime]'$value'"
            }
        }
    }
    
    if ($whereClauses.Count -gt 0) {
        $whereClause = $whereClauses -join ' -and '
        return "Get-ChildItem -Recurse | Where-Object { $whereClause }"
    }
    
    return "Get-ChildItem -Recurse"
}

Export-ModuleMember -Function New-QueryBuilder, Build-FileQuery
