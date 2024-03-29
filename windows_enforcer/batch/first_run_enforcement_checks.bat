@echo off
setlocal enabledelayedexpansion

set user="%username%"
set usertest="%COMPUTERNAME%$"

:: prevent manual run post bootstrapping. Only system account may run the process when the bootstrap file exist.
if exist "C:\<DOMAIN>\windows_enforcer\batch\bootstrap_success.txt" if not "%user%" == "%usertest%" (
	echo "This script may not be executed manually after bootstrapping, exiting in 20 seconds."
	timeout /t 20
	exit
	)

set TIMESTAMP=%DATE:/=-%_%TIME::=-%
set TIMESTAMP=%TIMESTAMP: =%
set LOGFILE=%temp%\<DOMAIN>\logs\first-run-enforcement-%TIMESTAMP%.log

:: Client side folder/file structure enforcement to prevent conflict/errors. NAS copyting takes precedence.
if not exist %temp%\<DOMAIN>\logs\ (mkdir %temp%\<DOMAIN>\logs\)
if not exist %temp%\<DOMAIN>\trusted-root-certificates (mkdir %temp%\<DOMAIN>\trusted-root-certificates)
if not exist C:\<DOMAIN>\windows_enforcer\batch\install-removal (mkdir C:\<DOMAIN>\windows_enforcer\install-removal)
if not exist C:\<DOMAIN>\scripts (mkdir C:\<DOMAIN>\scripts)
if not exist C:\<DOMAIN>\windows_enforcer\batch\winget-installs.txt (echo. 2>C:\<DOMAIN>\windows_enforcer\batch\winget-installs.txt)
if not exist C:\<DOMAIN>\windows_enforcer\batch\winget-uninstalls.txt (echo. 2>C:\<DOMAIN>\windows_enforcer\batch\winget-uninstalls.txt)
if not exist C:\<DOMAIN>\windows_enforcer\batch\github-release-install.txt (echo. 2>C:\<DOMAIN>\windows_enforcer\batch\github-release-install.txt)
if not exist C:\<DOMAIN>\windows_enforcer\batch\github-raw-installs.txt (echo. 2>C:\<DOMAIN>\windows_enforcer\batch\github-raw-installs.txt)
if not exist C:\<DOMAIN>\windows_enforcer\batch\github-release-install.txt (echo. 2>C:\<DOMAIN>\windows_enforcer\batch\github-release-install.txt)
if not exist C:\<DOMAIN>\windows_enforcer\batch\install-removal\installed.txt (echo. 2>C:\<DOMAIN>\windows_enforcer\batch\install-removal\installed.txt)
if not exist C:\<DOMAIN>\windows_enforcer\batch\install-removal\install_desired.txt (echo. 2>C:\<DOMAIN>\windows_enforcer\batch\install-removal\install_desired.txt)

:: Check dependencies
winget -v
if not errorlevel 0 (
	echo "*** Dependency Check - Winget not installed. Install 'App Installer' from the Microsoft Store for winget install feature ***" >> %LOGFILE%
	exit
)

:: Main entry point for running enforcement and syncing data for <DOMAIN> admin settings. Never rename or delete this file.

:: check if on <DOMAIN> workgroup (router name must match)
echo "checking if on proper <DOMAIN> workgroup" >> %LOGFILE%
:: copy and paste the below 2 lines for each network, updating the FQDN of the router hostname and IP and updating the integer value for neterror array
ping -n 1 <ROUTER IP> | find "TTL" && ping -n 1 -a <ROUTER IP> | find "<ROUTER HOSTNAME>" && ipconfig | find "<DOMAIN>"
set neterror[0]=%errorlevel%

:: loop through all error levels assinged to array and find a 0. Update the third number to number of home networks being checked minus 1.
for /L %%n in (0,1,0) do (
	echo !neterror[%%n]! >> %LOGFILE%
	if !neterror[%%n]!==0 (goto start)
	)

