############## 

# Inspired from the Technet Gallery post below but updated to find the correct NICs and show current DNS 
# https://gallery.technet.microsoft.com/scriptcenter/Change-DNS-ip-addressess-912954b2/view/Discussions
 
############## 
 
$Computerlist = get-content "servers.txt"
$DNSservers =@("10.10.100.70","10.10.100.80") 
 
foreach ($computername in $computerlist) { 
    $result =  get-wmiobject win32_pingstatus -filter "address='$computername'" 
    if ($result.statuscode -eq 0) { 
        $remoteNic = get-wmiobject -class win32_networkadapter -computer $computername | where-object {$_.netconnectionID -like "*Ethernet*"} 
        $index = $remotenic.index 
        $DNSlist = $(get-wmiobject win32_networkadapterconfiguration -computer $computername -Filter ‘IPEnabled=true’ | where-object {$_.index -eq $index}).dnsserversearchorder 
        $priDNS = $DNSlist | select-object -first 1 
        Write-host "Changing DNS IP's on $computername" -b "Yellow" -foregroundcolor "black" 
        Write-host "Current DNS IPs on $computername are $DNSlist" -b DarkYellow -ForegroundColor "Black"
        $change = get-wmiobject win32_networkadapterconfiguration -computer $computername | where-object {$_.index -eq $index} 
        $change.SetDNSServerSearchOrder($DNSservers) | out-null 
        $changes = $(get-wmiobject win32_networkadapterconfiguration -computer $computername -Filter ‘IPEnabled=true’ | where-object {$_.index -eq $index}).dnsserversearchorder 
        Write-host "$computername's Nic1 Dns IPs $changes" 
    } 
    else { 
        Write-host "$Computername is down cannot change IP address" -b "Red" -foregroundcolor "white" 
    } 
}
