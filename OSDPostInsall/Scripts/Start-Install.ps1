# The fresh look to the summary screen, has come from me hijacking the awesome splash screen from Trevor Joneshttps://smsagent.blog/2018/08/21/create-a-custom-splash-screen-for-a-windows-10-in-place-upgrade/ 
# and adapted it to work here along with the incredible tools provided by https://mahapps.com/

# Create a new PS process to call the "Spawn-Packages.ps1" and "Spawn-SplashScreen.ps1" script to prevennt the splash screen from blocking the installation script

# Enable Cleanup and Restart
$CleanupAndRestart = $False

# Start Installation Of Packages
$InstallProcess = New-Object System.Diagnostics.Process
$InstallProcess.StartInfo.UseShellExecute = $false
$InstallProcess.StartInfo.FileName = "PowerShell.exe"
$InstallProcess.StartInfo.Arguments = " -File ""$PSScriptRoot\Spawn-Packages.ps1"""
$InstallProcess.StartInfo.CreateNoWindow = $true
$InstallProcess.Start()

# Show Splash-Screen
$SplashScreenProcess = New-Object System.Diagnostics.Process
$SplashScreenProcess.StartInfo.UseShellExecute = $false
$SplashScreenProcess.StartInfo.FileName = "PowerShell.exe"
$SplashScreenProcess.StartInfo.Arguments = " -File ""$PSScriptRoot\Spawn-SplashScreen.ps1"""
$SplashScreenProcess.StartInfo.CreateNoWindow = $true
$SplashScreenProcess.Start()
$SplashScreenProcess.WaitForExit()

# If Cleanup And Restart Is Set To True (can be channge on line 3 ($True or $False)
if ($CleanupAndRestart -eq $True) {

    # If Installation Successful - Run Clean-up and Remove PostInstall Folder and contents  and restart
    if ($InstallProcess.ExitCode -eq 0) {Remove-Item -Path  "$($env:SystemDrive)\Temp\PostInstall" -Recurse -Force  -ErrorAction Ignore}

     # Restart PC
     Restart-Computer -Force
}




