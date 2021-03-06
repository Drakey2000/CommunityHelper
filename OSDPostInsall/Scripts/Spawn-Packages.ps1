﻿#################################################################################      Packages      #################################################################################

# Set all your required post installation tasks here...msi, .exe, .vbs, bat etc Silent commands, parameters, mst files
  
# Initialize Package List HashTable
$packageList = @() 

  # Example A
  $packageList += [PSCustomObject]@{
        Name = 'VMware Tools 11.0.0'
        FolderPath = 'Install - Example A\Install.bat' 
        Arguments = ''}
  
  # Example B  
  $packageList += [PSCustomObject]@{
        Name = 'SQL Server 2016'
        FolderPath = 'Install - Example B\Install.bat' 
        Arguments = ''}

  # Example C  
  $packageList += [PSCustomObject]@{
        Name = 'CCMAgent 5.00.9012.1020'
        FolderPath = 'Install - Example C\Install.bat' 
        Arguments = ''}



#################################################################################      Function      #################################################################################

# Clear error logs: Used in testing
$Error.Clear()

# Set Log File
$Logfile = "$($env:windir)\Logs\CommunityHelper\INSTALL - PostInstall.log"

# Set Package Root Folder
$PackageRootFolder = "$($env:SystemDrive)\Temp\PostInstall"

# Set Progeress Log File
$ProgressLogfile = "$($env:windir)\Logs\CommunityHelper\INSTALL - PostInstall-Progress.log"

# Create New Log File
New-Item -Path "$($env:windir)\Logs\CommunityHelper\INSTALL - PostInstall-Progress.log" -ItemType File -Force

# Log function
Function Write-Log {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$False)]
    [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
    [String]
    $Level = "INFO",

    [Parameter(Mandatory=$True)]
    [string]
    $Message,

    [Parameter(Mandatory=$False)]
    [string]
    $logfile = $logfile
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


try{

    # start count item
    [int]$count= 1

    # set script error count
    [int]$scriptError = 0

    # Create New-Registry Key
    New-Item –Path "HKLM:Software\CommunityHelper" –Name PostInstall -Force

    # Set Status Flag
    New-ItemProperty -Path "HKLM:Software\CommunityHelper\PostInstall" -Name "Status" -Value ”Inprogress” -PropertyType "String" -Force

    # Set PackageCountTotal
    New-ItemProperty -Path "HKLM:Software\CommunityHelper\PostInstall" -Name "PackageCountTotal" -Value $packageList.Count -PropertyType "String" -Force
    
    # Set Intial PackageCountPercentage
    New-ItemProperty -Path "HKLM:Software\CommunityHelper\PostInstall" -Name "PackageCountPercentage" -Value 0 -PropertyType "String" -Force

    # Set Package Error Count
    New-ItemProperty -Path "HKLM:Software\CommunityHelper\PostInstall" -Name "PackageErrorCount" -Value $scriptError -PropertyType "String" -Force

    # Set Progress LogFile Path
    New-ItemProperty -Path "HKLM:Software\CommunityHelper\PostInstall" -Name "ProgressLogFile" -Value $ProgressLogfile -PropertyType "String" -Force

    # Set LogFile FilePath
    New-ItemProperty -Path "HKLM:Software\CommunityHelper\PostInstall" -Name "LogFile" -Value $Logfile -PropertyType "String" -Force

    # For Each Application in install list
    foreach($package in $packageList.GetEnumerator()) {

    # Set PackageName
    New-ItemProperty -Path "HKLM:Software\CommunityHelper\PostInstall" -Name "PackageName" -Value $package.Name -PropertyType "String" -Force

    # Set PackageCount
    New-ItemProperty -Path "HKLM:Software\CommunityHelper\PostInstall" -Name "PackageCount" -Value $count -PropertyType "String" -Force

    # Build package full file path
    $packagePath = join-path -path $PackageRootFolder -ChildPath $($package.FolderPath)

    # Log the number of items to be processed
    Write-Log -Level INFO "process $($count) of $($packageList.count)"



        try{

        # Check for Argumnets and start the installation
        If([string]::IsNullOrWhitespace($package.Arguments)){
        
            # Log the application being processed
            Write-Log -Level INFO "starting installation of '$($package.Name)' from '$($packagePath)'"

            $process = Start-Process -FilePath "$packagePath" -wait -PassThru -ErrorAction Continue 
        
        }else{

            # Log the application being processed
            Write-Log -Level INFO "starting installation of '$($package.Name)' from '$($packagePath)' with arguments '$($package.Arguments)'"

            $process = Start-Process -FilePath "$packagePath" -ArgumentList $package.Arguments -wait -PassThru -ErrorAction Continue
        
        }
       

        # Did the process return an exit code 0 ?
        If ($process.exitcode -eq 0) {

            # write log file - Success
            Write-Log -Level INFO "installation completed with exitcode $($process.ExitCode)"

            # update package installation progress
            Add-Content $ProgressLogfile -Value ("$($package.Name) - Successful`n")

            } else {

            # write log file - failure
            write-log -Level ERROR -Message "installation completed with exit code $($process.ExitCode)"

            # increment script error counter
            $scriptError++

            # write log file - Failure
            Add-Content $ProgressLogfile -Value ("$($package.Name) - Failure`n")

            # Set Package Error Count
            New-ItemProperty -Path "HKLM:Software\CommunityHelper\PostInstall" -Name "PackageErrorCount" -Value $scriptError -PropertyType "String" -Force

            }
        }

        # Catch unknow exceptions
        catch{

        # write log file - failure
        Write-Log -Level ERROR -Message $_.Exception.Message

        # increment script error counter
        $scriptError++

        # write log file - Failure
        Add-Content $ProgressLogfile -Value ("$($package.Name) - Failure`n")

        # Set Package Error Count
        New-ItemProperty -Path "HKLM:Software\CommunityHelper\PostInstall" -Name "PackageErrorCount" -Value $scriptError -PropertyType "String" -Force

        }

    # Set PackageCountPercentage
    New-ItemProperty -Path "HKLM:Software\CommunityHelper\PostInstall" -Name "PackageCountPercentage" -Value ([math]::Round(($count/$packageList.Count)*100)) -PropertyType "String" -Force

    # increment count item
    $count++

    }


}


#################################################################################       Exception Catch      #################################################################################


catch{

 # write-log file
 Write-Log -Level ERROR -Message $_.Exception.Message

 # increment script error counter
 $scriptError++

 # Set Package Error Count
 New-ItemProperty -Path "HKLM:Software\CommunityHelper\PostInstall" -Name "PackageErrorCount" -Value $scriptError -PropertyType "String" -Force

 }


#################################################################################          Finally           #################################################################################


finally{

    # If no errors then run cleanup
    if ($error.Count -eq 0 -and $scripterror -eq 0) {

        # Clenup PostInstall directory
        # Remove-Item -Path  "$($env:SystemDrive)\Temp\PostInstall" -Recurse -Force  -ErrorAction Ignore

        # Set Status Flag
        New-ItemProperty -Path "HKLM:Software\CommunityHelper\PostInstall" -Name "Status" -Value ”Success” -PropertyType "String" -Force

        # Assign completed exit code
        Exit 0

        }else{

        # Set Status Flag
        New-ItemProperty -Path "HKLM:Software\CommunityHelper\PostInstall" -Name "Status" -Value ”Error” -PropertyType "String" -Force

        # Assign failed exit code
        Exit 1
    }
}
