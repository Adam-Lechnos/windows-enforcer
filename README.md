# Windows Enforcement Script
Enforce a suite of Installs, OS Settings, and Trusted Root Certificates with an output file sent to email when any issues or warnings are detected.

![Diagram](./windows-enforcement-diagram.drawio.svg)

The NAS will host the enforcer and suite of files that manage the certificates and install packages. Email alerts are sent using attachments to Postfix. Crontab performs hourly reruns. The hosted files are accessible by clients on `Z:\<NAS HOST>\<PARENT DIRECTORY>`.
Local hosts are first bootstrapped, which executes a series of tasks: creating the automated scheduled tasks in the Task Scheduler, checking for the NAS device availability then syncing the data from the device, instantiating script tamper protections, desired Windows OS Settings, and performing initial package and certificate installs. The local enforcer script runs based on pre-defined parameters including every logon. Local install persists to the `C:\Tools` directory except for Winget-based packages. Certificates are placed within the NAS\` `trusted-root-certificates` folder. Installations and certificates may therefore be managed centrally and enforced including uninstalls and certificated renewal and revocations, without requiring a PKI setup.

An enforcement cron job runs on the NAS which performs the management of certificates, checking of valid packages for install management options, and certificate renewal and revocation for certificate management files.
An email alert is sent when issues are discovered with any of the install and/or certificate management files including certificate revocation notices.

### Target Host Pre-reqs
1. [Winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/) and [OpenSSL](https://winstall.app/apps/ShiningLight.OpenSSL) are installed
   1. [robocopy](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy) is also required but should be already included in Windows 10 or higher by default
1. Ensure the following *does not exist* for each new target host being bootstrapped:
   1. Drive mapping letter `Z`
   1. Directory path `C:\Tools`
   1. Directory path `C:\Scripts` 

### Installation steps for all new clients
1. Ensure the client is connected to the workgroup, DAMO.NET
2. Copy the file `script\batch\first_run_enforcement_checks.bat`, locally to the the 'C' drive from the NAS server, ensuring the client is on an `DAMO.NET` network.
3. Ensure the NAS is mapped as drive 'Z', if not, ensure you can ping `10.10.0.10`, the NAS server. (Note: If any other drive is mapped to 'Z', the script will fail)
4. Start an elevated command prompt, then execute the locally copied file.
5. Check the `C:\scripts` folder, ensuring the files `C:\scripts\batch\first_run_enforcement_checks.bat` and `First Run Enforcement Checks.xml` exist.
6. Delete the manually executed `first_run_enforcement_checks.bat` file (which should *not* be the `C:\script\batch\first_run_enforcement_checks.bat` copy).

### NAS Installation
1. Place a copy of the entire enforcement-script-windows folder somewhere within the directory structure of the NAS and create a Shared Folder with read-only permissions.
2. Update the `first_run_enforcement_checks.bat` script to robocopy from the Shared Folder root recursively via the full path from the client's 'Z' drive mapping, per the snippet:
  3. ```batch
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
      		echo will attempt remaining enforcement tasks, which will fail if at least one sync has not occurred >> %LOGFILE%
      	) 
      ) else (
      	if exist Z:\damo-net\automation\enforcement\scripts\batch\first_run_enforcement_checks.bat (
      		goto resync
      	) else (
      		*** echo Z drive mapping is incorrect. Un-map existing Z drive, then try again *** >> %LOGFILE%
      	)
      )
     ``` 
4. Create a cronjob that runs once per day and executes the `enforce-checker.sh` script from the NAS device.
5. The NAS' IP must be `10.10.0.10`
6. Additional home networks may be added by following instructions within the `first_run_enforcement_checks.bat` assuming NAS replication exists and the drive letter persists, per the snippet:
  7. ```batch
     :: copy and paste the below 2 lines for each network, updating the FQDN of the router hostname and IP and updating the integer value for neterror array
     ping -n 1 10.10.0.1 | find "TTL" && ping -n 1 -a 10.10.0.1 | find "RT-AC5300-C300" && ipconfig | find "DAMO.NET"
     set neterror[0]=%errorlevel%
     ```
#### Permissions
* Read access should be the default permission for the parent and subdirectories of the Shared Folder to allow for local Windows [robocopy](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy) to copy the data.
* Write access should only be granted to admins designated to determine host enforcement.

### Updating files
From the NAS drive's enforcement folder, make changes to any file and it will sync and either execute or install.

**IMPORTANT** Never change the name of the file, `script\batch\first_run_enforcement_checks.bat`, either within the NAS directory or locally on any client. If the 'First Run Enforcement Checks' scheduled task is ever deleted or modified, the above steps should be followed.

### Tamper Protection
Each client runtime will ensure the following OS Settings and Windows Filesystem Permissions
* Enable Audit logging for logon and logoff events -both success and failures
* Lock down the directory, `C:\Scripts` with only read and list access by non-Admins within the `Users` group.
* Scheduled tasks are only viewable/modifiable by Admins.

### Feature Flags
The First Run Enforcement Script contains a feature flag folder, editable on the NAS enforcement folder, `\scripts\batch\featureFlags-first-run_enforcement_checks`
Each file may be set to ON by updating the appended name accordingly.

#### Feature Flag file details - file names below are case/spelling sensitive:
* `certificate-refresh-renameMe-ON.txt` --> This file is managed by the program and should not be modified; used to track which certs are slated for refresh based on their expiry. certs expiring within 15 days are added to this list. new certs should be replaced using the same values and cert file name. 
* `certificate-refresh_FORCE_renameMe-OFF.txt` --> Rename with OFF set to ON and add hostnames for hosts that require a full cert refresh. only used for hosts that have been offline long enough to miss certificate replacements. set back to OFF when not in use. 

### Logging
Scripts executed manually will output logging data to the logged-in user's temp directory --> `%temp%\damo-net\logs` (`C:\Users\<user>\AppData\Local\Temp\damo_net`)
Scripts executed via task scheduler, even if executed manually, will output logging data from the system's specified log directory --> `%temp%\damo-net\logs` (`C:\Windows\temp`)
A new log is generated with the execution's point-in-time date and time stamp appended.

If the client is off the network, the script will attempt to execute enforcement tasks, which are expected to fail if at least one sync has not occurred or if the files were deleted within the local scripts folder. The next successful re-sync will re-create any missing files.

### Managing Installs
Downloads packages to the `C:\Tools` folder, except for those that are obtained via the Winget package manager, in which case are installed according to the Winget process. Note, that only the data is downloaded to the `C:\Tools` folder. Subsequent installs must occur manually post the data retrieval if required. Use this feature for pulling down simple packages. Subsequent download attempts are ignored for each install in which its corresponding directory gets created. For Winget, the script first checks the Winget list command for existing installs. Upgrades are not attempted once the installation is completed. Use `Winget update --all` instead.

There are four files within the scripts\batch folder which reference the following install methods:
* `winget-install.txt` - Specify the official widget package names you would like installed. (Recommended). Values are case-sensitive. Use `https://winstall.app` to check the package name spelling.
* `winget-uninstall.txt` - Specify the official widget package names you would like uninstalled. (Recommended). Values are case-sensitive. Use `https://winstall.app` to check the package name spelling. If the same value exists in `winget-install.txt`, the package will be skipped. 
* `github-release-installs.txt` - specify a list of downloadable repo packages against repos that utilize the GitHub package release feature. Use OWNER/REPO format.
* `github-raw-installs.txt` - specify the full URLs against a raw GitHub downloadable, pointing to the `raw.githubusercontent.com` domain.
  * i.e., `https://raw.githubusercontent.com/AndyFul/ConfigureDefender/master/ConfigureDefender.exe` 

