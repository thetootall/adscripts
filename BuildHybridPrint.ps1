#Please visit https://github.com/thetootall/Imaging/blob/master/buildMDTenvironment.ps1 for current release, issues & more

#menu code: https://4sysops.com/archives/how-to-build-an-interactive-menu-with-powershell/
function Show-Menu
{
    param (
        [string]$Title = 'MDT Deployment'
    )
    Clear-Host
    Write-Host "================ $Title ================"
    
    Write-Host "1: Press '1' to downloading the Windows ADK and MDT bits."
    Write-Host "2: Press '2' to perform the MDT install."
    Write-Host "3: Press '3' to create the MDT folder structure."
    Write-Host "4: Press '4' to do absolutely nothing."
    Write-Host "5: Press '5' to initialize the MDT PS drive."
    Write-Host "6: Press '6' to create the MDT folder structure."
    Write-Host "7: Press '7' to update the Windows 10 boot WIM."
    Write-Host "8: Press '8' to refresh the MDT boot images."
    Write-Host "9: Press '9' to create a new Windows 10 deployment task sequence."
    Write-Host "Q: Press 'Q' to quit."
}



Write-host "This script will invoke the necessary commands to configure your MDT environment"

# Lax permissions on the share: https://deploymentresearch.com/Research/Post/613/Building-a-Windows-10-v1703-reference-image-using-MDT 
# Check for elevation
Write-Host "Checking for elevation"
 
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "Oupps, you need to run this script from an elevated PowerShell prompt!`nPlease start the PowerShell prompt as an Administrator and re-run the script."
    Write-Warning "Aborting script..."
    Break
}


