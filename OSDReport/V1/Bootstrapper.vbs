Dim oWS
Set oWS = CreateObject("Wscript.Shell")

Call oWS.Run("%windir%\system32\osdsetuphook.exe /execute", 0 , true)
Call oWS.Run("powershell.exe -ExecutionPolicy Bypass -File %windir%\Temp\OSDReport\Show-Report.ps1", 0 , true)

Wscript.Quit(0)

