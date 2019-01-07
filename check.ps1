$RemoteComputers = Import-csv wave-112118.csv
ForEach ($Item in $RemoteComputers)
{
Clear-Variable myvar*
$Computer = $item.("Object Name")
     Try
         {
             Write-host "Working with $Computer ...."

             $myvar1 = Invoke-Command -ComputerName $Computer -ScriptBlock {test-path "C:\Windows\CCM\SCClient.exe"} -ErrorAction SilentlyContinue
             #Write-host $myvar1
             If ($myvar1 -eq "True"){Write-host "$Computer has SCCM installed" -ForegroundColor Green}
             Else {Write-host "$Computer does NOT have SCCM installed" -ForegroundColor Yellow}

             $myvar2 = Invoke-Command -ComputerName $Computer -ScriptBlock {(Get-BitLockerVolume -MountPoint c:).ProtectionStatus}
             $myvar2a = $myvar2.value
             #Write-host $myvar2a
             If ($myvar2a -eq "On"){Write-host "$Computer has Bitlocker enabled" -ForegroundColor Green}
             ElseIf ($myvar2a -eq "Off"){Write-host "$Computer Bitlocker NOT protecting, is suspended" -ForegroundColor Yellow}

             $myvar3 = Get-Service -ComputerName $Computer SepMasterService -ErrorAction SilentlyContinue
             #Write-host $myvar3
             If ($myvar3 -ne $null){Write-host "$Computer has SEP installed" -ForegroundColor Green}
             ElseIf ($myvar3 -eq $null){Write-host "$Computer does NOT have SEP installed" -ForegroundColor Yellow}

             Write-host "------Ending $Computer"
         }
     Catch
         {
             Write-host "$Computer is not accessible"
         }
} 
