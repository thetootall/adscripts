#Reference
#https://blogs.technet.microsoft.com/ashleymcglone/2017/08/31/new-improved-group-policy-link-report-with-powershell/

Mkdir c:\temp
CD /temp

Write-host "Please confirm windows PATH updates when installing script" -BackgroundColor Black -ForegroundColor Yellow
Install-Script -Name gPLinkReport -Force
gPLinkReport | Export-Csv -Path GPLinkReport.csv -NoTypeInformation

Import-Module ActiveDirectory
Import-Module GroupPolicy
$dc = Get-ADDomainController -Discover -Service PrimaryDC
$domain = (get-ADDomain).forest
Get-GPOReport -All -Domain $domain -Server $dc -ReportType HTML -Path C:\Temp\GPOReportsAll.html
