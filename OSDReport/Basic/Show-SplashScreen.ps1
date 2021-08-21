##################################################################       Comments        ##################################################################
<#
.SYNOPSIS
    An XAML deployment complete splash screen

.DESCRIPTION
    Used with Configuration Manager Deployment Task Sequence to provide an the end user with a completed Splash Screen.

.EXAMPLE

.NOTES
    Author     : STEVEN DRAKE
    Version    : 15  July 2021 - Initial release
#>
##################################################################  Set Startup Parameters  ##################################################################

# Add AssemblyNames
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms,System.Drawing

# Check if running within the Configuration Manager Task Sequnce
Try{

    # Import Microsoft.SMS.TSProgressUI
    $TaskSequenceProgressUi = New-Object -ComObject "Microsoft.SMS.TSProgressUI"

    # Close Progress Bar
    $TaskSequenceProgressUi.CloseProgressDialog()

    # Import Microsoft.SMS.TSEnvironment
    $TSEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
    
    # Disable TSProgresUI
    $TSEnv.Value("TSDisableProgressUI") = $true

}Catch{}

# Add custom type to prevent the screen from sleeping
$code=@'
using System;
using System.Runtime.InteropServices;
public class DisplayState
{
    [DllImport("kernel32.dll", CharSet = CharSet.Auto,SetLastError = true)]
    public static extern void SetThreadExecutionState(uint esFlags);
    public static void KeepDisplayAwake()
    {
        SetThreadExecutionState(
            0x00000002 | 0x80000000);
    }
    public static void Cancel()
    {
        SetThreadExecutionState(0x80000000);
    }
}
'@

Add-Type -ReferencedAssemblies 'System', 'System.Runtime.InteropServices' -TypeDefinition $code -Language CSharp

# Margin="1,2,3,4" • Left, • Top, • Right, • Bottom

# Create WPF Window
[xml]$xaml = @"
<Window
       xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="MainWindow" WindowStyle="None" ResizeMode="NoResize" Foreground="White" Topmost="True" Left="0" Top="0" Height="800" Width="600">
	<Window.Background>
		<LinearGradientBrush EndPoint="0.5,1" StartPoint="0.5,0">
			<GradientStop Color="#012a47" Offset="0.2" />
			<GradientStop Color="#1271b5" Offset="0.5" />
			<GradientStop Color="#012a47" Offset="0.8" />
		</LinearGradientBrush>
	</Window.Background>
    <DockPanel HorizontalAlignment="Stretch" VerticalAlignment="Stretch">
	    <Grid Name="MainGrid" Height="Auto" Width="Auto" HorizontalAlignment="Stretch" VerticalAlignment="Stretch">
            <Grid.RowDefinitions>
                <RowDefinition Name="Row0" Height="0.25*"/>
                <RowDefinition Name="Row1" Height="*"/>
                <RowDefinition Name="Row2" Height="0.30*"/>
            </Grid.RowDefinitions>         
            <StackPanel Grid.Row="0" Margin="0,0,0,0" VerticalAlignment="Top">
                <TextBlock Name="MainTextBlock" Text="$env:computername" TextWrapping="Wrap" MaxWidth="0" Margin="15,15,15,15" FontSize="50" FontWeight="Light" VerticalAlignment="Center" HorizontalAlignment="Center" TextAlignment="Center" />
            </StackPanel>
            <StackPanel Grid.Row="1" Margin="0,0,0,0" VerticalAlignment="Center">
                <Image Name="MainImage" Source="$($PSScriptRoot)\Resources\Images\Complete.png" VerticalAlignment="Center" HorizontalAlignment="Center" />
            </StackPanel>
            <StackPanel Grid.Row="2" Margin="0,0,0,0" VerticalAlignment="Bottom">
                <TextBlock Name="TextBlock1" Text="$((Get-WmiObject -class Win32_OperatingSystem).Caption + " - " + (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ReleaseId)" TextWrapping="Wrap" MaxWidth="0" Margin="0,0,0,0" FontSize="18" FontWeight="Light" VerticalAlignment="Center" HorizontalAlignment="Center" TextAlignment="Center" />
                <Button Name="Button1" Height="60" Width="140" Margin="0,15,0,15" Background="White" BorderThickness="1" VerticalAlignment="Bottom" HorizontalAlignment="Center" >
                <Button.Resources>
                    <Style TargetType="{x:Type Border}">
                        <Setter Property="CornerRadius" Value="4"/>
                    </Style>
                </Button.Resources>
            </Button>
            </StackPanel>
	    </Grid>
	</DockPanel>
</Window>
"@

# Get primary monitor size
$PrimaryMonitor = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize

# Create a synchronized hash table and add the WPF window and its named elements to it
$UI = [System.Collections.Hashtable]::Synchronized(@{})
$UI.Window = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml))
$xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") |
    ForEach-Object -Process {
        $UI.$($_.Name) = $UI.Window.FindName($_.Name)
    }

# Set some initial values
$UI.MainTextBlock.MaxWidth = $PrimaryMonitor.Width
$UI.TextBlock1.MaxWidth = $PrimaryMonitor.Width

# Add image to button
$Image = New-Object System.Windows.Controls.Image
$Image.Source = "$PSScriptRoot\Resources\Images\PowerButton.png"
$UI.Button1.Content = $Image

# Event: Window loaded
$UI.Window.Add_Loaded({

    # Activate the window to bring it to the front
    $UI.Window.Activate()

    # Fill the screen
    $UI.Window.Left = $PrimaryMonitor.Left
    $UI.Window.Top = $PrimaryMonitor.Top
    $UI.Window.Height = $PrimaryMonitor.Height
    $UI.Window.Width = $PrimaryMonitor.Width
    $UI.Window.TopMost = $True

    # Fill the image space according to dynamic row height
    $UI.MainImage.MaxHeight = $UI.Row1.ActualHeight
    $UI.MainImage.Stretch = "Uniform"

    # Show mouse cursor
    [System.Windows.Forms.Cursor]::Show()

    # Keep Display awake
    [DisplayState]::KeepDisplayAwake()
})

# Event: Window closing (for testing)
$UI.Window.Add_Closing({

    # Cancel keeping the display awake
    [DisplayState]::Cancel()

})

# Event: Close the window on Button Click
$UI.Button1.Add_Click({$UI.Window.Close()})

# Show the splah screen
$UI.Window.ShowDialog()