:: exit with message if no 0 error levels found
echo "** <DOMAIN> home network not detected, exiting **" >> %LOGFILE%
exit

:start
echo "** <DOMAIN> workgroup detected, continuing... **" >> %LOGFILE%
:: copy itself if file does not exist in designated location
if not exist C:\<DOMAIN>\windows_enforcer\first_run_enforcement_checks.bat (
	echo "first run enforcement script does not exist, copying and executing remaining enforcement checks" >> %LOGFILE%
	mkdir C:\<DOMAIN>\windows_enforcer
	copy "%~f0" C:\<DOMAIN>\windows_enforcer\first_run_enforcement_checks.bat
)

:: peform file sync from designated NAS folder attempting to map the correct drive letter if it does not exist
echo running robo copy from central NAS enforcement folder to ensure latest files are being used >> %LOGFILE%
:: check if drive is mapped, if not, ping NAS, if fails, skip, otherwise, re-map
if not exist Z:\ (
	echo "*** mapped drive not found, pinging NAS ***" >> %LOGFILE%
	:: use IP of NAS device
	ping -n 1 <ROUTER IP> | find "TTL"
	if not errorlevel 1 (
		echo re-mapping NAS, ping responded >> %LOGFILE%
		goto resync
	) else (
		echo "*** cannot ping NAS, either down or off the network ***" >> %LOGFILE%
		echo "*** will attempt remaining enforcement tasks, which will fail if at least one sync has not occured ***" >> %LOGFILE%
	) 
) else (
	if exist Z:\<DOMAIN>\windows_enforcer\batch\first_run_enforcement_checks.bat (
		goto resync
	) else (
		echo "*** Z drive mapping is incorrect. Un-map existing Z drive, then try again ***" >> %LOGFILE%
	)
)

:resync
echo "** syncing files with NAS enforcement folder **" >> %LOGFILE%
:: sync scripts
robocopy C:\test\ C:\<DOMAIN>\ /MIR /Z /XD .git /XF bootstrap_success.txt last-runs-check.sh cert-check.sh >> %LOGFILE%
:: sync trusted root certificates
robocopy C:\test\trusted-root-certificates %temp%\<DOMAIN>\trusted-root-certificates /MIR  >> %LOGFILE%

