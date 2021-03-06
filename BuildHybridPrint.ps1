#Automated script for building the Azure Hybrid Print service in your environment
#By Chris Blackburn
#Follow updates and issues @ https://github.com/thetootall/adscripts/blob/master/BuildHybridPrint.ps1
#Version 0.6 - Added menu of options and consistent startup experience
#Largely based on these blogs but thanks to all the others to help support it making this far:
#https://docs.microsoft.com/en-us/windows-server/administration/hybrid-cloud-print/hybrid-cloud-print-deploy-passthrough
#https://www.scconfigmgr.com/2018/01/22/deploy-hybrid-cloud-print
#http://calvreid.co.uk/2018/08/12/hybrid-cloud-print-deployment/

#menu code: https://4sysops.com/archives/how-to-build-an-interactive-menu-with-powershell/
function Show-Menu
{
    param (
        [string]$Title = 'Hybrid Print Deployment'
    )
    Clear-Host
    Write-Host "================ $Title ================"
    
    Write-Host "1: Press '1' to install IIS & Cloud printer package."
    Write-Host "2: Press '2' to install SSL certificate."
    Write-Host "3: Press '3' to install SQLite, Management Package, & update web.config."
    Write-Host "4: Press '4' to install The Azure Application Proxy Connector."
    Write-Host "5: Press '5' to configure Azure app registrations."
    Write-Host "Q: Press 'Q' to quit."
}

#Server Prep
Write-host "Reading Powershell version"
$version = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release)
$versionnum = $version.release

If ($versionnum -lt "461814"){
Write-host "Examining the .NET framework version to support newer versions of Azure cmdlets, please wait" -Backgroundcolor Yellow -Foregroundcolor Black
#How we determine build https://github.com/dotnet/docs/blob/master/docs/framework/migration-guide/how-to-determine-which-versions-are-installed.md
Write-host ".NET Framework 4.7.2 not installed, please allow for install & reboot" -BackgroundColor Yellow -ForegroundColor Black
$temp = "C:\temp\download"
$installername = "NDP472-KB4054530-x86-x64-AllOS-ENU.exe"
$installerpath = $temp + "\" +  $installername

New-Item -Path $temp -ItemType Directory -Verbose
Write-host "Installing the updated .NET framework to support newer versions of Azure cmdlets. This may reboot so please relaunch the script afterwards." -Backgroundcolor Yellow -Foregroundcolor Black
#found the installer http://forums.wsusoffline.net/viewtopic.php?f=6&t=7905&sid=1b70c08d201f1997004449c28bc3c348&start=10
$url = “https://download.microsoft.com/download/6/E/4/6E48E8AB-DC00-419E-9704-06DD46E5F81D/NDP472-KB4054530-x86-x64-AllOS-ENU.exe” #download path for SQLLite Tools
Start-BitsTransfer -Source $url -Destination $temp

$invokecmd = “cmd.exe /c $installerpath /q”
Invoke-Expression $invokecmd
}

If ($versionnum -eq "461814"){
#install new PS Module https://docs.microsoft.com/en-us/powershell/azure/install-az-ps?view=azps-1.6.0

If (!(Get-module "Az")) {
    Write-host ".NET Framework 4.7.2 IS installed, downloading the Az Powershell module" -BackgroundColor Yellow -ForegroundColor Black
    Install-Module Az
    Write-host "Loading the new Az module, please wait" -BackgroundColor Green -ForegroundColor Black
    Import-Module Az} Else { 
    Write-host "Loading the new Az module, please wait" -BackgroundColor Green -ForegroundColor Black
    Import-Module Az}

}

Write-host "Logging in to the new Az module, please enter credentials when prompted wait" -BackgroundColor Green -ForegroundColor Black
Connect-AzAccount

If (!(Get-module "AzureAd")) {
    Write-host "Downloading the Azure Powershell module" -BackgroundColor Yellow -ForegroundColor Black
    Install-Module AzureAD
    Write-host "Loading the Azure Powershell module, please wait" -BackgroundColor Green -ForegroundColor Black
    Import-Module AzureAD} Else { 
    Write-host "Loading the Azure Powershell module, please wait" -BackgroundColor Green -ForegroundColor Black
    Import-Module AzureAD}

