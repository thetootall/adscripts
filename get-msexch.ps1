#https://community.spiceworks.com/topic/1940442-add-bulk-proxyaddresses-attribute

#CSV MAP
#SamAccountName
#cblackb
Import-module ActiveDirectory

$users = Import-Csv "prepareerrorlist.csv"

ForEach ($Item in $users){
$thisuser = $item.("Object Name")
Write-host "Matching $thisuser" -ForegroundColor Yellow

#$myuser = Get-AdUser $thisuser -properties givenname,sn,msExchRecipientTypeDetails
$myuser = Get-ADUser -Filter "UserPrincipalName -eq '$thisuser'" -properties givenname,sn,msExchRecipientTypeDetails
$mysam = $myuser.samaccountname
$mytype = $myuser.msExchRecipientTypeDetails
$output = $mysam + "," + $thisuser + "," + $mytype
Write-host $output
$output | Out-file prepareerrorvalues.csv -Append
}