echo "*tamper protection*" >> %LOGFILE%
:: lock down local C:\scripts directory and all child objects
echo "**locking down C:\<DOMAIN>\ directory**" >> %LOGFILE%
icacls C:\<DOMAIN>\ /reset /q /c /t >> %LOGFILE%
icacls C:\<DOMAIN>\ /inheritance:d >> %LOGFILE%
icacls C:\<DOMAIN>\ /setowner "Administrators" /q /c /t >> %LOGFILE%
icacls C:\<DOMAIN>\ /remove:g "Users" /q /c /t >> %LOGFILE%
icacls C:\<DOMAIN>\ /remove:g "Authenticated Users" /q /c /t >> %LOGFILE%
icacls C:\<DOMAIN>\ /grant "Users":(R) /q /c /t >> %LOGFILE%
:: remove delete permissions for this and the jumpstarter scripts and their task scheduler xmls from the Administrators group
icacls C:\<DOMAIN>\windows_enforcer\batch\first_run_enforcement_checks.bat /inheritance:d >> %LOGFILE%
icacls C:\<DOMAIN>\windows_enforcer\batch\first_run_enforcement_checks.bat /remove:g "Administrators" /q /c >> %LOGFILE%
icacls C:\<DOMAIN>\windows_enforcer\batch\first_run_enforcement_checks.bat /remove:g "Users" /q /c >> %LOGFILE%
icacls C:\<DOMAIN>\windows_enforcer\batch\first_run_enforcement_checks.bat /setowner "SYSTEM" /q /c >> %LOGFILE%
icacls C:\<DOMAIN>\windows_enforcer\powershell\first_run_enforcement-powershell.ps1 /inheritance:d >> %LOGFILE%
icacls C:\<DOMAIN>\windows_enforcer\powershell\first_run_enforcement-powershell.ps1 /remove:g "Administrators" /q /c >> %LOGFILE%
icacls C:\<DOMAIN>\windows_enforcer\powershell\first_run_enforcement-powershell.ps1 /remove:g "Users" /q /c >> %LOGFILE%
icacls C:\<DOMAIN>\windows_enforcer\powershell\first_run_enforcement-powershell.ps1 /setowner "SYSTEM" /q /c >> %LOGFILE%
icacls "C:\<DOMAIN>\windows_enforcer\batch\First Run Enforcement Checks.xml" /inheritance:d >> %LOGFILE%
icacls "C:\<DOMAIN>\windows_enforcer\batch\First Run Enforcement Checks.xml"  /remove:g "Administrators" /q /c >> %LOGFILE%
icacls "C:\<DOMAIN>\windows_enforcer\batch\First Run Enforcement Checks.xml"  /remove:g "Users" /q /c >> %LOGFILE%
icacls "C:\<DOMAIN>\windows_enforcer\batch\First Run Enforcement Checks.xml"  /setowner "SYSTEM" /q /c >> %LOGFILE%
icacls "C:\<DOMAIN>\windows_enforcer\batch\jumpstart.bat" /inheritance:d >> %LOGFILE%
icacls "C:\<DOMAIN>\windows_enforcer\batch\jumpstart.bat" /remove:g "Administrators" /q /c >> %LOGFILE%
icacls "C:\<DOMAIN>\windows_enforcer\batch\jumpstart.bat" /remove:g "Users" /q /c >> %LOGFILE%
icacls "C:\<DOMAIN>\windows_enforcer\batch\jumpstart.bat" /setowner "SYSTEM" /q /c >> %LOGFILE%
icacls "C:\<DOMAIN>\windows_enforcer\batch\jumpstarter.xml" /inheritance:d >> %LOGFILE%
icacls "C:\<DOMAIN>\windows_enforcer\batch\jumpstarter.xml" /remove:g "Administrators" /q /c >> %LOGFILE%
icacls "C:\<DOMAIN>\windows_enforcer\batch\jumpstarter.xml" /remove:g "Users" /q /c >> %LOGFILE%
icacls "C:\<DOMAIN>\windows_enforcer\batch\jumpstarter.xml" /setowner "SYSTEM" /q /c >> %LOGFILE%
:: ensure adminn access to the scripts folder
icacls C:\<DOMAIN>\scripts\ /reset /q /c /t >> %LOGFILE%
icacls C:\<DOMAIN>\scripts\ /inheritance:d >> %LOGFILE%
icacls C:\<DOMAIN>\scripts\ /setowner "Administrators" /q /c /t >> %LOGFILE%
icacls C:\<DOMAIN>\scripts\ /grant "Administrators":(F) /q /c /t >> %LOGFILE%
icacls C:\<DOMAIN>\scripts\ /remove:g "Users" /q /c /t >> %LOGFILE%
icacls C:\<DOMAIN>\scripts\ /grant "Users":(R) /q /c /t >> %LOGFILE%
icacls C:\<DOMAIN>\scripts\ /remove:g "Authenticated Users" /q /c /t >> %LOGFILE%
icacls C:\<DOMAIN>\scripts\ /grant "Authenticated Users":(R) /q /c /t >> %LOGFILE%
:: break-glass enable admin permissions to take control of the locked down file
@REM icacls C:\<DOMAIN>\windows_enforcer\batch\first_run_enforcement_checks.bat /grant "Administrators":(RX) /q /c >> %LOGFILE%

:: locking down task scheduler - prevent deletion
@REM reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\Task Scheduler5.0" /v "Task Deletion" /t REG_DWORD /d 0 /f

