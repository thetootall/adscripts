Import-module AzureAD
connect-azuread
$myuser = Read-host “Enter user’s UPN”
$userid = (Get-AzureADUser | ?{$_.UserPrincipalname -match $myuser}).ObjectID
Revoke-AzureADUserAllRefreshToken -ObjectId $userid
#reference: https://scomandothergeekystuff.com/2019/08/27/forcefully-revoke-azure-ad-user-session-access-immediately/
