@echo off
setlocal enabledelayedexpansion

@REM for /F "tokens=*" %%A in (C:\scripts\batch\github-raw-installs.txt) do (
@REM   set fullpath=%%A
@REM   for %%a in ("!fullpath!/.") do set lastPart=%%~nxa

@REM   for /f "tokens=1 delims=." %%a in ("!lastPart!") do (
@REM    set dirname=%%a
@REM    if not exist C:\Tools\!dirname! (
@REM     mkdir C:\Tools\!dirname!
@REM     curl -s -o C:\Tools\!dirname!\!lastPart! !fullpath! 
@REM    )

@REM   )
  
@REM )


@REM for /F "tokens=*" %%A in (C:\scripts\batch\github-release-install.txt) do (
@REM set ghrelease=%%A


@REM for /f "tokens=2 delims=/" %%a in ("!ghrelease!") do (
@REM   set dirname2=%%a  
@REM   if not exist C:\Tools\!dirname2! (
@REM     mkdir C:\Tools\!dirname2!  
@REM     cd C:\Tools\!dirname2!
@REM     for /f "tokens=1,* delims=:" %%A in ('curl -ks https://api.github.com/repos/!ghrelease!/releases/latest ^| find "browser_download_url"') do (
@REM      curl -s -kOL %%B
@REM     )
@REM   )
@REM  )
@REM )

@REM :: created list of what is installed
@REM dir /a:d /b C:\Tools\ > C:\scripts\batch\installed.txt

@REM :: created install_desired with list of what should be installed
@REM if exist C:\scripts\batch\install_desired.txt (
@REM del /Q C:\scripts\batch\install_desired.txt
@REM )
@REM for /F "tokens=*" %%A in (C:\scripts\batch\github-raw-installs.txt) do (
@REM   set fullpath=%%A
@REM   for %%a in ("!fullpath!/.") do set lastPart=%%~nxa
@REM   for /f "tokens=1 delims=." %%a in ("!lastPart!") do (
@REM    set dirname=%%a
@REM    echo !dirname! >> C:\scripts\batch\install_desired.txt
@REM   ) 
@REM )

@REM for /F "tokens=*" %%A in (C:\scripts\batch\github-release-install.txt) do (
@REM set ghrelease=%%A
@REM for /f "tokens=2 delims=/" %%a in ("!ghrelease!") do (
@REM   set dirname2=%%a
@REM   echo !dirname2! >> C:\scripts\batch\install_desired.txt
@REM  )
@REM )

@REM :: reconcile the list of installed against what should be installed, outputting only those that should be removed
@REM if exist C:\scripts\batch\install_remove.txt (
@REM   del /Q C:\scripts\batch\install_remove.txt
@REM )

@REM for /F "tokens=*" %%A in (C:\scripts\batch\installed.txt) do (
@REM   set installed=%%A
@REM   findstr "\<!installed!\>" "C:\scripts\batch\install_desired.txt"

@REM   if errorlevel 1 (
@REM     echo !installed! >> C:\scripts\batch\install_remove.txt
@REM   )
@REM )

@REM for /F "tokens=*" %%A in (C:\scripts\batch\install_remove.txt) do (
@REM   set remove=%%A
@REM   rmdir /s/q C:\Tools\!remove!
@REM )


:: remove before installing cert for each which will expire within two weeks; allowing two week window for replacing cert file before its expiration
@REM echo checking trusted root certificate expiries and removing first if within two weeks



@REM FOR /F "tokens=* USEBACKQ" %%F IN (`"C:\Program Files\OpenSSL-Win64\bin\openssl.exe" x509 -in C:\test\trusted-root-certificates\Trusted-Root-Cert-router149brp.crt -subject -noout`) DO (
@REM   SET subject=%%F
@REM )

@REM for /f "tokens=8 delims==" %%a in ("!subject!") do (
@REM   certutil.exe -delstore root %%a
@REM   echo ** Removed Cert Name: %%a **
@REM )

@REM for /f "tokens=8 delims==" %%a in ("!subject!") do (
@REM   certutil.exe -delstore root %%a
@REM   echo ** Removed Cert Name: %%a **
@REM )

if exist C:\test\scripts\batch\featureFlags-first-run_enforcement_checks\certificate-refresh_FORCE_renameMe-ON.txt (
	FOR /F "tokens=* USEBACKQ" %%F IN (`hostname`) DO (
    SET hostname=%%F
	  findstr /r /s /i /m /c:"\<%hostname%\>" "C:\test\scripts\batch\featureFlags-first-run_enforcement_checks\certificate-refresh_FORCE_renameMe-ON.txt"
	  if not errorlevel 1 (
		  echo feature flag for force cert refresh active with local host opted in removing trusted root certificates listed in force list before installing'  >> %LOGFILE%
		  echo REMOVE CERT TEST
		  for /F "tokens=*" %%A in (C:\scripts\batch\featureFlags-first-run_enforcement_checks\certificate-refresh_FORCE_LIST.txt) do certutil.exe -delstore root %%A && echo ** Cert Name: %%A **  >> %LOGFILE%
	  )  
  )
)
