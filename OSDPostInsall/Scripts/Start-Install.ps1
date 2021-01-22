# Create a new PS process to call the "Show-OSUpgradeBackground" script, to avoid blocking the continuation of task sequence

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