do
 {
Show-Menu –Title 'MDT Deployment'
 $selection = Read-Host "Please make a selection"
 switch ($selection)
 {
    '1' {


Write-host "Creating download folder and pulling MDT toolkit from Microsoft servers"
$temp = "C:\temp\download"
New-Item -Path $temp -ItemType Directory -Verbose
$url="https://download.microsoft.com/download/3/3/9/339BE62D-B4B8-4956-B58D-73C4685FC492/MicrosoftDeploymentToolkit_x64.msi"
Start-BitsTransfer -Source $url -Destination $temp

$invokecmd = "cmd.exe /c start /wait msiexec.exe /I C:\temp\download\MicrosoftDeploymentToolkit_x64.msi /qb /norestart"
Invoke-Expression $invokecmd

# WAIK Docs
# https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install
# Steps we need to automate
Write-host "Please save the ADK installer under $temp, launching download" -BackgroundColor White -ForegroundColor Blue
Pause
Start-Process "iexplore" "https://go.microsoft.com/fwlink/?linkid=2026036"

Write-host "Please save the ADK PE addon under $temp, launching download" -BackgroundColor White -ForegroundColor Blue
Pause
Start-Process "iexplore" "https://go.microsoft.com/fwlink/?linkid=2022233"

# get the ADK for 1809 - https://go.microsoft.com/fwlink/?linkid=2026036
# get the PE addon - https://go.microsoft.com/fwlink/?linkid=2022233
# Additional Powershell Logic
# https://devblogs.microsoft.com/scripting/learn-how-to-use-powershell-to-automate-mdt-deployment/

Write-host "Once these files are downloaded you are ready to continue"
Pause

}
    '2' {

# This installs Windows Deployment Service
Import-Module ServerManager
add-WindowsFeature wds,wds-deployment, wds-transport, wds-adminpack

$wdsUtilResults = wdsutil /initialize-server /remInst:"C:\RemoteInstall"
$wdsUtilResults | select -last 1

# We need to fix some AD permissions
# We're prestaging machines similar to SCCM AD: https://scadminsblog.wordpress.com/2016/11/27/assigning-permissions-to-sccm-domain-join-account-with-powershell/
# But we have a problem for access rights: https://social.technet.microsoft.com/Forums/en-US/dbff853b-3c49-4551-a4b7-4e892decef2a
# Finding some base ACLs: https://devblogs.microsoft.com/scripting/use-powershell-to-explore-active-directory-security/

# This code is still theory on setting AD ACLs
If ($myaclblock -eq "TRUE"){
Set-Location AD:
$WDSComputer = Get-ADObject -Filter 'name -like $computer' -Properties *
(Get-Acl $WDSComputer).access | ft identityreference, accesscontroltype -AutoSize

$rootdse = Get-ADRootDSE
$domain = Get-ADDomain

$guidmap = @{ }
Get-ADObject -SearchBase ($rootdse.SchemaNamingContext) -LDAPFilter '0(schemaidguid=*)' -Properties lDAPDisplayName, schemaIDGUID |
	ForEach-Object{
		$guidmap[$_.lDAPDisplayName] = [System.GUID]$_.schemaIDGUID
	}

$ou = Get-ADOrganizationalUnit -Identity 'OU=New_Computers,OU=Edmentum,DC=ED,DC=LAN'
$oupath="AD:\$($ou.DistinguishedName)"
$sid=$WDSComputer.objectSid
$p = New-Object System.Security.Principal.SecurityIdentifier($sid)
$acl = Get-ACL $oupath
$ace=New-Object System.DirectoryServices.ActiveDirectoryAccessRule($p, 'WriteProperty,WriteDacl', 'Allow', 'Descendents', $guidmap['user'])
$acl.AddAccessRule($ace)
$acl|Set-ACL $oupath
# End Code block for ACLs
}

# WE cannotrun wdsutil configuration due to Access is denied errors
# $wdsClientResult = wdsutil /Set-Server /AnswerClients:All
# Set the key https://social.technet.microsoft.com/Forums/windows/en-US/f6ed133d-4029-4f45-8756-d062f34618df
# If It does not exist, New-ItemProperty  -PropertyType String
Write-host "Updating WDS registry keys"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WDSServer\Providers\WDSPXE\Providers\BINLSVC" -Name "netbootAnswerRequests" -Value "TRUE"
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\WDSSERVER\Providers\WDSPXE\Providers\BINLSVC" -Name "netbootAnswerOnlyValidClients" -Value "FALSE"
$ComputerOU = "CN=Computers,DC=ED,DC=LAN"
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\WDSSERVER\Providers\WDSPXE\Providers\BINLSVC" -Name "netbootNewMachineOU" -value $ComputerOU
Restart-Service WDSSERVER

Write-host "This process is downloading files from the internet, this may take a few moments" -BackgroundColor Red -ForegroundColor White
$invokeadk = "cmd.exe /c c:\temp\download\adksetup.exe /quiet /installpath c:\ADK /features OptionId.DeploymentTools"
Invoke-Expression $invokeadk

Write-host "This process is downloading files from the internet, this may take a few moments" -BackgroundColor Red -ForegroundColor White
$invokeadkaddon = "cmd.exe /c c:\temp\download\adkwinpesetup.exe"
Invoke-Expression $invokeadkaddon

}
    '3' {
# Initialize
Add-PSSnapIn Microsoft.BDD.PSSnapIn -ErrorAction SilentlyContinue

# Constants
$Computer = get-content env:computername
$FolderPath = "C:\DeploymentShare"
$ShareName = "DeploymentShare$"
$NetPath = "\\$Computer\DeploymentShare$"
$MDTDescription = "Deployment Share"

# Make MDT Directory
mkdir "$FolderPath"

# Create MDT Shared Folder
$Type = 0
$objWMI = [wmiClass] 'Win32_share'
$objWMI.create($FolderPath, $ShareName, $Type)

# Configure NTFS Permissions for the MDT Build Lab deployment share
# icacls $Folderpath /grant '"VIAMONSTRA\MDT_BA":(OI)(CI)(RX
Write-host "Updating folders and share permissions"
icacls $Folderpath /grant '"Administrators":(OI)(CI)(F)'
icacls $Folderpath /grant '"SYSTEM":(OI)(CI)(F)'
icacls "$FolderPath\Captures" /grant '"Everyone":(OI)(CI)(M)'
 
# Configure Sharing Permissions for the MDT Build Lab deployment share
Grant-SmbShareAccess -Name $ShareName -AccountName "EVERYONE" -AccessRight Change -Force
Revoke-SmbShareAccess -Name $ShareName -AccountName "CREATOR OWNER" -Force

}
    '5' {

Write-host "Loading MDT Virtual Drive as DS001" -BackgroundColor White -ForegroundColor Black
# Initialize
Add-PSSnapIn Microsoft.BDD.PSSnapIn -ErrorAction SilentlyContinue

# Constriants
$Computer = get-content env:computername
$FolderPath = "C:\DeploymentShare"
$ShareName = "DeploymentShare$"
$NetPath = "\\$Computer\DeploymentShare$"
$MDTDescription = "Deployment Share"

# Create PS Drive for MDT
new-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root "$FolderPath" -Description "$MDTDescription" -NetworkPath "$NetPath"  -Verbose | add-MDTPersistentDrive -Verbose

}
    '6' {

Write-host "Creating Folder Structure in MDT, please wait..." -BackgroundColor White -ForegroundColor Black
# Create OS Folders
$OSBUILD = "Windows 10 1803"
new-item -path "DS001:\Operating Systems" -enable "True" -Name $OSBUILD -Comments "" -ItemType "folder" -Verbose

# Create Driver Folders
new-item -path "DS001:\Out-of-Box Drivers" -enable "True" -Name "WinPE x86" -Comments "" -ItemType "folder" -Verbose
new-item -path "DS001:\Out-of-Box Drivers" -enable "True" -Name "WinPE x64" -Comments "" -ItemType "folder" -Verbose

new-item -path "DS001:\Out-of-Box Drivers" -enable "True" -Name "Windows 10" -Comments "" -ItemType "folder" -Verbose

new-item -path "DS001:\Out-of-Box Drivers\Windows 10" -enable "True" -Name "Dell Inc." -Comments "" -ItemType "folder" -Verbose

#Create Packages Folders
#new-item -path "DS001:\Packages" -enable "True" -Name "Language Packs" -Comments "" -ItemType "folder" -Verbose

# Create TS Folders
new-item -path "DS001:\Task Sequences" -enable "True" -Name "Windows 10" -Comments "" -ItemType "folder" -Verbose

# Create Application Folders
new-item -path "DS001:\Applications" -enable "True" -Name "Reference Applications" -Comments "" -ItemType "folder" -Verbose
new-item -path "DS001:\Applications" -enable "True" -Name "Core Applications" -Comments "" -ItemType "folder" -Verbose

# Create Selection Profiles
new-item -path "DS001:\Selection Profiles" -enable "True" -Name "WinPE x86" -Comments "" -Definition "<SelectionProfile><Include path=`"Out-of-Box Drivers\WinPE x86`" #/></SelectionProfile>" -ReadOnly "False" -Verbose
new-item -path "DS001:\Selection Profiles" -enable "True" -Name "WinPE x64" -Comments "" -Definition "<SelectionProfile><Include path=`"Out-of-Box Drivers\WinPE x64`" #/></SelectionProfile>" -ReadOnly "False" -Verbose

}
    '7' {
Write-host "Processing new Windows ISO import" -BackgroundColor White -ForegroundColor Black
# Import Windows 10 ISO
# Building the Path https://stackoverflow.com/questions/16452901/how-do-i-get-the-drive-letter-for-the-iso-i-mounted-with-mount-diskimage
# Reference: https://social.technet.microsoft.com/Forums/en-US/c242828b-58f5-4cc0-87e9-244f8e264b87/powershell-mdt-cmdlet-doesnt-seem-to-work-properly-when-invoked-as-background-job-or-maybe-its-me?forum=mdt
$ISOpath = Read-host "Please enter the path of your Windows Build ISO"
#In my lab it was located at: "C:\Windows 10 1803\Windows 10 1803 Updated 1-10-19.iso"
$mountResult = Mount-DiskImage $ISOPath -PassThru
$mountResult | Get-Volume
$driveLetter = ($mountResult | Get-Volume).DriveLetter
#$WimDestPath = "\\" + $computer + "\" + $driveletter + "$\sources\install.wim"
$WimDestPath = $driveletter + ":\sources\install.wim"

$DeploySharePath = $FolderPath
#$WimDestPath = "D:\install.wim"
$DestFolder = $OSBuild

Write-host "Importing the OS image into MDT"
Import-MDToperatingsystem -path "DS001:\Operating Systems\$DestFolder" -SourceFile $WimDestPath -DestinationFolder $DestFolder -Verbose
$OSCatalog = "DS001:\Operating Systems\$DestFolder\Windows 10 Enterprise in Windows 10 1803 install.wim"
Get-MDTOperatingSystemCatalog -ImageFile $oscatalog -Index 1

}
    '8' {
# Force an Update for the deployment Share
Write-host "Updating the MDT Deployment share, please wait...." -BackgroundColor White -ForeGroundColor Black
Update-MDTDeploymentShare -Path "DS001:" -Force -Verbose

# Import the boot images from MDT
Write-host "Removing old MDT images to WDS, please wait...." -BackgroundColor White -ForeGroundColor Black
Get-WdsBootImage | Remove-WdsBootImage
Write-host "Updating the x64 boot image" -BackgroundColor White -ForegroundColor Black
Import-WdsBootImage -Path $folderpath\Boot\LiteTouchPE_x64.wim -NewImageName "MDT Production x64" –SkipVerify -Verbose
Write-host "We are not using the x86 boot image in our environment, skipping" -BackgroundColor Yellow -ForegroundColor Black
#Import-WdsBootImage -Path $folderpath\Boot\LiteTouchPE_x86.wim -NewImageName "MDT Production x86" –SkipVerify -Verbose
#If we want to get more granular with cleanup, this takes it an extra step
#https://powershellpr0mpt.com/2017/01/04/automagically-update-your-mdt-boot-image/

}
    '9' {
# Create the task sequence
import-mdttasksequence -path "DS001:\Task Sequences\Windows 10" -Name "Install Windows 10" -Template "Client.xml" -Comments "" -ID "TS001" -Version "1.0" -OperatingSystemPath "DS001:\Operating Systems\Windows 10 1803\Windows 10 Enterprise in Windows 10 1803 install.wim" -FullName "Windows User" -OrgName "Test" -HomePage "about:blank" -AdminPassword "Password" -Verbose

}

     }
     pause
 }
 until ($selection -eq 'q')