:: remove all certs before installing for hosts opted into force cert refresh list with flag set to ON
if exist C:\<DOMAIN>\windows_enforcer\batch\featureFlags-first-run_enforcement_checks\certificate-refresh_FORCE_renameMe-ON.txt (
	FOR /F "tokens=* USEBACKQ" %%F IN (`hostname`) DO (
    SET hostname=%%F
	  findstr /r /s /i /m /c:"\<!hostname!\>" "C:\<DOMAIN>\windows_enforcer\batch\featureFlags-first-run_enforcement_checks\certificate-refresh_FORCE_renameMe-ON.txt"
	  if not errorlevel 1 (
		  echo 'feature flag for force cert refresh active with local host opted in. removing trusted root certificates listed in force list before installing' >> %LOGFILE%
		  for /F "tokens=*" %%A in (C:\<DOMAIN>\windows_enforcer\batch\featureFlags-first-run_enforcement_checks\certificate-refresh_FORCE_LIST.txt) do certutil.exe -delstore root %%A && echo ** Removed Cert Name: %%A **  >> %LOGFILE%
	  )  
  )
)

:: remove certs within revokation list
if exist C:\<DOMAIN>\windows_enforcer\batch\cert-removal\cert-revoked.txt (
	echo "applying cert revocation for certs specified in cert-revoked.txt"  >> %LOGFILE%
	for /F "tokens=*" %%A in (C:\<DOMAIN>\windows_enforcer\batch\cert-removal\cert-revoked.txt) do (
		certutil.exe -verifystore root %%A
		if errorlevel 0 (
			certutil.exe -delstore root %%A && echo ** Cert Name: %%A **  >> %LOGFILE%
		)	
	)
)

:: remove before installing certs if feature flag active - via present file name and its list of 'Issued To' cert names (usefull for replacing expired certs)
if exist C:\<DOMAIN>\windows_enforcer\batch\featureFlags-first-run_enforcement_checks\certificate-refresh_renameMe-ON.txt (
	echo "always active feature flag - removing trusted root certificates listed in file before installing" >> %LOGFILE%
	for /F "tokens=*" %%A in (C:\<DOMAIN>\windows_enforcer\batch\featureFlags-first-run_enforcement_checks\certificate-refresh_renameMe-ON.txt) do certutil.exe -delstore root %%A && echo ** Cert Name: %%A ** >> %LOGFILE%
)

