##################################################################       Comments        ##################################################################
<#
.SYNOPSIS
     A splash screen to run installation packages post Operating System Deployment, vSphere Template Deployment etc.  Check out https://ourcommunityhelper.com/2021/01/13/vmware-vsphere-post-install-customization/ 

.DESCRIPTION
    The fresh look to the Splash Screen, has come from me hijacking the awesome splash screen from Trevor Joneshttps://smsagent.blog/2018/08/21/create-a-custom-splash-screen-for-a-windows-10-in-place-upgrade/ 
    and adapted it to work alongside the incredible tools provided by https://mahapps.com/

.EXAMPLE

.NOTES
    Author     : STEVEN DRAKE
    Version    : 12 Feb  2021 - Removed additional ticker in Spawn-SplashScreen.ps1 and changed Progress to sTEP x of x in Spawn-Packages.ps1
#>
##################################################################  Set Startup Parameters  ##################################################################

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




