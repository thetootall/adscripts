Dim argSPN, argUser, argComputer, spnToSearch, objCategory, strFilter, searchCategory, domainInput

Function Help()
Dim strMessage
strMessage = strMessage & "Usage:" & chr(13)
strMessage = strMessage & "For accurate results run this script from the IIS server or a member server in the same domain as IIS server." & chr(13)
strMessage = strMessage & "Check the article's failure scenarios and make sure no duplicate SPNs exist." & chr(13)
strMessage = strMessage & "cscript spnHelper.vbs /f:spn /spn:HTTP/www.test.com /user:mydomain\apppool1" & chr(13)
strMessage = strMessage & "cscript spnHelper.vbs /f:spn /spn:HTTP/www.test.com /computer:iis6server1" & chr(13)
strMessage = strMessage & "cscript spnHelper.vbs /f:user /user:mydomain\apppool1" & chr(13)
strMessage = strMessage & "cscript spnHelper.vbs /f:computer /computer:iis6server1" & chr(13)
strMessage = strMessage & "cscript spnHelper.vbs /f:duplicatespn /spn:HTTP/www.test.com" & chr(13)
strMessage = strMessage & "cscript spnHelper.vbs /f:requiredspn" & chr(13)
MsgBox strMessage,,"SPN Helper"
WScript.Quit
End Function

