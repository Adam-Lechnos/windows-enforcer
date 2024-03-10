@echo off
setlocal enabledelayedexpansion

set TIMESTAMP=%DATE:/=-%_%TIME::=-%
set TIMESTAMP=%TIMESTAMP: =%
set LOGFILE=%temp%\damo_net\logs\first-run-enforcement-%TIMESTAMP%.log

if not exist %temp%\damo_net\logs\ (mkdir %temp%\damo_net\logs\)
if not exist C:\scripts\batch\install_removal (mkdir C:\scripts\batch\install_removal)
if not exist C:\scripts\batch\github-raw-installs.txt (break>"C:\scripts\batch\github-raw-installs.txt")
if not exist C:\scripts\batch\github-release-installs.txt (break>"C:\scripts\batch\github-release-installs.txt")
if not exist C:\scripts\batch\winget-installs.txt (break>"C:\scripts\batch\winget-installs.txt")


:: Main entry point for running enforcement and syncing data for Damo.net admin settings. Never rename or delete this file.

:: check if on DAMO.NET workgroup (router name must match)
echo checking if on proper DAMO.NET workgroup >> %LOGFILE%
:: copy and paste the below 2 lines for each network, updating the FQDN of the router hostname and IP and updating the integer value for neterror array
ping -n 1 10.10.0.1 | find "TTL" && ping -n 1 -a 10.10.0.1 | find "RT-AC5300-C300" && ipconfig | find "DAMO.NET"
set neterror[0]=%errorlevel%

:: loop through all error levels assinged to array and find a 0. Update the third number to number of home networks being checked minus 1.
for /L %%n in (0,1,0) do (
	echo !neterror[%%n]! >> %LOGFILE%
	if !neterror[%%n]!==0 (goto start)
	)

:: exit with message if no 0 error levels found
echo ** DAMO.NET home network not detected, exiting ** >> %LOGFILE%
exit

:start
echo ** DAMO.NET workgroup detected, continuing... ** >> %LOGFILE%
:: copy itself if file does not exist in designated location
if not exist C:\scripts\batch\first_run_enforcement_checks.bat (
	echo first run enforcement script does not exist, copying and executing remaining enforcement checks >> %LOGFILE%
	mkdir C:\scripts\batch
	copy "%~f0" C:\scripts\batch\first_run_enforcement_checks.bat
)

:: peform file sync from designated NAS folder attempting to map the correct drive letter if it does not exist
echo running robo copy from central NAS enforcement folder to ensure latest files are being used >> %LOGFILE%
:: check if drive is mapped, if not, ping NAS, if fails, skip, otherwise, re-map
if not exist Z:\ (
	echo mapped drive not found, pinging NAS >> %LOGFILE%
	:: use IP of NAS device
	ping -n 1 10.10.0.1 | find "TTL"
	if not errorlevel 1 (
		echo re-mapping NAS, ping responded >> %LOGFILE%
		goto resync
	) else (
		echo cannot ping NAS, either down or off the network >> %LOGFILE%
		echo will attempt remaining enforcecment tasks, which will fail if at least one sync has not occured >> %LOGFILE%
	) 
) else (
	if exist Z:\damo-net\automation\enforcement\scripts\batch\first_run_enforcement_checks.bat (
		goto resync
	) else (
		*** echo Z drive mapping is incorrect. Unamp existing Z drive, then try again *** >> %LOGFILE%
	)
)

:resync
echo ** syncing files with NAS enforcement folder ** >> %LOGFILE%
:: sync scripts
robocopy C:\test\scripts C:\scripts /MIR >> %LOGFILE%
:: create temporary trust root certificates folder		
mkdir %temp%\damo_net\trusted-root-certificates
:: sync trusted root certificates
robocopy C:\test\trusted-root-certificates %temp%\damo_net\trusted-root-certificates /MIR  >> %LOGFILE%

:: remove all certs before installing for hosts opted into force cert refresh list with flag set to ON
if exist C:\scripts\batch\featureFlags-first-run_enforcement_checks\certificate-refresh_FORCE_renameMe-ON.txt (
	FOR /F "tokens=* USEBACKQ" %%F IN (`hostname`) DO (
    SET hostname=%%F
	  findstr /r /s /i /m /c:"\<!hostname!\>" "C:\scripts\batch\featureFlags-first-run_enforcement_checks\certificate-refresh_FORCE_renameMe-ON.txt"
	  if not errorlevel 1 (
		  echo 'feature flag for force cert refresh active with local host opted in. removing trusted root certificates listed in force list before installing' >> %LOGFILE%
		  for /F "tokens=*" %%A in (C:\scripts\batch\featureFlags-first-run_enforcement_checks\certificate-refresh_FORCE_LIST.txt) do certutil.exe -delstore root %%A && echo ** Removed Cert Name: %%A **  >> %LOGFILE%
	  )  
  )
)

:: remove before installing certs if feature flag active - via present file name and its list of 'Issued To' cert names (usefull for replacing expired certs)
if exist C:\scripts\batch\featureFlags-first-run_enforcement_checks\certificate-refresh_renameMe-ON.txt (
	echo feature flag active - removing trusted root certificates listed in file before installing  >> %LOGFILE%
	for /F "tokens=*" %%A in (C:\scripts\batch\featureFlags-first-run_enforcement_checks\certificate-refresh_renameMe-ON.txt) do certutil.exe -delstore root %%A && echo ** Cert Name: %%A **  >> %LOGFILE%
)