Except for 'widget-install.txt', items removed from the text files will result in their respective directory removal from `C:\Tools` only. You must still uninstall packages installed via an installer, hence, these methods, except for Winget, should only be used for simple executables. Winget uninstalls can be enforced by the aforementioned `winget-uninstall.txt` install management input file.

### Managing Trusted Root Certificates
Trusted Root Certificates may be added for home network devices that contain a web interface for TLS, such as a router's admin UI. This feature can be used to ensure all hosts receive the Trusted Root Certificate applied to the Computer setting of the Certificate Manager
* `trusted-root-certificates` folder is where the trusted root certificate should be placed. Once copied locally by the enforcement script, the certificate will be installed on the local host.
  * Certs within a 45-day or less certificate expiry will trigger an email alert via the [Enforcement Checker](#enforcement-checker) hook.
  * Email alerts will trigger and apply to the attached report until the cert is renewed. Ensure the same cert options are specified such as the CN, Subject, and SAN.
* Within 14 days are less of the cert expiry, the certificate will be placed on the refresh list, `certificate-refresh_renameMe-ON.txt`, located within the `batch\featureFlags-first-run_enforcement_checks` directory, which instructs all hosts to first remove the cert from the local Certificate Manager before installing the newly added cert dropped into the `trusted-root-certificates` directory.
  * After the 14-day window, any offline hosts will require a forced refresh. Rename `certificate-refresh_FORCE_renameMe-OFF.txt` within the `batch\featureFlags-first-run_enforcement_checks` directory, changing the text `OFF` to `ON`. Then add the hosts that missed the 14-day window or were off the home network.
    * Hostnames that are not resolvable will trigger an error during an [Enforcement Checker](#enforcement-checker) email. 
  * Upon the next enforcement run, only those hosts listed within the `certificate-refresh_FORCE_renameMe-ON.txt` will first remove the certificate from the local Certificate Manager, then install the non-expiring replacement.
* Certificates removed from the `trusted-root-certificates` folder are automatically placed on a revocation list, `cert-revoked.txt`
  * Certificates present within the `cert-revoked.txt` are automatically removed from the local Certificate Manager.
  * Certificates with the same CN added back to the `trusted-root-certificates` folder are removed from the revocation list.
  * The text files used to track the presence and revocation of certificates are automatically backed up for redundancy. Restoration occurs when the original cert revocation files are missing or corrupted.

### Windows OS Enforcement
The following Windows 10/11 Operating System settings are enforced. Explorer.exe will not be rebooted in favor of an uninterrupted end-user experience. Instead, settings will take effect on the next reboot.
* Audit logging for `logon` and `logoff` events
* Windows File Explorer - Enable viewable file extensions

### Enforcement Checker
Enforcement checker runs via cron to check for proper file and folder hygiene. It ensure the requisite certificate and installer management files are present and formatted correctly. Email alerts are sent out if any issues are detected including certain informational and warning types.
#### Email Alerting
Email alerts will be generated with an attached log file if any of the following issues are detected by the `enforce-checker.sh` cron job:
* Installer management files are missing such as 'winget-install.txt' or the 'install-removal' directory is missing
  * Files and directories will be re-created without input or data
* Check installer management files for non-existent packages are executables
* Check if the Winget installer and uninstaller input files contain the same package
* Certificate management files are missing such as 'certificate-refresh-FORCE_renameMe-OFF.txt' or the 'trusted-root-certificates' directory is missing.
  * Files and directories will be re-created with default settings
* Certificate has been added to the revocation list and will be removed from all clients on their next enforcement run
  * Missing or corrupt certificate revocation management files and corrective actions.  
*  Ensure input files are properly formatted by replacing correct [POSIX](https://unix.stackexchange.com/questions/153091/how-to-add-a-carriage-return-before-every-newline) carriage returns and removes empty lines
*  Any certs expiring within 45 days or less
  * Will continue to alert until replaced with a non-expiring cert. All cert options should be identical, such as Subject, CN, and SAN.
  * Once the expiry is 14 days or less automatic replacements will occur. These expiring certs will be removed and then added during the 14-day window.