Function setArguments()
argSPN = lcase(WScript.Arguments.Named("spn"))
argUser =  lcase(WScript.Arguments.Named("user"))
argComputer = lcase(WScript.Arguments.Named("computer"))
searchCategory = lcase(WScript.Arguments.Named("f"))
if instr(argUser,"\")>0 then
domainInput = ",DC=" & split(argUser,"\")(0)
argUser = split(argUser,"\")(1)
end if
End Function

Function resetValues()
spnToSearch = ""
objCategory = ""
strFilter = ""
End Function

Function getGCPath()
Dim tempGCPath, objGC, tempGC, tempStr
Set objGC = GetObject("GC:")
for each tempGC in objGC
tempGCPath = tempGC.ADsPath
next
if tempGCPath <> "" then
getGCPath = tempGCPath
else
WScript.Echo "Unable to find active directory"
WScript.Quit
end if
For tempCounter=0 to UBound(split(lcase(split(getGCPath,"//")(1)),"."))
If tempCounter = UBound(split(lcase(split(getGCPath,"//")(1)),".")) Then tempSeperator="" else tempSeperator = ","
tempStr = tempStr & "DC=" & split(lcase(split(getGCPath,"//")(1)),".")(tempCounter) & tempSeperator
Next
getGCPath = tempGCPath & "/" & tempStr
End Function

Function getSPNClass()
Dim tempSPNClass
If trim(argSPN)="" Then getSPNClass = "*": Exit Function
If instr(argSPN,"/")=0 Then getSPNClass = "*": Exit Function
If instr(split(argSPN,"/")(0),"*")>0 Then getSPNClass = "*": Exit Function
getSPNClass = split(argSPN,"/")(0)
End Function

Function isSPNInputValid(spnIN)
isSPNInputValid = ""
If instr(spnIN,"/")=0 Then Exit Function
If instr(spnIN,"*")>0 Then Exit Function
isSPNInputValid = spnIN
End Function

Function Main()
Dim paramSPN
paramSPN = ""
call  resetValues()
call setArguments()
Select Case searchCategory
Case "spn"
if (argUser = "" and argComputer = "") or (argUser <> "" and argComputer <> "") then WScript.Echo "You must use /spn along with /computer or /user": WScript.Quit
if argSPN = "" then argSPN = "*"
spnToSearch = "(servicePrincipalName=" & argSPN & ")"
if argUser <> "" then objCategory = "(objectCategory=person)(sAMAccountName=" & argUser & ")"
if argComputer <> "" then 
objCategory = "(objectCategory=computer)(cn=" & argComputer & ")"
End If
strFilter = "(&" & spnToSearch & objCategory & ")"
Case "duplicatespn"
If isSPNInputValid(argSPN)="" Then WScript.Echo "Invalid SPN input. Please verify and try again.": WScript.Quit
spnToSearch = "(servicePrincipalName=" & argSPN & ")"
strFilter = spnToSearch
paramSPN = argSPN
Case "requiredspn"
call showRequiredSPNs("IIS")
WScript.Quit
Case "computer"
objCategory = "(&(objectCategory=computer)(cn=" & argComputer & "))"
strFilter = objCategory
Case "user"
objCategory = "(&(objectCategory=person)(sAMAccountName=" & argUser & "))"
strFilter = objCategory
Case else
call Help()
WScript.Quit
End Select
call getSPNs(paramSPN)
End Function

Function getPingResult(hostName,errorMessage)
'On Error Resume Next
getPingResult = ""
If instr(hostName,".")=0 Then
Dim tempGCPath, objGC, tempGC
Set objGC = GetObject("GC:")
for each tempGC in objGC
tempGCPath = tempGC.ADsPath
next
if tempGCPath <> "" then
gcPath = tempGCPath
else
WScript.Echo "Unable to find active directory"
WScript.Quit
end if
Set adConn = CreateObject("ADODB.Connection")
Set adCmd = CReateObject("ADODB.Command")
adConn.Provider = "ADsDSOObject"
adConn.Open "ADs Provider"
Set adCmd.ActiveConnection = adConn
adQuery = "<" + gcPath + ">;" & "(&(objectCategory=computer)(cn=" & hostName & "))" & ";dnsHostName;subtree"
'WScript.Echo adQuery
'WScript.Quit
adCmd.CommandText = adQuery
Set adRecordSet = adCmd.Execute
if adRecordSet.RecordCount>0 Then 
If IsNull(adRecordSet.Fields("dnsHostName"))=0 Then 
getPingResult = adRecordSet.Fields("dnsHostName") 
hostName = getPingResult 
Else 
getPingResult = hostName
End If
else 
errorMessage = "Could not find " & hostname & " in the active directory"
end if

Exit Function
End If
getPingResult = hostName
Exit Function
'If Err Then getPingResult = hostName
End Function

Function getSPNs(spn)
Dim spnClass, duplicateSPNArray
spnClass = getSPNClass()
duplicateSPNArray = ""
gcPath = getGCPath()
Set adConn = CreateObject("ADODB.Connection")
Set adCmd = CreateObject("ADODB.Command")
adConn.Provider = "ADsDSOObject"
adConn.Open "ADs Provider"
Set adCmd.ActiveConnection = adConn
adQuery = "<" + gcPath + domainInput + ">;" & strFilter & ";distinguishedName,objectCategory,dnsHostName,servicePrincipalName,sAMAccountName;subtree"
'WScript.Echo adQuery
'WScript.Quit
adCmd.CommandText = adQuery
Set adRecordSet = adCmd.Execute
if adRecordSet.EOF and adRecordSet.Bof Then
WScript.echo "No " & searchCategory & " found with the given criteria."
else
If adRecordSet.RecordCount>10 Then
If msgbox(adRecordSet.RecordCount & " Records are returned with the given criteria. Printing all of them might take a long time" & chr(13) & " Do you want to print all of them?",vbYesNo,"Kerberos")=vbNo Then Exit Function
End If
Do While not adRecordset.Eof
If Err Then Exit Do
WScript.echo "Class: " & split(split(adRecordSet.Fields("objectCategory"),",")(0),"=")(1)
WScript.Echo adRecordSet.Fields("distinguishedName")
if UCase(adRecordSet.Fields("objectCategory")) = "COMPUTER" Then
WScript.echo "Computer Name" & adRecordSet.Fields("dnsHostName")
else
WScript.echo "User Name: " & adRecordSet.Fields("samAccountName")
end if
if instr(searchCategory,"spn")>0 Then
spnCollection = adRecordSet.Fields("servicePrincipalName")
for each individualSPN in spnCollection
if spnClass="*" Then
WScript.Echo Chr(9) + individualSPN
else
Select Case searchCategory
Case "spn"
if Lcase(split(individualSPN,"/")(0)) = lcase(spnClass) Then
WScript.Echo Chr(9) + individualSPN
end if
Case "duplicatespn"
if Lcase(individualSPN) = lcase(spn) Then
duplicateSPNArray = duplicateSPNArray & Lcase(individualSPN) & " for " & split(split(adRecordSet.Fields("objectCategory"),",")(0),"=")(1) & ":" & adRecordSet.Fields("samAccountName") & Chr(29)
end if
Case "requiredspn"
End Select
End if
next
end if
WScript.Echo
adRecordSet.MoveNext
Loop
If searchCategory = "duplicatespn" Then
If UBound(Split(duplicateSPNArray,Chr(29)))>1 Then
WScript.Echo "Duplicate SPNs found"
For tempDuplicateCount=0 to UBound(Split(duplicateSPNArray,Chr(29)))-1
WScript.Echo Split(duplicateSPNArray,Chr(29))(tempDuplicateCount)
Next
End If
End If
WScript.Echo ""
If adRecordset.RecordCount>1 Then WScript.Echo "Found " & adRecordset.RecordCount & " accounts" Else WScript.Echo "Found " & adRecordset.RecordCount & " account"
end if
adRecordset.Close
adConn.Close
If Err Then MsgBox Err.Message
End Function

Function getCategoryCount(myFilterValue, myFilterCategory)
'This function accepts 2 parameters. First paramenter is the filter value and second param is filter category.
'If you want to pass in your own filter string with various categories, you can pass "" as the second param.
gcPath = getGCPath()
searchCategory = myFilterCategory
Select Case lcase(searchCategory)
Case "spn"
tempFilter = "(servicePrincipalName=" & myFilterValue & ")"
Case "user"
tempFilter = "(&(objectCategory=person)(sAMAccountName=" & myFilterValue & "))"
Case "computer"
tempFilter = "(&(objectCategory=computer)(cn=" & myFilterValue & "))"
Case else
tempFilter = myFilterValue
End Select
Dim tempCategoryCount
tempCategoryCount = 0
Set adConn = CreateObject("ADODB.Connection")
Set adCmd = CReateObject("ADODB.Command")
adConn.Provider = "ADsDSOObject"
adConn.Open "ADs Provider"
Set adCmd.ActiveConnection = adConn
adQuery = "<" + gcPath + domainInput + ">;" & tempFilter & ";objectCategory,dnsHostName,servicePrincipalName,sAMAccountName;subtree"
'WScript.Echo adQuery
'WScript.Quit
adCmd.CommandText = adQuery
Set adRecordSet = adCmd.Execute
if adRecordSet.EOF and adRecordSet.Bof Then
else
Do While not adRecordset.Eof
If Err Then Exit Do
if searchCategory = "spn" Then
spnCollection = adRecordSet.Fields("servicePrincipalName")
for each individualSPN in spnCollection
If lcase(individualSPN) = lcase(myFilterValue) Then
tempCategoryCount  = tempCategoryCount  + 1
End If
next
else
tempCategoryCount = tempCategoryCount + 1
end if   
adRecordSet.MoveNext
Loop
end if
getCategoryCount = tempCategoryCount
adRecordset.Close
adConn.Close
End Function

Function showRequiredSPNs(Product)
Select Case Product
Case "IIS"
If MsgBox("Is IIS running in a Cluster or NLB",vbYesNo)=vbYes Then 'Running in Cluster or NLB is true
strClusterName = InputBox("Enter the Cluster Name")
If strClusterName = "" Then WScript.Quit
If getPingResult(strClusterName,errorMessage)="" Then
If MsgBox(errorMessage & ". Do you want to continue?",vbYesNo)<>vbYes Then WScript.Quit
End If
strDomainAccount = InputBox("Enter the Domain Account that the application pool is running under")
If strDomainAccount = "" Then WScript.Quit
strRequiredSPN = "HTTP/" & strClusterName
If instr(strDomainAccount,"\") > 0 then
If getCategoryCount(split(strDomainAccount,"\")(1), "user")=0 Then
WScript.Echo "Domain account " & strDomainAccount & " does not exist"
WScript.Quit
End If
Else
If getCategoryCount(strDomainAccount, "user")=0 Then
WScript.Echo "Domain account " & strDomainAccount & " does not exist"
WScript.Quit
End If
End If
If getCategoryCount(strRequiredSPN, "spn")>0 Then
WScript.Echo "SPN " & " is already set. Use search option for finding the account that it is set for"
WScript.Quit
End If
WScript.Echo "You need to set the SPN " & strRequiredSPN & " for domain account " & strDomainAccount
Else
If MsgBox("Is IIS application pool running under domain account",vbYesNo)=vbYes Then 
strHostName = InputBox("Enter the hostname or host header or FQDN that you use to access the application")
If strHostName = "" Then WScript.Quit
If getPingResult(strHostName,errorMessage)="" Then
If MsgBox(errorMessage & ". Do you want to continue?",vbYesNo)<>vbYes Then WScript.Quit
End If
strDomainAccount = InputBox("Enter the Domain Account that the application pool is running under")
If strDomainAccount = "" Then WScript.Quit
If instr(strDomainAccount,"\") > 0 then
If getCategoryCount(split(strDomainAccount,"\")(1), "user")=0 Then
WScript.Echo "Domain account " & strDomainAccount & " does not exist"
WScript.Quit
End If
Else
If getCategoryCount(strDomainAccount, "user")=0 Then
WScript.Echo "Domain account " & strDomainAccount & " does not exist"
WScript.Quit
End If
End If
strRequiredSPN = "HTTP/" & strHostName
If getCategoryCount(strRequiredSPN, "spn")>0 Then
WScript.Echo "SPN " & strSPNRequired & " is already set. Use search option for finding the account that it is set for"
WScript.Quit
Else
WScript.Echo "You need to set SPN " & strRequiredSPN & " for domain account " & strDomainAccount
WScript.Quit
End If
Else
strHostName = InputBox("Enter the host header or FQDN that you use to access the application")
If strHostName = "" Then WScript.Quit
If getPingResult(strHostName,errorMessage)="" Then
If MsgBox(errorMessage & ". Do you want to continue?",vbYesNo)<>vbYes Then WScript.Quit
End If
If MsgBox("Are you accessing the application with netbios name or FQDN or CNAME alias of IIS server?",vbYesNo)=vbYes Then
strRequiredSPN = "host/" & strHostName
If getCategoryCount(strRequiredSPN, "spn")>0 Then
WScript.Echo "Required SPN " & strRequiredSPN & " is already set. Use search option for finding the account that it is set for"
WScript.Quit
Else
WScript.Echo "You need to set SPN " & strRequiredSPN & " for IIS server's netbios name"
WScript.Quit
End If
End If
strHostHeader = InputBox("Enter the host header that you use to access the application")
If strHostHeader = "" Then WScript.Quit
strRequiredSPN = "http/" & strHostHeader
If getCategoryCount(strSPNRequired, "spn")>0 Then
WScript.Echo "A required SPN " & strSPNRequired & " is already set. Use search option to find the account the SPN is set to. If the required SPN is found under a different account, remove and add it to the IIS server's machine account."
WScript.Quit
Else
WScript.Echo "You need to set SPN " & strRequiredSPN & " for IIS server's netbios name"
WScript.Quit
End If
End If

End If
Case Else
call Help()
End Select
End Function

call Main()
