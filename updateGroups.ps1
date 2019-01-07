
$groups = Import-Csv "c:\Temp\updateGroups.csv" 
ForEach ($Item in $groups)
{
$thisgroup = $item.("Group Name")
Write-host $thisgroup

Set-ADGroup -Identity $thisgroup -Add @{"msExchRequireAuthToSendTo"=$false}

} 
