#Requires -Version 7.0

# Common private helpers shared across all File Manager feature files.
# These are intentionally NOT exported - they are internal utilities available
# to every function once the root module dot-sources the feature files.

function Format-FileSize {
    param([long]$Bytes)

    if ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    } elseif ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    } elseif ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    } else {
        return "$Bytes bytes"
    }
}

function Get-FileManagerThemeXaml {
    <#
    Shared dark-theme resources injected into every window's <Window.Resources>.
    Interactive controls are retemplated because the stock WPF (Aero2) templates
    hard-code their light hover/selection colors, which made white text
    unreadable on hover. All hover/active states use the accent blue.

    Palette: window #1E1E1E, panel #2D2D30, border #3E3E42, text #CCCCCC,
             accent #007ACC, accent-pressed #005A9E
    #>
    return @'
        <!-- ==== Menu item templates (keyed, referenced by the MenuItem style below) ==== -->
        <ControlTemplate x:Key="FMMenuTopLevelHeader" TargetType="{x:Type MenuItem}">
            <Border x:Name="Bd" Background="Transparent" Padding="10,5">
                <Grid>
                    <ContentPresenter ContentSource="Header" RecognizesAccessKey="True" VerticalAlignment="Center"/>
                    <Popup x:Name="PART_Popup" Placement="Bottom"
                           IsOpen="{Binding IsSubmenuOpen, RelativeSource={RelativeSource TemplatedParent}}"
                           AllowsTransparency="True" Focusable="False" PopupAnimation="Fade">
                        <Border Background="#2D2D30" BorderBrush="#3E3E42" BorderThickness="1" Padding="2">
                            <ItemsPresenter KeyboardNavigation.DirectionalNavigation="Cycle"/>
                        </Border>
                    </Popup>
                </Grid>
            </Border>
            <ControlTemplate.Triggers>
                <Trigger Property="IsHighlighted" Value="True">
                    <Setter TargetName="Bd" Property="Background" Value="#007ACC"/>
                    <Setter Property="Foreground" Value="White"/>
                </Trigger>
                <Trigger Property="IsSubmenuOpen" Value="True">
                    <Setter TargetName="Bd" Property="Background" Value="#007ACC"/>
                    <Setter Property="Foreground" Value="White"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Opacity" Value="0.5"/>
                </Trigger>
            </ControlTemplate.Triggers>
        </ControlTemplate>
        <ControlTemplate x:Key="FMMenuTopLevelItem" TargetType="{x:Type MenuItem}">
            <Border x:Name="Bd" Background="Transparent" Padding="10,5">
                <ContentPresenter ContentSource="Header" RecognizesAccessKey="True" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
                <Trigger Property="IsHighlighted" Value="True">
                    <Setter TargetName="Bd" Property="Background" Value="#007ACC"/>
                    <Setter Property="Foreground" Value="White"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Opacity" Value="0.5"/>
                </Trigger>
            </ControlTemplate.Triggers>
        </ControlTemplate>
        <ControlTemplate x:Key="FMMenuSubmenuItem" TargetType="{x:Type MenuItem}">
            <Border x:Name="Bd" Background="Transparent" Padding="14,6,14,6">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <ContentPresenter Grid.Column="0" ContentSource="Header" RecognizesAccessKey="True" VerticalAlignment="Center"/>
                    <TextBlock Grid.Column="1" Text="{TemplateBinding InputGestureText}" Margin="24,0,0,0" Opacity="0.6" VerticalAlignment="Center"/>
                </Grid>
            </Border>
            <ControlTemplate.Triggers>
                <Trigger Property="IsHighlighted" Value="True">
                    <Setter TargetName="Bd" Property="Background" Value="#007ACC"/>
                    <Setter Property="Foreground" Value="White"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Opacity" Value="0.5"/>
                </Trigger>
            </ControlTemplate.Triggers>
        </ControlTemplate>
        <ControlTemplate x:Key="FMMenuSubmenuHeader" TargetType="{x:Type MenuItem}">
            <Border x:Name="Bd" Background="Transparent" Padding="14,6,10,6">
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <ContentPresenter Grid.Column="0" ContentSource="Header" RecognizesAccessKey="True" VerticalAlignment="Center"/>
                    <TextBlock Grid.Column="1" Text="&#x25B8;" Margin="24,0,0,0" VerticalAlignment="Center"/>
                    <Popup x:Name="PART_Popup" Placement="Right"
                           IsOpen="{Binding IsSubmenuOpen, RelativeSource={RelativeSource TemplatedParent}}"
                           AllowsTransparency="True" Focusable="False" PopupAnimation="Fade">
                        <Border Background="#2D2D30" BorderBrush="#3E3E42" BorderThickness="1" Padding="2">
                            <ItemsPresenter KeyboardNavigation.DirectionalNavigation="Cycle"/>
                        </Border>
                    </Popup>
                </Grid>
            </Border>
            <ControlTemplate.Triggers>
                <Trigger Property="IsHighlighted" Value="True">
                    <Setter TargetName="Bd" Property="Background" Value="#007ACC"/>
                    <Setter Property="Foreground" Value="White"/>
                </Trigger>
                <Trigger Property="IsSubmenuOpen" Value="True">
                    <Setter TargetName="Bd" Property="Background" Value="#007ACC"/>
                    <Setter Property="Foreground" Value="White"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Opacity" Value="0.5"/>
                </Trigger>
            </ControlTemplate.Triggers>
        </ControlTemplate>

        <!-- ==== Text and input ==== -->
        <Style TargetType="{x:Type TextBlock}">
            <Setter Property="Foreground" Value="#CCCCCC"/>
        </Style>
        <Style TargetType="{x:Type Label}">
            <Setter Property="Foreground" Value="#CCCCCC"/>
        </Style>
        <Style TargetType="{x:Type RadioButton}">
            <Setter Property="Foreground" Value="#CCCCCC"/>
        </Style>
        <Style TargetType="{x:Type CheckBox}">
            <Setter Property="Foreground" Value="#CCCCCC"/>
        </Style>
        <Style TargetType="{x:Type GroupBox}">
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
        </Style>
        <Style TargetType="{x:Type TextBox}">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CaretBrush" Value="#CCCCCC"/>
            <Setter Property="SelectionBrush" Value="#007ACC"/>
            <Setter Property="Padding" Value="2"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type TextBox}">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}" SnapsToDevicePixels="True">
                            <ScrollViewer x:Name="PART_ContentHost" Focusable="False" Padding="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="BorderBrush" Value="#007ACC"/>
                            </Trigger>
                            <Trigger Property="IsKeyboardFocusWithin" Value="True">
                                <Setter TargetName="Bd" Property="BorderBrush" Value="#007ACC"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==== Buttons ==== -->
        <Style TargetType="{x:Type Button}">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderBrush" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="Margin" Value="2"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type Button}">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}" Padding="{TemplateBinding Padding}"
                                SnapsToDevicePixels="True">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" RecognizesAccessKey="True"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#007ACC"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#005A9E"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.5"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==== Menus ==== -->
        <Style TargetType="{x:Type Menu}">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
        </Style>
        <Style TargetType="{x:Type MenuItem}">
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Template" Value="{StaticResource FMMenuSubmenuItem}"/>
            <Style.Triggers>
                <Trigger Property="Role" Value="TopLevelHeader">
                    <Setter Property="Template" Value="{StaticResource FMMenuTopLevelHeader}"/>
                </Trigger>
                <Trigger Property="Role" Value="TopLevelItem">
                    <Setter Property="Template" Value="{StaticResource FMMenuTopLevelItem}"/>
                </Trigger>
                <Trigger Property="Role" Value="SubmenuHeader">
                    <Setter Property="Template" Value="{StaticResource FMMenuSubmenuHeader}"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="{x:Type ContextMenu}">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ContextMenu}">
                        <Border Background="#2D2D30" BorderBrush="#3E3E42" BorderThickness="1" Padding="2">
                            <ItemsPresenter KeyboardNavigation.DirectionalNavigation="Cycle"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="{x:Type Separator}">
            <Setter Property="Background" Value="#3E3E42"/>
        </Style>

        <!-- ==== Tabs ==== -->
        <Style TargetType="{x:Type TabControl}">
            <Setter Property="Background" Value="#252526"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="BorderThickness" Value="0"/>
        </Style>
        <Style TargetType="{x:Type TabItem}">
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type TabItem}">
                        <Border x:Name="Bd" Background="#2D2D30" BorderBrush="#3E3E42" BorderThickness="1,1,1,0"
                                Padding="12,6" Margin="0,0,2,0" SnapsToDevicePixels="True">
                            <ContentPresenter ContentSource="Header" RecognizesAccessKey="True"
                                              HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#007ACC"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                            <MultiTrigger>
                                <MultiTrigger.Conditions>
                                    <Condition Property="IsMouseOver" Value="True"/>
                                    <Condition Property="IsSelected" Value="False"/>
                                </MultiTrigger.Conditions>
                                <Setter TargetName="Bd" Property="Background" Value="#007ACC"/>
                                <Setter Property="Foreground" Value="White"/>
                            </MultiTrigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==== Lists ==== -->
        <Style TargetType="{x:Type ListBox}">
            <Setter Property="Background" Value="#1E1E1E"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
        </Style>
        <Style TargetType="{x:Type ListBoxItem}">
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ListBoxItem}">
                        <Border x:Name="Bd" Background="Transparent" Padding="4,2" SnapsToDevicePixels="True">
                            <ContentPresenter/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#007ACC"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#007ACC"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==== ComboBox ==== -->
        <Style TargetType="{x:Type ComboBox}">
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,4"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ComboBox}">
                        <Grid>
                            <ToggleButton x:Name="ToggleButton" Focusable="False" ClickMode="Press"
                                          IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="{x:Type ToggleButton}">
                                        <Border x:Name="Bd" Background="#2D2D30" BorderBrush="#3E3E42" BorderThickness="1"
                                                SnapsToDevicePixels="True">
                                            <TextBlock x:Name="Arrow" Text="&#x25BE;" HorizontalAlignment="Right"
                                                       VerticalAlignment="Center" Margin="0,0,8,0" Foreground="#CCCCCC"/>
                                        </Border>
                                        <ControlTemplate.Triggers>
                                            <Trigger Property="IsMouseOver" Value="True">
                                                <Setter TargetName="Bd" Property="Background" Value="#007ACC"/>
                                                <Setter TargetName="Arrow" Property="Foreground" Value="White"/>
                                            </Trigger>
                                            <Trigger Property="IsChecked" Value="True">
                                                <Setter TargetName="Bd" Property="Background" Value="#007ACC"/>
                                                <Setter TargetName="Arrow" Property="Foreground" Value="White"/>
                                            </Trigger>
                                        </ControlTemplate.Triggers>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                            </ToggleButton>
                            <ContentPresenter Content="{TemplateBinding SelectionBoxItem}"
                                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                              Margin="{TemplateBinding Padding}" HorizontalAlignment="Left"
                                              VerticalAlignment="Center" IsHitTestVisible="False"/>
                            <Popup x:Name="PART_Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}"
                                   AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                                <Border Background="#2D2D30" BorderBrush="#3E3E42" BorderThickness="1"
                                        MinWidth="{TemplateBinding ActualWidth}" MaxHeight="{TemplateBinding MaxDropDownHeight}">
                                    <ScrollViewer>
                                        <ItemsPresenter KeyboardNavigation.DirectionalNavigation="Contained"/>
                                    </ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="{x:Type ComboBoxItem}">
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ComboBoxItem}">
                        <Border x:Name="Bd" Background="Transparent" Padding="8,4" SnapsToDevicePixels="True">
                            <ContentPresenter/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#007ACC"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.5"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- ==== DataGrid ==== -->
        <Style TargetType="{x:Type DataGridColumnHeader}">
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="Background" Value="#2D2D30"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="8,4"/>
            <Setter Property="BorderBrush" Value="#3E3E42"/>
            <Setter Property="BorderThickness" Value="0,0,1,1"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type DataGridColumnHeader}">
                        <Grid>
                            <Border x:Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                                    BorderThickness="{TemplateBinding BorderThickness}" Padding="{TemplateBinding Padding}"
                                    SnapsToDevicePixels="True">
                                <StackPanel Orientation="Horizontal">
                                    <ContentPresenter VerticalAlignment="Center"/>
                                    <TextBlock x:Name="SortArrow" Text="" Margin="6,0,0,0" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Border>
                            <Thumb x:Name="PART_LeftHeaderGripper" HorizontalAlignment="Left" Width="4" Cursor="SizeWE">
                                <Thumb.Template>
                                    <ControlTemplate TargetType="{x:Type Thumb}">
                                        <Border Background="Transparent"/>
                                    </ControlTemplate>
                                </Thumb.Template>
                            </Thumb>
                            <Thumb x:Name="PART_RightHeaderGripper" HorizontalAlignment="Right" Width="4" Cursor="SizeWE">
                                <Thumb.Template>
                                    <ControlTemplate TargetType="{x:Type Thumb}">
                                        <Border Background="Transparent"/>
                                    </ControlTemplate>
                                </Thumb.Template>
                            </Thumb>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="#007ACC"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                            <Trigger Property="SortDirection" Value="Ascending">
                                <Setter TargetName="SortArrow" Property="Text" Value="&#x25B4;"/>
                            </Trigger>
                            <Trigger Property="SortDirection" Value="Descending">
                                <Setter TargetName="SortArrow" Property="Text" Value="&#x25BE;"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="{x:Type DataGridRow}">
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#007ACC"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="{x:Type DataGridCell}">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
            <Style.Triggers>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#007ACC"/>
                    <Setter Property="Foreground" Value="White"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- ==== Misc ==== -->
        <Style TargetType="{x:Type GridSplitter}">
            <Setter Property="Background" Value="#3E3E42"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#007ACC"/>
                </Trigger>
            </Style.Triggers>
        </Style>
'@
}
