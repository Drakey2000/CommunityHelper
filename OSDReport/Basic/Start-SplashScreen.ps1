
# Create a new PS process to call the "Show-SplashScreen" script to enable a post cleanup of the scipt and dependencies
$Process = New-Object System.Diagnostics.Process
$Process.StartInfo.UseShellExecute = $false
$Process.StartInfo.FileName = "PowerShell.exe"
$Process.StartInfo.Arguments = " -File ""$PSScriptRoot\Show-SplashScreen.ps1"""
$Process.StartInfo.CreateNoWindow = $true
$Process.Start()
$Process.WaitForExit()


# Cleanup - Delete Script and Dependencies (C:\Windows\Temp\OSDReport Folder)
if (Test-Path "$env:SystemRoot\Temp\OSDReport"){Remove-Item -Path "$env:SystemRoot\Temp\OSDReport" -Recurse -Force}

# Set Default (Reapplied on restart) : Enable Cursor Suppression:  0 = Disabled: Mouse cursor is not suppressed 1 = Enabled: Mouse cursor is suppressed (default) - https://support.microsoft.com/en-us/help/4494800/no-mouse-cursor-during-configuration-manager-osd-task-sequence
reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableCursorSuppression /t REG_DWORD /d 1 /f
