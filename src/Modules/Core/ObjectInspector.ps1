#Requires -Version 7.0

# Object Inspector Module - Expandable property panel for rich metadata display
# Shows all available file metadata as PowerShell objects

function Show-ObjectInspector {
    <#
    .SYNOPSIS
        Opens the object inspector for a file or object
    .DESCRIPTION
        Displays all properties and metadata of a file or PowerShell object
        with the ability to filter by values and edit properties
    .PARAMETER Path
        Path to the file to inspect
    .PARAMETER Object
        PowerShell object to inspect
    .EXAMPLE
        Show-ObjectInspector -Path "C:\file.txt"
        Inspects a file
    .EXAMPLE
        Get-Process | Select-Object -First 1 | Show-ObjectInspector
        Inspects a process object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [object]$Object,
        
        [Parameter(Mandatory=$false)]
        [string]$Path
    )
    
    # Get the object to inspect
    if ($Path) {
        $Object = Get-Item -Path $Path
    }
    
    if (-not $Object) {
        Write-Error "No object or path specified"
        return
    }
    
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Object Inspector - PowerShell File Manager"
        Height="700" Width="900"
        WindowStartupLocation="CenterScreen"
        Background="#1E1E1E">
    <Window.Resources>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="#CCCCCC"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="CaretBrush" Value="#CCCCCC"/>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderThickness" Value="0"/>
        </Style>
    </Window.Resources>
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <!-- Object Info Header -->
        <Border Grid.Row="0" Background="#2D2D30" CornerRadius="4" Padding="10" Margin="0,0,0,10">
            <StackPanel>
                <TextBlock Name="ObjectName" FontSize="18" FontWeight="Bold" Foreground="#4EC9B0"/>
                <TextBlock Name="ObjectType" FontSize="12" Foreground="#999999" Margin="0,5,0,0"/>
            </StackPanel>
        </Border>
        
        <!-- Filter Box -->
        <Border Grid.Row="1" Background="#252526" CornerRadius="4" Padding="5" Margin="0,0,0,10">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="Filter:" VerticalAlignment="Center" Margin="0,0,10,0"/>
                <TextBox Grid.Column="1" Name="FilterBox" Background="Transparent" BorderThickness="0"/>
            </Grid>
        </Border>
        
        <!-- Properties Grid -->
        <Border Grid.Row="2" Background="#252526" CornerRadius="4">
            <DataGrid Name="PropertiesGrid"
                      AutoGenerateColumns="False"
                      IsReadOnly="False"
                      Background="#1E1E1E"
                      Foreground="#E0E0E0"
                      GridLinesVisibility="Horizontal"
                      HeadersVisibility="Column"
                      RowBackground="#1E1E1E"
                      AlternatingRowBackground="#252526"
                      CanUserSortColumns="True">
                <DataGrid.ColumnHeaderStyle>
                    <Style TargetType="DataGridColumnHeader">
                        <Setter Property="Foreground" Value="#CCCCCC"/>
                        <Setter Property="Background" Value="#2D2D30"/>
                        <Setter Property="FontWeight" Value="SemiBold"/>
                        <Setter Property="Padding" Value="8,4"/>
                    </Style>
                </DataGrid.ColumnHeaderStyle>
                <DataGrid.Columns>
                    <DataGridTextColumn Header="Property" Binding="{Binding Name}" Width="200" IsReadOnly="True">
                        <DataGridTextColumn.ElementStyle>
                            <Style TargetType="TextBlock">
                                <Setter Property="FontWeight" Value="Bold"/>
                                <Setter Property="Foreground" Value="#569CD6"/>
                            </Style>
                        </DataGridTextColumn.ElementStyle>
                    </DataGridTextColumn>
                    <DataGridTextColumn Header="Value" Binding="{Binding Value}" Width="*">
                        <DataGridTextColumn.ElementStyle>
                            <Style TargetType="TextBlock">
                                <Setter Property="Foreground" Value="#E0E0E0"/>
                            </Style>
                        </DataGridTextColumn.ElementStyle>
                    </DataGridTextColumn>
                    <DataGridTextColumn Header="Type" Binding="{Binding Type}" Width="150" IsReadOnly="True">
                        <DataGridTextColumn.ElementStyle>
                            <Style TargetType="TextBlock">
                                <Setter Property="Foreground" Value="#4EC9B0"/>
                            </Style>
                        </DataGridTextColumn.ElementStyle>
                    </DataGridTextColumn>
                </DataGrid.Columns>
            </DataGrid>
        </Border>
        
        <!-- Action Buttons -->
        <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
            <Button Name="ExportBtn" Content="Export Properties" Padding="10,5" Margin="0,0,10,0"/>
            <Button Name="RefreshBtn" Content="Refresh" Padding="10,5" Margin="0,0,10,0"/>
            <Button Name="CloseBtn" Content="Close" Padding="10,5"/>
        </StackPanel>
    </Grid>
