# The fresh look to the summary screen, has come from me hijacking the awesome splash screen from Trevor Joneshttps://smsagent.blog/2018/08/21/create-a-custom-splash-screen-for-a-windows-10-in-place-upgrade/ 
# and adapted it to work with here 


# Create a new PS process to call the "Show-Report" script to enable a post cleanup of the scipt and MahApps dependencies
$Process = New-Object System.Diagnostics.Process
$Process.StartInfo.UseShellExecute = $false
$Process.StartInfo.FileName = "PowerShell.exe"
$Process.StartInfo.Arguments = " -File ""$PSScriptRoot\Show-Report.ps1"""
$Process.StartInfo.CreateNoWindow = $true
$Process.Start()
$Process.WaitForExit()


# Cleanup - Delete Script and Dependencies (C:\Windows\Temp\OSDReport Folder)
if (Test-Path "$env:SystemRoot\Temp\OSDReport"){Remove-Item -Path "$env:SystemRoot\Temp\OSDReport" -Recurse -Force}
