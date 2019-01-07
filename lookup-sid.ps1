$mysid = "S-1-5-21-3881197464-3378170926-3800815769-5830"

$objSID = New-Object System.Security.Principal.SecurityIdentifier ($mysid) 
$objUser = $objSID.Translate( [System.Security.Principal.NTAccount]) 
$objUser.Value