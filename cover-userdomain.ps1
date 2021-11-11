Connect-AzureAD
  
$Path = "OU=Users,DC=corp,DC=northwinds,DC=com"
$Domain = "@northwinds.com" 

$Users = Get-ADUser -SearchBase $Path -Filter "UserPrincipalName -like '*@contoso.com" -Properties * -ResultSetSize $null 

$UsersToSkip = @( 
    'mona.smith@northwinds.com' 
   , 'ronald.doe@northwinds.com' 
) 

$Users | foreach { 
If ($UsersToSkip –NotContains $_.UserPrincipalName) {  
  $_.UserPrincipalName 
   $NewEmailAddr = $_.GivenName + "." + $_.Surname + $Domain 
   $NewEmailAddr = $NewEmailAddr.Replace("'", "") 
   $NewEmailAddr = $NewEmailAddr.Replace("é", "e") 
   $NewEmailAddr = $NewEmailAddr.Replace(" ", "") 
   $NewEmailAddr 

   # Remove old sip and primary SMTP values        
   $_ | Set-AdUser -Remove @{ProxyAddresses="sip:" + $_.UserPrincipalName} 
   $_ | Set-AdUser -Remove @{ProxyAddresses="SMTP:" + $_.UserPrincipalName} 

   # Add old email address back as an alias, setup primary SMTP and sip addresses 
   $_ | Set-AdUser -Add @{ProxyAddresses="smtp:" + $_.UserPrincipalName} 
   $_ | Set-AdUser -Add @{ProxyAddresses="SMTP:" + $NewEmailAddr} 
   $_ | Set-AdUser -Add @{ProxyAddresses="sip:" + $NewEmailAddr} 

   # Update email address and UPN 
   $_ | Set-AdUser -EmailAddress $NewEmailAddr -UserPrincipalName $NewEmailAddr 

   # Update UPN in Azure AD 
   Set-AzureAdUser -ObjectId $_.UserPrincipalName -UserPrincipalName $NewEmailAddr 
} 
} 

Disconnect-AzureAD