</Window>
"@
    
    try {
        $window = [Windows.Markup.XamlReader]::Parse($xaml)
        $objectName = $window.FindName("ObjectName")
        $objectType = $window.FindName("ObjectType")
        $filterBox = $window.FindName("FilterBox")
        $propertiesGrid = $window.FindName("PropertiesGrid")
        $exportBtn = $window.FindName("ExportBtn")
        $refreshBtn = $window.FindName("RefreshBtn")
        $closeBtn = $window.FindName("CloseBtn")
        
        # Set object info
        $objectName.Text = if ($Object.Name) { $Object.Name } else { $Object.ToString() }
        $objectType.Text = "Type: $($Object.GetType().FullName)"
        
        # Get all properties
        $LoadProperties = {
            $properties = [System.Collections.ArrayList]::new()
            
            # Get standard properties
            foreach ($prop in ($Object | Get-Member -MemberType Property, NoteProperty)) {
                try {
                    $value = $Object.($prop.Name)
                    $properties.Add([PSCustomObject]@{
                        Name = $prop.Name
                        Value = if ($value) { $value.ToString() } else { "" }
                        Type = if ($value) { $value.GetType().Name } else { "Null" }
                    }) | Out-Null
                } catch {
                    $properties.Add([PSCustomObject]@{
                        Name = $prop.Name
                        Value = "<Error reading property>"
                        Type = "Error"
                    }) | Out-Null
                }
            }
            
            # For files, add extended properties
            if ($Object -is [System.IO.FileInfo] -or $Object -is [System.IO.DirectoryInfo]) {
                try {
                    # Add file-specific metadata
                    $shell = New-Object -ComObject Shell.Application
                    $folder = $shell.Namespace($Object.DirectoryName)
                    $file = $folder.ParseName($Object.Name)
                    
                    for ($i = 0; $i -lt 320; $i++) {
                        $propName = $folder.GetDetailsOf($null, $i)
                        if ($propName) {
                            $propValue = $folder.GetDetailsOf($file, $i)
                            if ($propValue) {
                                $properties.Add([PSCustomObject]@{
                                    Name = "Extended: $propName"
                                    Value = $propValue
                                    Type = "String"
                                }) | Out-Null
                            }
                        }
                    }
                } catch {
                    # Extended properties not available
                }
            }
            
            return $properties
        }
        
        $allProperties = & $LoadProperties
        $propertiesGrid.ItemsSource = $allProperties
        
        # Filter box handler
        $filterBox.Add_TextChanged({
            $filter = $filterBox.Text
            if ([string]::IsNullOrWhiteSpace($filter)) {
                $propertiesGrid.ItemsSource = $allProperties
            } else {
                $filtered = $allProperties | Where-Object {
                    $_.Name -like "*$filter*" -or $_.Value -like "*$filter*"
                }
                $propertiesGrid.ItemsSource = $filtered
            }
        })
        
        # Export button handler
        $exportBtn.Add_Click({
            $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
            $saveDialog.Filter = "CSV File (*.csv)|*.csv|JSON File (*.json)|*.json"
            $saveDialog.Title = "Export Properties"
            
            if ($saveDialog.ShowDialog() -eq 'OK') {
                $extension = [System.IO.Path]::GetExtension($saveDialog.FileName)
                if ($extension -eq '.csv') {
                    $allProperties | Export-Csv -Path $saveDialog.FileName -NoTypeInformation
                } else {
                    $allProperties | ConvertTo-Json | Out-File -FilePath $saveDialog.FileName
                }
                [System.Windows.MessageBox]::Show("Properties exported successfully!", "Success", 'OK', 'Information')
            }
        })
        
        # Refresh button handler
        $refreshBtn.Add_Click({
            if ($Path) {
                $script:Object = Get-Item -Path $Path
            }
            $allProperties = & $LoadProperties
            $propertiesGrid.ItemsSource = $allProperties
            $filterBox.Text = ""
            
            # Update object info display
            $objectName.Text = if ($script:Object.Name) { $script:Object.Name } else { $script:Object.ToString() }
            $objectType.Text = "Type: $($script:Object.GetType().FullName)"
        })
        
        # Close button handler
        $closeBtn.Add_Click({
            $window.Close()
        })
        
        # Handle property cell editing
        $propertiesGrid.Add_CellEditEnding({
            param($eventSender, $e)
            if ($e.EditAction -eq 'Commit') {
                $property = $e.Row.Item
                $newValue = $e.EditingElement.Text
                
                try {
                    # Attempt to set the property on the object
                    $Object.($property.Name) = $newValue
                    [System.Windows.MessageBox]::Show("Property updated successfully!", "Success", 'OK', 'Information')
                } catch {
                    [System.Windows.MessageBox]::Show("Failed to update property: $_", "Error", 'OK', 'Error')
                    $e.Cancel = $true
                }
            }
        })
        
        $window.ShowDialog() | Out-Null
        
    } catch {
        Write-Error "Failed to create object inspector: $_"
    }
}

function Get-ObjectDetails {
    <#
    .SYNOPSIS
        Gets detailed properties of an object
    .DESCRIPTION
        Returns all properties and metadata of an object as a structured result
    .PARAMETER Path
        Path to the file to inspect
    .PARAMETER Object
        PowerShell object to inspect
    .EXAMPLE
        Get-ObjectDetails -Path "C:\file.txt"
        Gets details for a file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [object]$Object,
        
        [Parameter(Mandatory=$false)]
        [string]$Path
    )
    
    # Get the object to inspect
    if ($Path) {
        $Object = Get-Item -Path $Path
    }
    
    if (-not $Object) {
        Write-Error "No object or path specified"
        return
    }
    
    $properties = [System.Collections.ArrayList]::new()
    
    # Get standard properties
    foreach ($prop in ($Object | Get-Member -MemberType Property, NoteProperty)) {
        try {
            $value = $Object.($prop.Name)
            $properties.Add([PSCustomObject]@{
                Name = $prop.Name
                Value = if ($value) { $value.ToString() } else { "" }
                Type = if ($value) { $value.GetType().Name } else { "Null" }
            }) | Out-Null
        } catch {
            $properties.Add([PSCustomObject]@{
                Name = $prop.Name
                Value = "<Error reading property>"
                Type = "Error"
            }) | Out-Null
        }
    }
    
    return $properties
}

Export-ModuleMember -Function Show-ObjectInspector, Get-ObjectDetails
