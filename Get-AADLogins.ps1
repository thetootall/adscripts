#Logs outout in the runtime location
$accesslog = "AADlogins.csv"

#log into AAD
try 
{ $var = Get-AzureADTenantDetail } 
catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] 
{ Write-Host "You're not connected - authenticating to Azure AD..." -ForegroundColor Black -BackgroundColor Yellow
Connect-AzureAD
}

#dump user array into new array with UPN
#this is a temp test pull of all users
$Cloudupns = Get-AzureADUser -Filter "userType eq 'Member' and accountEnabled eq true" -All $true

#check interactive logins against array
#date filter: https://www.ntweekly.com/2021/06/01/azure-ad-powershell-signins-report-for-user-login-location/

#$array = Get-AzureADAuditSignInLogs -Filter "createddatetime lt $setDate"

#Loop thru each user
foreach ($CloudUpn in $Cloudupns) {

    ##Get logs filtered by current guest
    $Azurelogs = Get-AzureADAuditSignInLogs -Filter "userprincipalname eq `'$($Cloudupn.userprincipalname)'" -ALL:$true 

    ##Check if multiple entries and tidy results
    if ($Azurelogs -is [array]) {
        $CloudTimestamp = $Azurelogs[0].createddatetime
    }
    else {
        $CloudTimestamp = $Azurelogs.createddatetime
    }

    ##Build Output Object
    $CloudObject = [PSCustomObject]@{

        Userprincipalname = $Cloudupn.userprincipalname
        accountEnabled = $Cloudupn.accountEnabled
	    accountType = "Cloud"
        LastSignin = $CloudTimestamp
        ObjectID = $Cloudupn.ObjectID
        AppsUsed = (($Azurelogs.resourcedisplayname | select -Unique) -join (';'))
    }

    ##Export Results
    Write-host $CloudObject
    $CloudObject | export-csv $accesslog -NoTypeInformation -Append
}
