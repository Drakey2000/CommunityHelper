<#
.WARNING
    This script is destructive as it contains Clear-Disk

.SYNOPSIS
    Warning Destructive - Created to run in WinPE OSD to Clear-Disk

.DESCRIPTION
    Runs in WinPE OSD to find all non BusType USB connected Drives and format disk

.NOTES
    File Name      : osddiskclean_exclude_usb.ps1
    Author         : S.P.Drake

.COMPONENT
    (WinPE-EnhancedStorage),Windows PowerShell (WinPE-StorageWMI),Microsoft .NET (WinPE-NetFx),Windows PowerShell (WinPE-PowerShell). Need to
    added to the WinPE Boot Image to enable the script to run

    The COMObject Microsoft.SMS.TSEnvironment is only available in MDT\SCCM WinPE
#>


try{

# Import Microsoft.SMS.TSEnvironment
$TSEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment

# Log file function, just change destaination path if required
Function Write-Log {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$False)]
    [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
    [String]
    $Level,

    [Parameter(Mandatory=$False)]
    [string]
    $Message,

    [Parameter(Mandatory=$False)]
    [string]
    $logfile = "$($TSEnv.value('_SMSTSLogPath'))\OSDDiskClean.log"
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"

    If($logfile) {
        Add-Content $logfile -Value $Line
    }
    Else {
        Write-Output $Line
    }
}


# Read Task Sequnce Variable _SMSTSBootUEFI and set Partition Style
if ($TSEnv.Value('_SMSTSBootUEFI') -eq $True){$Style = 'GPT'} else {$Style = 'MBR'}


# Get only physical disks that are not BusType USB
$physicalDisks = Get-PhysicalDisk | Where-Object -FilterScript {$_.Bustype -ne 'USB'}

    # Did we find any matching physical disks ?
    if ($null-eq $physicalDisks) {
        Write-Log -Message "No physical disks have been detected"
        Write-Log
    }
    else {
        Write-Log -Message "The following physical disks have been detected: -"
        Write-Log

        # Display all physical disks that have been found
        foreach ($disk in $physicalDisks) {
                Write-Log -Message "FriendlyName:  $($disk.FriendlyName)"
                Write-Log -Message "MediaType:  $($disk.MediaType)"
                Write-Log -Message "BusType:  $($disk.BusType)"
                Write-Log -Message "Size:  $($disk.Size /1GB)"
                Write-Log -Message "DeviceID:  $($disk.DeviceID)"
                Write-Log
        }

     }

   # Display action to be performed
    foreach ($disk in $physicalDisks) {

                Write-Log -Message "The physical drive $($disk.FriendlyName) of Bustype $($disk.BusType) and Media Type $($disk.MediaType) on Device ID : $($disk.DeviceId) will be cleaned"

                # If disk is new and Partition Style 'RAW' then Initialize Disk
                if (get-disk -Number $disk.DeviceId | Where-Object {$_.PartitionStyle -eq 'RAW'}){Initialize-Disk -Number $disk.DeviceId -PartitionStyle $style}

                # Clear disk partition and data
                Clear-Disk -Number $disk.DeviceId -RemoveOEM -RemoveData -Confirm:$false
                Write-Log -Message "Command: Clear-Disk -Number $($disk.DeviceId) -RemoveOEM -RemoveData -Confirm:$false"

                # Initialize-Disk
                Initialize-Disk -Number $disk.DeviceId -PartitionStyle $style
                Write-Log -Message "Command: Initialize-Disk -Number $($disk.DeviceId) -PartitionStyle $($style)"

            }
}catcH{
    Write-Log
    Write-Log -Level ERROR -Message $_.Exception.Message
    Write-Log
    Exit 1
}
