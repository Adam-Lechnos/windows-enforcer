# Powershell script executed by first_run_enforcement_checks.bat

$TIMESTAMP = (get-date -f MM-dd-yyyy_HH-mm-ss)
$TEMPFOLDER= [System.Environment]::GetEnvironmentVariable('TEMP')
$LOGFILE = "$TEMPFOLDER\damo_net\logs\first-run-enforcement-powershell-$TIMESTAMP.log"

## enable auditing for all objects within the C:\damo_net folder
echo "* Audit Policy Enforcement *" | Out-File -FilePath $LOGFILE -Append
echo "** ensuring all objects are enabled for auditing in the 'C:\damo_net' folder **" | Out-File -FilePath $LOGFILE -Append
$MyAcl = Get-Acl -Path C:\damo_net -Audit
$FileSACL = [System.Security.AccessControl.FileSystemAuditRule]::new("Everyone","FullControl","ContainerInherit,ObjectInherit","None","Success,Failure")
$MyAcl.AddAuditRule($FileSACL)
Set-Acl -Path C:\damo_net -AclObject $MyAcl
echo $MyAcl | Out-File -FilePath $LOGFILE -Append
echo $FileSACL | Out-File -FilePath $LOGFILE -Append
$MyAcl.GetAuditRules | Out-File -FilePath $LOGFILE -Append
echo "* End Audit Policy Enforcement *" | Out-File -FilePath $LOGFILE -Append

echo "*End Script*" | Out-File -FilePath $LOGFILE -Append