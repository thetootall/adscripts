#https://community.spiceworks.com/topic/1940442-add-bulk-proxyaddresses-attribute

#CSV MAP
#SamAccountName
#cblackb
Import-module ActiveDirectory

$users = Import-Csv "nomatch.csv"

ForEach ($Item in $users){
$thisuser = $item.("Object Name")
Write-host "Matching $thisuser" -ForegroundColor Yellow

#$myuser = Get-AdUser - $thisuser -properties givenname,sn
$myuser = Get-ADUser -Filter "UserPrincipalName -eq '$thisuser'"
$mysam = $myuser.samaccountname
$output = $mysam + "," + $thisuser
Write-host $output
$output | Out-file matchedinsource.csv -Append
}