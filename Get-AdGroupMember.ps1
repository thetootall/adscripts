#Automated script for building the Azure Hybrid Print service in your environment
#By Chris Blackburn
#Follow updates and issues @ https://github.com/thetootall/adscripts/blob/master/Get-AdGroupMember.ps1
#Pulled from support from:
#https://serverfault.com/questions/532945/list-all-groups-and-their-members-with-powershell-on-win2008r2

Import-Module ActiveDirectory

$Groups = Get-AdGroup -filter *  | select name,objectguid

Foreach ($Group in $Groups) {
Write-host $Group.name

  $Arrayofmembers = Get-ADGroupMember -identity $Group.objectguid -recursive | select name,samaccountname,userprincipalname


  foreach ($Member in $Arrayofmembers) {
  $Table = @()

$Record = @{
  "Group Name" = ""
  "Name" = ""
  "Username" = ""
  "UPN" = ""
}
    $Record."Group Name" = $Group.name
    $Record."Name" = $Member.name
    $Record."UserName" = $Member.samaccountname
    Clear-Variable memberupn
    $memberupn = Get-ADUser $Member.samaccountname | select userprincipalname
    $Record."UPN" = $memberupn.userprincipalname
    $objRecord = New-Object PSObject -property $Record
    $Table += $objrecord
   $Table | export-csv "SecurityGroups.csv" -NoTypeInformation -append
  }
}