:: install trusted root certificates if not present on local host
echo installing trusted root certificates  >> %LOGFILE%
for /f %%f in ('dir /b %temp%\damo_net\trusted-root-certificates\') do certutil.exe -addstore root %temp%\damo_net\trusted-root-certificates\%%f && echo ** File: %%f **  >> %LOGFILE%

:: Ensure enablement for auditing/logging logon and logoff events
auditpol /set /subcategory:"Logoff" /success:enable /failure:enable
auditpol /set /subcategory:"Logon" /success:enable /failure:enable

:: Ensure enablement of task scheduler history
wevtutil set-log Microsoft-Windows-TaskScheduler/Operational /enabled:true

:: check if the scheduled tasks exists, recreating & first running them as neccessary
echo checking scheduled tasks >> %LOGFILE%
schtasks /query /TN "Damo.net\First Run Enforcement Checks" >NUL 2>&1
if %errorlevel% NEQ 0 (
	echo scheduled task does not exist, re-creating - first run enforcement checks >> %LOGFILE%
        :: create then start after delay while continuing this script
	schtasks /Create /XML "C:\scripts\batch\First Run Enforcement Checks.xml" /TN "Damo.net\First Run Enforcement Checks" >> %LOGFILE%
	echo first run enforcement scheduled task will start in 10 seconds to intialize hourly auto-runs >> %LOGFILE%
	start "" /b cmd /c "timeout /nobreak 10 >nul & start schtasks /run /TN "Damo.net\First Run Enforcement Checks" >> %LOGFILE%
)

schtasks /query /TN "Damo.net\Network Adapters - All - Reset" >NUL 2>&1
if %errorlevel% NEQ 0 (
	echo scheduled task does not exist, re-creating - network adapter reset script >> %LOGFILE% 
	schtasks /Create /XML "C:\scripts\powershell\Network Adapters - All - Reset.xml" /TN "Damo.net\Network Adapters - All - Reset" >> %LOGFILE%
	schtasks /run /TN "Damo.net\Network Adapters - All - Reset" >> %LOGFILE%
)


:: Install Tools
echo **Installing Tools** >> %LOGFILE%

:: winget installs
echo *winget installs* >> %LOGFILE%

winget -v
if not errorlevel 0 (
	echo install App Installer from the Microsoft Store >> %LOGFILE%
	exit
)

for /F "tokens=*" %%A in (C:\scripts\batch\winget-installs.txt) do (
	winget list %%A >> %LOGFILE%
	if not errorlevel 0 (
	winget install %%A -h --accept-package-agreements --accept-source-agreements --no-upgrade >> %LOGFILE% && echo installed %%A >> %LOGFILE%
	)
)

:: non-winget installs & downloads
echo *non-winget installs and downloads* >> %LOGFILE%

if not exist C:\Tools (
	mkdir C:\Tools
	echo created C:\Tools directory >> %LOGFILE%
)

:: GitHub Raw Installs
echo *github raw installs* >> %LOGFILE%

@echo off
setlocal enabledelayedexpansion

for /F "tokens=*" %%A in (C:\scripts\batch\github-raw-installs.txt) do (
  set fullpath=%%A
  for %%a in ("!fullpath!/.") do set lastPart=%%~nxa

  for /f "tokens=1 delims=." %%a in ("!lastPart!") do (
   set dirname=%%a
   if not exist C:\Tools\!dirname! (
    mkdir C:\Tools\!dirname! >> %LOGFILE%
    curl -o C:\Tools\!dirname!\!lastPart! !fullpath! >> %LOGFILE%
    echo !dirname! installed >> %LOGFILE%
   )
  )  
)

:: GitHub Release Installes
echo *github release installs* >> %LOGFILE%

for /F "tokens=*" %%A in (C:\scripts\batch\github-release-install.txt) do (
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

:: Remove installs which are no longer listed - Excludes winget installs
echo created list of what is installed >> %LOGFILE%
dir /a:d /b C:\Tools\ > C:\scripts\batch\install-removal\installed.txt

echo created install_desired with list of what should be installed >> %LOGFILE%
if exist C:\scripts\batch\install-removal\install_desired.txt (
del /Q C:\scripts\batch\install-removal\install_desired.txt
)
for /F "tokens=*" %%A in (C:\scripts\batch\github-raw-installs.txt) do (
  set fullpath=%%A
  for %%a in ("!fullpath!/.") do set lastPart=%%~nxa
  for /f "tokens=1 delims=." %%a in ("!lastPart!") do (
   set dirname=%%a
   echo !dirname! >> C:\scripts\batch\install-removal\install_desired.txt
  ) 
)

for /F "tokens=*" %%A in (C:\scripts\batch\github-release-install.txt) do (
set ghrelease=%%A
for /f "tokens=2 delims=/" %%a in ("!ghrelease!") do (
  set dirname2=%%a
  echo !dirname2! >> C:\scripts\batch\install-removal\install_desired.txt
 )
)

echo reconciled the list of installed against what should be installed outputting only those that should be removed >> %LOGFILE%
if exist C:\scripts\batch\install-removal\install_remove.txt (
  del /Q C:\scripts\batch\install-removal\install_remove.txt
)

for /F "tokens=*" %%A in (C:\scripts\batch\install-removal\installed.txt) do (
  set installed=%%A
  findstr "\<!installed!\>" "C:\scripts\batch\install-removal\install_desired.txt"
  if errorlevel 1 (
    echo !installed! >> C:\scripts\batch\install-removal\install_remove.txt
  )
)

if exist C:\scripts\batch\install-removal\install_remove.txt (
  for /F "tokens=*" %%A in (C:\scripts\batch\install-removal\install_remove.txt) do (
    set remove=%%A
    rmdir /s/q C:\Tools\!remove!
	echo removing !remove! >> %LOGFILE%
  )
)

echo **End Tools Installs** >> %LOGFILE%
echo **End Script** >> %LOGFILE%

:: Output log file location
echo LOG LOCATION: %LOGFILE%