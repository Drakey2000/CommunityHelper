# Load Microsoft.SMS.TSEnvironment
$TSEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment
 
# Get Task Sequence variables - Ordered not being retained with Import-Clixml
$SMSEnv = [ordered]@{
           
            'Boot Image ID' = $TSEnv.Value('_SMSTSBootImageID')
            'Install Updates' = $TSEnv.Value('SMSInstallUpdateTarget')
            'Launch Mode' = $TSEnv.Value('_SMSTSLaunchMode')
            'Local Cache' = $TSEnv.Value('_SMSTSClientCache')
            'Managament Point' = $TSEnv.Value('_SMSTSMP')
            'Media Type' = $TSEnv.Value('_SMSTSMediaType')
            'Peer Mode Enabled' = $TSEnv.Value('SMSTSPeerDownload')
            'Run from DP' = $TSEnv.Value('_SMSTSRunFromDP')
            'Site Code' = $TSEnv.Value('_SMSTSSiteCode')
            'Task Sequence ID' = $TSEnv.Value('_SMSTSAdvertID')
            'Task Sequence Name' = $TSEnv.Value('_SMSTSPackageName')
             'UEFI Mode' = $TSEnv.Value('_SMSTSBootUEFI')
}

# Export-Clixml to read ouside of Microsoft.SMS.TSEnvironment
$SMSEnv | Export-Clixml -Path "$env:SystemRoot\Temp\OSDReport\TSEnv.xml" 
