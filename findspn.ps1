#based on the script at 
#http://social.technet.microsoft.com/wiki/contents/articles/18996.list-all-spns-used-in-your-active-directory.aspx
#This version fixes some output issues as well as builds in output to a txt file for searching

Set-ExecutionPolicy Unrestricted -force
#Set Search
cls
$search = New-Object DirectoryServices.DirectorySearcher([ADSI]“”)
$search.filter = “(servicePrincipalName=*)”
$results = $search.Findall()

#set local file name
$filename = "allupn.txt"

#list results
foreach($result in $results)
{
	$userEntry = $result.GetDirectoryEntry()
	$line0 = "---------------------"
	Write-Host $line0
	$line0 | Out-file -filepath $filename -append
	$head1 =  "Object Name = " 
	$line1 = $head1 + $userEntry.name
	Write-host $line1 -foreground Black -background Yellow
	$line1 | Out-file -filepath $filename -append
	$head2 =  "DN = "
	$line2 = $head2 + $userEntry.distinguishedName
	Write-host $line2
	$line2 | Out-file -filepath $filename -append
	$head3 = "Object Cat = "
	$line3 = $head3 + $userEntry.objectCategory
	Write-host $line3
	$line3 | Out-file -filepath $filename -append
	$line4 = "servicePrincipalNames"
	Write-host $line4
	$line4 | Out-file -filepath $filename -append
	$line5 = "---------------------"
	Write-host $line5
	$line5 | Out-file -filepath $filename -append
	$i=1
	foreach($SPN in $userEntry.servicePrincipalName)
		{
		$line6 = $SPN
		Write-host $line6
		$line6 | Out-file -filepath $filename -append
		}
} 
