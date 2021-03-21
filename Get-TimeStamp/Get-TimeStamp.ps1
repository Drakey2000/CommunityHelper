<#
.SYNOPSIS
    Enables you to add Task Sequence Task Steps and it will record the time it was initiated and calculate the duration
    of time passed from when it was last initiated

.DESCRIPTION
    Get-TimeStamp is a function that returns all time stamps and differencec from a running task sequnce

.PARAMETER State
    None


.EXAMPLE
     Get-TimeStamp

.OUTPUTS
    C:\Windows\Logs\ComputaCenter\TaskSequenceName-Timestamp.log

.NOTES
    Author:  Steven Drake
    Version: 1.0
#>

Try{
    # Import Microsoft.SMS.TSEnvironment
    $TSEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment

    # Get Script Name - Without Extention
    $FileName = (Get-Item $PSCommandPath).Basename

    # Set Log File
    $Logfile = "$($env:windir)\CCM\Logs\_$($TSEnv.Value('_SMSTSPackageName'))-$FileName.log"

    # Create Log Folder
    New-Item -Path (Split-Path -Path $Logfile) -ItemType Directory -Force

    # Create Column Headers
    If(!(Test-Path -Path $Logfile)){Add-Content $Logfile -Value "Step Name,Start Timestamp,Duration Split - Days.Hrs.Mins:Secs"}

    # Get Current Time Stamp
    $CurrentTime=(Get-Date)

    # Get Running Step
    $Step = $TSEnv.Value('_SMSTSCurrentActionName')

    # Get Previous Time Stamp to Work Out Duration
    Try{

        # Calculate Time Split
        $Duration = (New-TimeSpan -Start $TSEnv.Value('LastTimeStamp') –End $CurrentTime)

        # Convert Time Split to Days. Hours : Minutes : Seconds
        $DurationString = "{0:dd}.{0:hh}:{0:mm}:{0:ss}" -f $Duration

    }Catch{}

    # Write TimeStamp Log - Comma Seperated
    Add-Content $Logfile -Value "$Step,$CurrentTime,$DurationString"

    # Update LastTimeStamp
    $TSEnv.Value('LastTimeStamp') = $CurrentTime

}Catch{ Add-Content $Logfile -Value $_.Exception.Message; Exit 1}