Connect-AzureAD


#Prepopulate URLs
Write-host "Gathering tenant information, please wait" -BackgroundColor Green -ForegroundColor Black
$mytenant = Get-AzureADTenantDetail
$mytenantdomain = ($mytenant.VerifiedDomains).name -like "*onmicrosoft*" -notlike "*.mail.onmicrosoft.com*"
$mytenantdomain = [string]$mytenantdomain
$mytenantid = $mytenant.ObjectID


do
 {
Show-Menu –Title 'Hybrid Print Deployment'
 $selection = Read-Host "Please make a selection"
 switch ($selection)
 {
    '1' {
#Install Cloud Printer Package
Write-host "Loading Cloud Printer module, please wait" -BackgroundColor Green -ForegroundColor Black
Find-Module -Name "PublishCloudPrinter"
  
Install-Module -Name "PublishCloudPrinter"

Import-Module PublishCloudPrinter

cd 'C:\Program Files\WindowsPowerShell\Modules\PublishCloudPrinter\1.0.0.0'
.\CloudPrintDeploy.ps1 -AzureTenant $mytenantdomain -AzureTenantGuid $mytenantid -verbose
#Note that this may NOT install the services if there is an incorrect build of Windows Server 2016??

}
    '2' {
#Install SSL certificate
Write-host "Please ensure you have copied the PFX file to your server"
Pause
$certpath = Read-host "Please enter the full path to the PFX certificate:"
#in the lab I used: "C:\Temp\Cert\wildcard-pw-wild.pfx"
$password = Read-Host -Prompt "Enter password" -AsSecureString

$mycert = Get-PfxCertificate -FilePath $certpath
$mythumb = $mycert.Thumbprint

Import-PfxCertificate -FilePath $certpath -CertStoreLocation "Cert:\LocalMachine\My" -Password $password
#https://devblogs.microsoft.com/scripting/weekend-scripter-use-powershell-to-update-ssl-bindings/
Import-Module WebAdministration #Fixed error binding cert because module was not loaded
Get-Item IIS:\SslBindings\0.0.0.0!443 | Remove-Item
get-item -Path "cert:\LocalMachine\My\$mythumb" | new-item -path IIS:\SslBindings\0.0.0.0!443
}
    '3' {
#Install SQLite, Management Package, & update web.config"
Write-host "Installing SQL Lite...." -BackgroundColor Yellow -ForegroundColor Black
Register-PackageSource -Name nuget.org -ProviderName NuGet -Location https://www.nuget.org/api/v2/ -Trusted -Force
Install-Package system.data.sqlite -providername NuGet
#to uninstall: Uninstall-Package system.data.sqlite -providername NuGet
$sqlpak = Get-Package system.data.sqlite
$sqlver = $sqlpak.version

$SourcePath = "C:\Program Files\PackageManagement\NuGet\Packages"
$SQLiteVersion = $sqlver #The SQLLite version that you installed
$DesPath = "C:\inetpub\wwwroot\MopriaCloudService"

if (!(Test-Path "$DesPath\bin\x86")) {
    New-Item -Path "$DesPath\bin\x86" -ItemType Directory -Verbose
}
if (!(Test-Path "$DesPath\bin\x64")) {
    New-Item -Path "$DesPath\bin\x64" -ItemType Directory -Verbose
}
#Copy the x86 Interop Module
Copy-Item -Path "$SourcePath\System.Data.SQLite.Core.$SQLiteVersion\build\net46\x86\SQLite.Interop.dll" -Destination "$DesPath\bin\x86\SQLite.Interop.dll" -Force -Verbose
#Copy the x64 Interop module
Copy-Item -Path "$SourcePath\System.Data.SQLite.Core.$SQLiteVersion\build\net46\x64\SQLite.Interop.dll" -Destination "$DesPath\bin\x64\SQLite.Interop.dll" -Force -Verbose
Copy-Item -Path "$SourcePath\System.Data.SQLite.Core.$SQLiteVersion\lib\net46\System.Data.SQLite.dll" -Destination "$DesPath\bin\System.Data.SQLite.dll" -Force -Verbose
Copy-Item -Path "$SourcePath\System.Data.SQLite.Linq.$SQLiteVersion\lib\net46\System.Data.SQLite.Linq.dll" -Destination "$DesPath\bin\System.Data.SQLite.Linq.dll" -Force -Verbose
Copy-Item -Path "$SourcePath\System.Data.SQLite.EF6.$SQLiteVersion\lib\net46\System.Data.SQLite.EF6.dll" -Destination "$DesPath\bin\System.Data.SQLite.EF6.dll" -Force -Verbose

#download the Management Tool
Write-host "Downloading the SQLITE tools, please wait...." -BackgroundColor White -ForegroundColor Black
$temp = "C:\temp\download"
$extract = $temp + "\sqlite-tools"
$file = "sqlite-tools-win32-x86-3230000.zip"
$filepath = $temp + "\" + $file

New-Item -Path $temp -ItemType Directory -Verbose

$url = “https://www.sqlite.org/2018/sqlite-tools-win32-x86-3230000.zip” #download path for SQLLite Tools

Start-BitsTransfer -Source $url -Destination $temp

Expand-Archive -Path $filepath -DestinationPath $extract

cd “C:\inetpub\wwwroot\MopriaCloudService\Database”

$installer = “\sqlite3.exe”

$installpath = $extract + “\sqlite-tools-win32-x86-3230000” + $installer

#How to run in Powershell – Start-Process
#https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process?view=powershell-6

$invokecmd = “cmd.exe /c $installpath MopriaDeviceDb.db ‘.read MopriaSQLiteDb.sql'”
Invoke-Expression $invokecmd
Write-host "Please Update SQLite references in the web.config to $sqlver" -BackgroundColor Red -ForegroundColor white
Start-Process "notepad" "C:\inetpub\wwwroot\MopriaCloudService\web.config"
Write-host "When you're ready, press Enter" -BackgroundColor Red -ForegroundColor white
Pause
}
    '4' {
#Install The Azure Application Proxy Connector
Write-host "Please install the Application Proxy Service Connector now." -BackgroundColor Yellow -ForegroundColor Black 
Start-Process "iexplore" "https://portal.azure.com/#blade/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/AppProxy"

Write-host "When you're ready, press Enter" -BackgroundColor Red -ForegroundColor white
Pause
}
    '5' {
#Configure Azure app registrations''
#Reference https://docs.microsoft.com/en-us/windows-server/administration/hybrid-cloud-print/hybrid-cloud-print-overviewd

#Gather Tenant Information
$domain = Read-host "Enter domain name for Hybrid Print services"

$cldsvcdisc = "Hybrid Cloud Print Discovery Endpoint"
$cldwebapp = "Hybrid Cloud Print Proxy Endpoint"
$cldnative = "Hybrid Cloud Print Native App"

$cldsvcdiscURL = "http://MopriaDiscoveryService/CloudPrint"
$cldwebappURL = "http://MicrosoftEnterpriseCloudPrint/CloudPrint"

$urlsvcdisc = "https://mcs." + $domain + "/mcs/"
$urlwebapp = "https://ecp." + $domain + "/ecp/"

Write-host "Building Discovery URL as $urlsvcdisc" -BackgroundColor Yellow -ForegroundColor Black 
Write-host "Building Proxy URL as $urlwebapp" -BackgroundColor Yellow -ForegroundColor Black 

Write-host "Please ensure both domains exist inside of your DNS services prior to creation - or they will fail" -BackgroundColor Red -ForegroundColor White
Write-host "When you're ready, press Enter" -BackgroundColor Red -ForegroundColor white
Pause

#start Native App Build
$azureendpointbuild = Read-host "Please acknowledge Y if you're ready to create the Endpoints"
If ($azureendpointbuild -eq "Y"){
#Setup the Discovery Endpoint First
Write-host "Creating Discovery Endpoint, please wait"  -BackgroundColor White -ForegroundColor Black
Write-host "$cldsvcdisc endpoint URL: $urlsvcdisc"
New-AzureADApplicationProxyApplication -DisplayName $cldsvcdisc -ExternalUrl $urlsvcdisc -InternalUrl $urlsvcdisc -ExternalAuthenticationType Passthru

$azureID1 = Get-AzureADApplication | ?{$_.displayname -like $cldsvcdisc}
$azureobj1 = $azureID1.objectID
$azureapp1 = $azureID1.appid

$azureID1 | Set-AzureADApplication -IdentifierUris $clddvcdiscURL
$azureID1.IdentifierUris

#Setup the Proxy Endpoint Second
Write-host "Creating Proxy Endpoint, please wait"  -BackgroundColor White -ForegroundColor Black
Write-host "$cldwebapp endpoint URL: $urlwebapp"
New-AzureADApplicationProxyApplication -DisplayName $cldwebapp -ExternalUrl $urlwebapp -InternalUrl $urlwebapp -ExternalAuthenticationType Passthru

$azureID2 = Get-AzureADApplication | ?{$_.displayname -like $cldwebapp}
$azureobj2 = $azureID2.objectID
$azureapp2 = $azureID2.appid

$azureID2 | Set-AzureADApplication -IdentifierUris $cldwebappURL
$azureID2.IdentifierUris

}
#End Endpoint creation

#start Native App Build
$azureappbuild = Read-host "Please acknowledge Y if you're ready to create the Native Apps"
If ($azureappbuild -eq "Y"){
#Configure Native App
$azureURL3var = "ms-appx-web://Microsoft.AAD.BrokerPlugin/S-1-15-2-3784861210-599250757-1266852909-3189164077-45880155-1246692841-283550366"

#Creating a native App https://stackoverflow.com/questions/51376242/azure-ad-application-register-how-to-provide-application-type-when-registeri
Write-host "Creating Native App, please wait"  -BackgroundColor White -ForegroundColor Black
New-AzureADApplication -DisplayName $cldnative -ReplyUrls $azureURL3var -PublicClient $true

$azureID3 = Get-AzureADApplication | ?{$_.displayname -like $cldnative}

$azureobj3 = $azureID3.objectID
$azureapp3 = $azureID3.appid
$azureURL3id = "ms-appx-web://Microsoft.AAD.BrokerPlugin/" + $azureapp3

$azureURL3 = New-Object System.Collections.ArrayList
$azureURL3 = $azureID3.ReplyURLs
$azureURL3.Add($azureURL3id)

Set-AzureADApplication -ObjectId $azureobj3 -ReplyUrls $AzureURL3

$azureApp3 = Get-AzureADServicePrincipal -All $True | ?{$_.displayname -like $cldnative}
$azapp3 = Get-AzADApplication  | ?{$_.displayname -like $cldnative}
$azapp3ojb = $azapp3.ObjectId
$azapp3app = $azapp3.ApplicationID
$azapp3url = "https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/CallAnAPI/appId/" + $azapp3app + "/objectId/" + $azapp3ojb + "/isMSAApp/"

Write-host "Please add the Endpoint with permissions directly in the Azure portal"

Start-Process "iexplore" "$azapp3url"

Pause
}
#Future improvement = write API permissions directly
#assign application permissions https://stackoverflow.com/questions/42164581/how-to-configure-a-new-azure-ad-application-through-powershell/42166700
#https://techcommunity.microsoft.com/t5/Azure-Developer-Community-Blog/DevOps-trick-8211-Provision-Azure-Active-Directory-Apps-in-a/ba-p/336760
#Install-Script -Name Grant-AzureApiAccess

#Update Registry
#https://blog.netwrix.com/2018/09/11/how-to-get-edit-create-and-delete-registry-keys-with-powershell/

Write-host "Updating Mopria service URL in the registry as $urlwebapp" -BackgroundColor Yellow -ForegroundColor Black
Set-Itemproperty -path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudPrint\MopriaDiscoveryService' -Name 'URL' -value $urlwebapp
(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CloudPrint\MopriaDiscoveryService' -Name 'URL') | select URL

#Create the Intune Policy


#Create the Printer
}

     }
     pause
 }
 until ($selection -eq 'q')