:: install trusted root certificates if not present on local host
echo "installing trusted root certificates" >> %LOGFILE%
for /f %%f in ('dir /b %temp%\<DOMAIN>\trusted-root-certificates\') do certutil.exe -addstore root %temp%\<DOMAIN>\trusted-root-certificates\%%f && echo ** File: %%f ** >> %LOGFILE%

:: Ensure enablement for auditing/logging logon and logoff events
echo "*ensure enablement of audit logging for logon and logoff events*" >> %LOGFILE%
auditpol /set /subcategory:"Logoff" /success:enable /failure:enable >> %LOGFILE%
auditpol /set /subcategory:"Logon" /success:enable /failure:enable >> %LOGFILE%

:: Ensure enablement of task scheduler history
echo "*ensure enablement of task scheduler history*" >> %LOGFILE%
wevtutil set-log Microsoft-Windows-TaskScheduler/Operational /enabled:true >> %LOGFILE%

:: check if the scheduled tasks exists, recreating & first running them as neccessary
echo "checking scheduled tasks" >> %LOGFILE%
schtasks /query /TN "<DOMAIN>\First Run Enforcement Checks" >NUL 2>&1
if %errorlevel% NEQ 0 (
	echo scheduled task does not exist, re-creating - first run enforcement checks >> %LOGFILE%
        :: create then start after delay while continuing this script
	schtasks /Create /XML "C:\<DOMAIN>\windows_enforcer\batch\First Run Enforcement Checks.xml" /TN "<DOMAIN>\First Run Enforcement Checks" >> %LOGFILE%
	echo first run enforcement scheduled task will start in 10 seconds to intialize daily auto-runs >> %LOGFILE%
	start "" /b cmd /c "timeout /nobreak 10 >nul & start "" schtasks /run /TN "<DOMAIN>\First Run Enforcement Checks"" >> %LOGFILE%
)

schtasks /query /TN "\First Run Enforcement Checks Jumpstarter" >NUL 2>&1
if %errorlevel% NEQ 0 (
	echo scheduled task does not exist, re-creating - first run enforcement checks jumpstarter >> %LOGFILE%
        :: create then start after delay while continuing this script
	schtasks /Create /XML "C:\<DOMAIN>\windows_enforcer\batch\jumpstarter.xml" /TN "\First Run Enforcement Checks Jumpstarter" >> %LOGFILE%
	echo "first run enforcement jumpstart scheduled task created" >> %LOGFILE%
)

schtasks /query /TN "<DOMAIN>\Network Adapters - All - Reset" >NUL 2>&1
if %errorlevel% NEQ 0 (
	echo scheduled task does not exist, re-creating - network adapter reset script >> %LOGFILE% 
	schtasks /Create /XML "C:\<DOMAIN>\windows_enforcer\powershell\Network Adapters - All - Reset.xml" /TN "<DOMAIN>\Network Adapters - All - Reset" >> %LOGFILE%
	schtasks /run /TN "<DOMAIN>\Network Adapters - All - Reset" >> %LOGFILE%
)

:: Windows OS Settings
echo "*Windows OS Settings Enforcement*" >> %LOGFILE%

:: File Explorer - Enable Viewable Extensions
echo "**ensuring enforcement of file explorer settings**" >> %LOGFILE%
reg query HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced /v HideFileExt | findstr "0x0"
if %errorlevel% NEQ 0 (
	reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced /v HideFileExt /t REG_DWORD /d 0 /f
	echo "File Explorer - Enable Viewable Extensions -- reg key/value not found. Registry updated" >> %LOGFILE%
)

:: Local Audit Policy
echo "**ensuring enforcement of audit policy**" >> %LOGFILE%
auditpol /set /Category:"Object Access" /success:enable /failure:enable
auditpol /set /Category:"Account Logon" /success:enable /failure:enable
auditpol /set /Category:"Privilege Use" /success:enable /failure:enable
auditpol /set /Category:"Account Management" /success:enable /failure:enable

:: Enable Auditing for all users, all events, all event types, for local <DOMAIN> folder. Logging is set inside the script and outputs to a separate file.
:: All additional customizations for the enforcement process should be added to the powershell script below from the NAS device.
Powershell.exe -WindowStyle hidden -executionpolicy remotesigned -File C:\<DOMAIN>\windows_enforcer\powershell\first_run_enforcement-powershell.ps1
echo "*Powershell facility execution attempted - check the most recent 'first_run_enforcement-powershell-<timestamp>.log' file for execution details.*" >> %LOGFILE%

echo "*Install Management*" >> %LOGFILE%
:: Install Tools
:: check if connetected to the internet, otherwise skip
ping -n 1 google.com | find "TTL"
if not errorlevel 1 (
	echo "Internet connection detected, performing install processes" >> %LOGFILE%
	:: Install Tools
	echo "**Install Processes - Begin**" >> %LOGFILE%

	:: winget installs
	echo **winget installs** >> %LOGFILE%

	for /F "tokens=*" %%A in (C:\<DOMAIN>\windows_enforcer\batch\winget-installs.txt) do (
		winget list %%A >> %LOGFILE%
		if not errorlevel 0 (
		winget install %%A -h --accept-package-agreements --accept-source-agreements --no-upgrade >> %LOGFILE% && echo installed %%A >> %LOGFILE%
		) else (
			echo "winget package already installed - %%A" >> %LOGFILE%
		)
	)

	:: non-winget installs & downloads
	echo "**non-winget installs and downloads**" >> %LOGFILE%

	if not exist C:\Tools (
		mkdir C:\Tools
		echo created C:\Tools directory >> %LOGFILE%
	)

	:: GitHub Raw Installs
	echo "**github raw installs**" >> %LOGFILE%

	@echo off
	setlocal enabledelayedexpansion

	for /F "tokens=*" %%A in (C:\<DOMAIN>\windows_enforcer\batch\github-raw-installs.txt) do (
	set fullpath=%%A
	for %%a in ("!fullpath!/.") do set lastPart=%%~nxa

	for /f "tokens=1 delims=." %%a in ("!lastPart!") do (
	set dirname=%%a
	if not exist C:\Tools\!dirname! (
		mkdir C:\Tools\!dirname! >> %LOGFILE%
		curl -o C:\Tools\!dirname!\!lastPart! !fullpath! >> %LOGFILE%
		echo "!dirname! installed" >> %LOGFILE%
	)
	)  
	)

	:: GitHub Release Installes
	echo "**github release installs**" >> %LOGFILE%

	for /F "tokens=*" %%A in (C:\<DOMAIN>\windows_enforcer\batch\github-release-install.txt) do (
	set ghrelease=%%A

	for /f "tokens=2 delims=/" %%a in ("!ghrelease!") do (
	set dirname2=%%a  
	if not exist C:\Tools\!dirname2! (
		mkdir C:\Tools\!dirname2! >> %LOGFILE% 
		cd C:\Tools\!dirname2!
		for /f "tokens=1,* delims=:" %%A in ('curl -ks https://api.github.com/repos/!ghrelease!/releases/latest ^| find "browser_download_url"') do (
		curl -kOL %%B >> %LOGFILE%
		)
	)
	)
	)
	echo "Install Processes - End" >> %LOGFILE%
) else (
	echo "No internet connection, skipping install processes" >> %LOGFILE%
)

:: Remove installs which are no longer listed - Excludes winget installs
echo "**remaining install management**" >> %LOGFILE%
echo "created list of what is installed" >> %LOGFILE%
dir /a:d /b C:\Tools\ > C:\<DOMAIN>\windows_enforcer\batch\install-removal\installed.txt

echo "created 'install_desired.txt' with list of what should be installed" >> %LOGFILE%
if exist C:\<DOMAIN>\windows_enforcer\batch\install-removal\install_desired.txt (
del /Q C:\<DOMAIN>\windows_enforcer\batch\install-removal\install_desired.txt
)
for /F "tokens=*" %%A in (C:\<DOMAIN>\windows_enforcer\batch\github-raw-installs.txt) do (
  set fullpath=%%A
  for %%a in ("!fullpath!/.") do set lastPart=%%~nxa
  for /f "tokens=1 delims=." %%a in ("!lastPart!") do (
   set dirname=%%a
   echo !dirname! >> C:\<DOMAIN>\windows_enforcer\batch\install-removal\install_desired.txt
  ) 
)

for /F "tokens=*" %%A in (C:\<DOMAIN>\windows_enforcer\batch\github-release-install.txt) do (
set ghrelease=%%A
for /f "tokens=2 delims=/" %%a in ("!ghrelease!") do (
  set dirname2=%%a
  echo !dirname2! >> C:\<DOMAIN>\windows_enforcer\batch\install-removal\install_desired.txt
 )
)

echo "reconciled 'install_desired_.txt' list" >> %LOGFILE%
if exist C:\<DOMAIN>\windows_enforcer\batch\install-removal\install_remove.txt (
  del /Q C:\<DOMAIN>\windows_enforcer\batch\install-removal\install_remove.txt
)

for /F "tokens=*" %%A in (C:\<DOMAIN>\windows_enforcer\batch\install-removal\installed.txt) do (
  set installed=%%A
  findstr "\<!installed!\>" "C:\<DOMAIN>\windows_enforcer\batch\install-removal\install_desired.txt"
  if errorlevel 1 (
    echo !installed! >> C:\<DOMAIN>\windows_enforcer\batch\install-removal\install_remove.txt
  )
)

if exist C:\<DOMAIN>\windows_enforcer\batch\install-removal\install_remove.txt (
  for /F "tokens=*" %%A in (C:\<DOMAIN>\windows_enforcer\batch\install-removal\install_remove.txt) do (
    set remove=%%A
    rmdir /s/q C:\Tools\!remove!
	echo "removing !remove!" >> %LOGFILE%
  )
)

:: Remove winget installs listed within the winget-uninstalls input file
echo "**processing winget uninstalls**" >> %LOGFILE%
for /F "tokens=*" %%A in (C:\<DOMAIN>\windows_enforcer\batch\winget-uninstalls.txt) do (
	set wgremove=%%A
	findstr /r /s /i /m /c:"\<!wgremove!\>" "C:\<DOMAIN>\windows_enforcer\batch\winget-installs.txt"
	if not errorlevel 1 (
		echo "winget uninstall conflict for '!wgremove!' - present in install input as well, skipping" >> %LOGFILE%
	) else (
		: winget install !wgremove! --force --override "/uninstall /silent"
		echo "attempting winget uninstall - !wgremove!" >> %LOGFILE%
		winget uninstall !wgremove! -h --force --purge --disable-interactivity >> %LOGFILE%
		if not errorlevel 0 (
			echo "package already uninstalled or not found - !wgremove!" >> %LOGFILE%
			) else (
				echo "uninstalled winget install - !wgremove!" >> %LOGFILE%
			) 
	)
)

:: bootstrap successful output flag which is excluded from robocopy overwrite
if not exist C:\<DOMAIN>\windows_enforcer\batch\bootstrap_success.txt  (
	echo. 2>C:\<DOMAIN>\windows_enforcer\batch\bootstrap_success.txt
	:: remove delete permissions for the bootstrap success file from the Administrators group
	icacls C:\<DOMAIN>\windows_enforcer\batch\bootstrap_success.txt /reset /q /c >> %LOGFILE%
	icacls C:\<DOMAIN>\windows_enforcer\batch\bootstrap_success.txt /inheritance:d >> %LOGFILE%
	icacls C:\<DOMAIN>\windows_enforcer\batch\bootstrap_success.txt /remove:g "Administrators" /q /c >> %LOGFILE%
	icacls C:\<DOMAIN>\windows_enforcer\batch\bootstrap_success.txt /remove:g "Users" /q /c >> %LOGFILE%
	icacls C:\<DOMAIN>\windows_enforcer\batch\bootstrap_success.txt /setowner "SYSTEM" /q /c >> %LOGFILE%
	echo "**bootstrap file and permissions created**" >> %LOGFILE%
	echo "BOOTSTRAP SUCCESSFUL"
	) else (
		echo "**bootstrap file and permissions already exists**" >> %LOGFILE%
	)

:: last runs output with timestamp
echo %TIMESTAMP% > C:\<DOMAIN>\windows_enforcer\batch\last_run.txt
icacls C:\<DOMAIN>\windows_enforcer\batch\last_run.txt /reset /q /c >> %LOGFILE%
icacls C:\<DOMAIN>\windows_enforcer\batch\last_run.txt /inheritance:d >> %LOGFILE%
icacls C:\<DOMAIN>\windows_enforcer\batch\last_run.txt /grant "Users":(R) /q /c >> %LOGFILE%
echo "**last run file with timestamp created**" >> %LOGFILE%

if exist C:\<DOMAIN>_last-runs (
	echo %TIMESTAMP% > C:\<DOMAIN>_last-runs\%COMPUTERNAME%.txt
	echo "sent last run data to '<DOMAIN>_last-runs' folder on NAS" >> %LOGFILE%
) else (
	echo "could not send last run data to '<DOMAIN>_last-runs' folder on NAS as folder was not accessible. Last run did complete however. Check local 'last_run.txt file' to confirm timestamp" >> %LOGFILE%
)

@REM IF "%user%" == "%usertest%" (
@REM 	echo "this is a test" > C:\<DOMAIN>\windows_enforcer\batch\testing.txt
@REM 	)

echo "*End Install Management*" >> %LOGFILE%
echo "*End Script*" >> %LOGFILE%

:: Output log file location
echo "LOG LOCATION: %LOGFILE%"
