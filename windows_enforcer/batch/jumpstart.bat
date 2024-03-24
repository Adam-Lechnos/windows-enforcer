@echo off
setlocal enabledelayedexpansion

set TIMESTAMP=%DATE:/=-%_%TIME::=-%
set TIMESTAMP=%TIMESTAMP: =%
set LOGFILE=%temp%\<DOMAIN>\logs\jumpstart-%TIMESTAMP%.log

:: subtract last run time from current time
for /F "tokens=*" %%A in (C:\<DOMAIN>\windows_enforcer\batch\last_run.txt) do (
	set lastrun=%%A

	set timestamp1=!TIMESTAMP:-=!
	set timestamp1=!timestamp1:~3,-10!
	set timestampE=!timestamp1:~4!
	set timestampB=!timestamp1:~0,-4!
	set currTime=!timestampE!!timestampB!

	set timestamp2=!lastrun:-=!
	set timestamp2=!timestamp2:~3,-11!
	set timestamp2E=!timestamp2:~4!
	set timestamp2B=!timestamp2:~0,-4!
	set lastrunTime=!timestamp2E!!timestamp2B!

	set /a dayslastrun=!currTime!-!lastrunTime!
)

:: check if enforcement folder exists and if not recreate and jumpstart the copy resync process
if not exist C:\<DOMAIN> (
	echo "File detection error: 'C:\<DOMAIN>\windows_enforcer\first_run_enforcement_checks.bat', attempting to re-create 'C:\<DOMAIN>' and re-running resync" >> %LOGFILE%
	mkdir C:\<DOMAIN>
	goto startcopy
) else (
	echo "File OK: 'C:\<DOMAIN>\windows_enforcer\first_run_enforcement_checks.bat'" >> %LOGFILE%
)

if !dayslastrun! gtr 6 (
	ECHO "days since last enforcement run is greater than 6, re-running resync" >> %LOGFILE%
	goto startcopy
) else (
	echo "days since last enforcement check OK, performing scheduled tasks check" >> %LOGFILE%
	goto staskcheck
)

:startcopy
:: check if on <DOMAIN> workgroup (router name must match)
echo "checking if on proper <DOMAIN> workgroup" >> %LOGFILE%
:: copy and paste the below 2 lines for each network, updating the FQDN of the router hostname and IP and updating the integer value for neterror array
ping -n 1 <ROUTER IP> | find "TTL" && ping -n 1 -a <ROUTER IP> | find "<ROUTER HOSTNAME>" && ipconfig | find "<DOMAIN>"
set neterror[0]=%errorlevel%

:: loop through all error levels assinged to array and find a 0. Update the third number to number of home networks being checked minus 1.
for /L %%n in (0,1,0) do (
	echo !neterror[%%n]! >> %LOGFILE%
	if !neterror[%%n]!==0 (goto resyncstart)
	)

:: exit with message if no 0 error levels found
echo "** <DOMAIN> home network not detected, exiting **" >> %LOGFILE%
exit

:resyncstart
:: peform file sync from designated NAS folder attempting to map the correct drive letter if it does not exist
echo "running robo copy from central NAS enforcement folder to ensure latest files are being used" >> %LOGFILE%
:: check if drive is mapped, if not, ping NAS, if fails, skip, otherwise, re-map
if not exist Z:\ (
	echo "*** mapped drive not found, pinging NAS ***" >> %LOGFILE%
	:: use IP of NAS device
	ping -n 1 <ROUTER IP> | find "TTL"
	if not errorlevel 1 (
		echo re-mapping NAS, ping responded >> %LOGFILE%
		goto resync
	) else (
		echo "*** cannot ping NAS, either down or off the network, exiting ***" >> %LOGFILE%
		exit
	) 
) else (
	if exist Z:\<DOMAIN>\windows_enforcer\batch\first_run_enforcement_checks.bat (
		goto resync
	) else (
		echo "*** Z drive mapping is incorrect. Un-map existing Z drive, then try again. Exiting ***" >> %LOGFILE%
		exit
	)
)

:resync
echo "** syncing files with NAS enforcement folder **" >> %LOGFILE%
:: sync scripts
robocopy C:\test\ C:\<DOMAIN>\ /MIR /Z /XD .git /XF bootstrap_success.txt last-runs-check.sh cert-check.sh >> %LOGFILE%
:: sync trusted root certificates
robocopy C:\test\trusted-root-certificates %temp%\<DOMAIN>\trusted-root-certificates /MIR  >> %LOGFILE%

:staskcheck
echo "checking scheduled tasks" >> %LOGFILE%
schtasks /query /TN "<DOMAIN>\First Run Enforcement Checks" >NUL 2>&1
if %errorlevel% NEQ 0 (
	echo "scheduled task does not exist, re-creating - first run enforcement checks" >> %LOGFILE%
        :: create then start after delay while continuing this script
	schtasks /Create /XML "C:\<DOMAIN>\windows_enforcer\batch\First Run Enforcement Checks.xml" /TN "<DOMAIN>\First Run Enforcement Checks" >> %LOGFILE%
	echo first run enforcement scheduled task will start in 10 seconds to intialize daily auto-runs >> %LOGFILE%
	start "" /b cmd /c "timeout /nobreak 10 >nul & start "" schtasks /run /TN "<DOMAIN>\First Run Enforcement Checks"" >> %LOGFILE%
) else (
	echo "scheduled tasks OK" >> %LOGFILE%
)


:: last runs output with timestamp
echo %TIMESTAMP% > C:\<DOMAIN>\windows_enforcer\batch\last_run-jumpstart.txt
icacls C:\<DOMAIN>\windows_enforcer\batch\last_run-jumpstart.txt /reset /q /c >> %LOGFILE%
icacls C:\<DOMAIN>\windows_enforcer\batch\last_run-jumpstart.txt /inheritance:d >> %LOGFILE%
icacls C:\<DOMAIN>\windows_enforcer\batch\last_run-jumpstart.txt /grant "Users":(R) /q /c >> %LOGFILE%
echo "**last run file with timestamp created**" >> %LOGFILE%


echo "*End Script*" >> %LOGFILE%
