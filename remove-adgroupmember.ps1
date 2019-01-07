$users=get-content "./users.txt"
foreach($user in $users){
    write-host "Checking $user for Aventail Membership"
    $memberdmz = (Get-ADGroupMember -Identity sxi-aventail-dmz).samaccountname -contains $users
    $memberdmz
    if ($memberdmz) { 
        write-host "Removing $user From sxi-aventail-dmz"
        remove-adgroupmember -Identity sxi-aventail-dmz -Member $user -Confirm:$false -Verbose
        }
    $member= (Get-ADGroupMember -Identity sxi-aventail-st).samaccountname -contains $users
    $member
    if ($member) {
        write-host "Removing $user From sxi-aventail"
        remove-adgroupmember -Identity SXI-Aventail-ST -Member $users -confirm:$false -verbose
        }
    }