@echo off
setlocal enabledelayedexpansion

set TIMESTAMP=%DATE:/=-%_%TIME::=-%
set TIMESTAMP=%TIMESTAMP: =%
set LOGFILE=%temp%\damo_net\logs\jumpstart-%TIMESTAMP%.log


echo checking scheduled tasks >> %LOGFILE%
schtasks /query /TN "Damo.net\First Run Enforcement Checks" >NUL 2>&1
if %errorlevel% NEQ 0 (
	echo scheduled task does not exist, re-creating - first run enforcement checks >> %LOGFILE%
        :: create then start after delay while continuing this script
	schtasks /Create /XML "C:\damo_net\windows_enforcer\batch\First Run Enforcement Checks.xml" /TN "Damo.net\First Run Enforcement Checks" >> %LOGFILE%
	echo first run enforcement scheduled task will start in 10 seconds to intialize daily auto-runs >> %LOGFILE%
	start "" /b cmd /c "timeout /nobreak 10 >nul & start "" schtasks /run /TN "Damo.net\First Run Enforcement Checks"" >> %LOGFILE%
)