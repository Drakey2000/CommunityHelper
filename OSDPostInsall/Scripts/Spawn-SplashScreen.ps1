# The fresh look to the summary screen, has come from me hijacking the awesome splash screen from Trevor Joneshttps://smsagent.blog/2018/08/21/create-a-custom-splash-screen-for-a-windows-10-in-place-upgrade/ 
# and adapted it to work here along with the incredible tools provided by https://mahapps.com/


# Set the location we are running from
$Source = $PSScriptRoot

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms,System.Drawing,System.DirectoryServices.AccountManagement
Add-Type -Path "$Source\bin\System.Windows.Interactivity.dll"
Add-Type -Path "$Source\bin\ControlzEx.dll"
Add-Type -Path "$Source\bin\MahApps.Metro.dll"

# Get Primary Monitor
$PrimaryMonitor = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize

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

# Load the main window XAML code
[XML]$Xaml = [System.IO.File]::ReadAllLines("$Source\Xaml\SplashScreen.xaml")

# Create a synchronized hash table and add the WPF window and its named elements to it
$UI = [System.Collections.Hashtable]::Synchronized(@{})
$UI.Window = [Windows.Markup.XamlReader]::Load((New-Object -TypeName System.Xml.XmlNodeReader -ArgumentList $xaml))
$xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]") |
    ForEach-Object -Process {
        $UI.$($_.Name) = $UI.Window.FindName($_.Name)
    }

# Set some initial values
$UI.MainTextBlock.MaxWidth = $PrimaryMonitor.Width
$UI.TextBlock2.MaxWidth = $PrimaryMonitor.Width
$UI.TextBlock3.MaxWidth = $PrimaryMonitor.Width
$UI.TextBlock4.MaxWidth = $PrimaryMonitor.Width
$UI.TextBlock5.MaxWidth = $PrimaryMonitor.Width


$UI.MainTextBlock.Text = "We are now running post setup tasks"
$UI.TextBlock2.Text = ""
$UI.TextBlock3.Text = "Post Installation Progress 0%"
$UI.TextBlock4.Text = "00:00:00"
$UI.TextBlock5.Text = "This will not take long...don't turn off your pc"

# Add Image to Button
$Image = New-Object System.Windows.Controls.Image
$Image.Source = "$Source\Resources\Images\Blue-PowerButton.png"
$UI.Button1.Content = $Image

# Run on Frequency - Update Main Text, Status, Animation
$TimerCode = {

    # Set TimerCode - Timer to 1 Seconds
    $DispatcherTimer.Interval = [TimeSpan]::FromSeconds(1)

    # Get running status from registry
    $Status = Get-ItemProperty -Path HKLM:Software\CommunityHelper\PostInstall -Name Status | Select-Object -ExpandProperty Status -ErrorAction SilentlyContinue

    # If Status Success
    If($status -eq 'Success'){

            $UI.MainTextBlockBeginStoryBoard.Storyboard.stop($UI.Window)

            # Set Successful Post Installation Splash Screen Properties
            $UI.MaintextBlock.Text = "Installation Successful"
            $UI.TextBlock2.Text = Get-Content -Path "C:\Windows\Logs\CommunityHelper\INSTALL - PostInstall-Progress.log" -Raw
            $UI.TextBlock5.Text = "Post Installation Completed Successfully"
            $UI.Button1.Visibility = "Visible"
            $UI.MainGrid.Background = "Green"

            $Stopwatch.Stop()
            $DispatcherTimer.Stop()

    # If Status Error
    }elseif ($status -eq 'Error'){

                $UI.MainTextBlockBeginStoryBoard.Storyboard.stop($UI.Window)

                # Set Failed Post Installation Splash Screen Properties
                $UI.MaintextBlock.Text = "Installation Failed"
                $UI.TextBlock2.Text = Get-Content -Path "C:\Windows\Logs\CommunityHelper\INSTALL - PostInstall-Progress.log" -Raw
                $UI.TextBlock5.Text = "Please check logs for details $(Get-ItemProperty -Path HKLM:Software\CommunityHelper\PostInstall -Name LogFile | Select-Object -ExpandProperty LogFile -ErrorAction SilentlyContinue)"
                $UI.Button1.Visibility = "Visible"
                $UI.MainGrid.Background = "Red"

                $Stopwatch.Stop()
                $DispatcherTimer.Stop()

      }
       # If Installation is in progress
    else{
                $UI.MaintextBlock.Text = "Just some text to test with"
                $UI.MaintextBlock.Text = Get-ItemProperty -Path HKLM:Software\CommunityHelper\PostInstall -Name PackageName | Select-Object -ExpandProperty PackageName -ErrorAction SilentlyContinue
                $UI.TextBlock2.Text = Get-Content -Path "C:\Windows\Logs\CommunityHelper\INSTALL - PostInstall-Progress.log" -Raw

        }

}

# Set TimerCode - Opening Introduction Timer to 6 Seconds
$DispatcherTimer = New-Object -TypeName System.Windows.Threading.DispatcherTimer
$DispatcherTimer.Interval = [TimeSpan]::FromSeconds(6)
$DispatcherTimer.Add_Tick($TimerCode)

# Run on Frequency - Update Progress Bar and Stop watch
$TimerCode2 = {
    $ProgressValue = Get-ItemProperty -Path HKLM:Software\CommunityHelper\PostInstall -Name PackageCountPercentage | Select-Object -ExpandProperty PackageCountPercentage -ErrorAction SilentlyContinue
    $UI.TextBlock4.Text = "$($Stopwatch.Elapsed.Hours.ToString('00')):$($Stopwatch.Elapsed.Minutes.ToString('00')):$($Stopwatch.Elapsed.Seconds.ToString('00'))"
    $UI.ProgressBar.Value  = $ProgressValue
    $UI.TextBlock3.Text = "Post Installation Progress $ProgressValue%"
}

# Set TimerCode2
$DispatcherTimer2 = New-Object -TypeName System.Windows.Threading.DispatcherTimer
$DispatcherTimer2.Interval = [TimeSpan]::FromSeconds(1)
$DispatcherTimer2.Add_Tick($TimerCode2)


# Create Progress stop watch
$Stopwatch = New-Object System.Diagnostics.Stopwatch

# Event: Window loaded
$UI.Window.Add_Loaded({

    # Activate the window to bring it to the fore
    $This.Activate()

    # Fill the screen
    $This.Left = $PrimaryMonitor.Left
    $This.Top = $PrimaryMonitor.Top
    $This.Height = $PrimaryMonitor.Height
    $This.Width = $PrimaryMonitor.Width
    $This.TopMost = $True

    # Keep Display awake
    [DisplayState]::KeepDisplayAwake()
})


# Event: Window closing (for testing)
$UI.Window.Add_Closing({

    # Cancel keeping the display awake
    [DisplayState]::Cancel()

    # Stop stop watch and timers
    $Stopwatch.Stop()
    $DispatcherTimer.Stop()
    $DispatcherTimer2.Stop()
})

# Event: Close the window on right-click (for testing)
# $UI.Window.Add_MouseRightButtonDown({$This.Close()})

# Event: Close the window on Button Click
$UI.Button1.Add_Click({$UI.Window.Close()})

# Start timers and stop watch
$Stopwatch.Start()
$DispatcherTimer.Start()
$DispatcherTimer2.Start()

# Display the window
$UI.Window.ShowDialog()
