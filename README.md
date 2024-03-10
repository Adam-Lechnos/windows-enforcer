# enforcement-script-windows
Enforce a suite of Installs, OS Settings, and Trusted Root Certificates with an output file sent to email when any issues or warnings are detected.

This is where automation and enforcement scripts are synchronized to Windows client hosts within Damo.net.

### Pre-reqs
1. [Winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/) installed on each target host

### Installation steps for all new clients
1. Ensure the client is connected to the workgroup, DAMO.NET
2. Copy the file script\batch\first_run_enforcement_checks.bat, locally to the the C drive from the NAS server, ensuring the client is on an DAMO.NET network.
3. Ensure the NAS is mapped as drive Z, if not, ensure you can ping 10.10.0.10, the NAS server. (Note: If any other drive is mapped to Z, the script will fail)
4. Start an elevated command prompt, then execute the locally copied file.
5. Check the C:\scripts folder, ensuring the files 'C:\scripts\batch\first_run_enforcement_checks.bat' and 'First Run Enforcement Checks.xml' exist.
6. Delete the manually executed 'first_run_enforcement_checks.bat' file (which should *not* be the C:\script\batch\first_run_enforcement_checks.bat copy).

### Updating files
From the NAS drive's enforcement folder, make changes to any file and it will sync and either execute or install.

**IMPORTANT** Never change the name of the file, script\batch\first_run_enforcement_checks.bat, either within the NAS directory or locally on any client. If the 'First Run Enforcement Checks' scheduled task is ever deleted or modified, the above steps should be followed.

### Feature Flags
The First Run Enforcement Script contains a feature flag folder, editable on the NAS enforcement folder, \scripts\batch\featureFlags-first-run_enforcement_checks
Each file may be set to ON by updating the appended name accordingly.

#### Feature Flag file details - file names below are case/spelling sensitive:
* certificate-refresh-renameMe-ON.txt --> This file is managed by the program and should not be modified; used to track which certs are slated for refresh based on their expiry. certs expiring within 15 days are added to this list. new certs should be replaced using the same values and cert file name. 
* certificate-refresh_FORCE_renameMe-OFF.txt --> Rename with OFF set to ON and add hostnames for hosts that require a full cert refresh. only used for hosts that have been offline long enough to miss certificate replacements. set back to OFF when not in use. 

### Logging
Scripts executed manually will output logging data to the logged-in user's temp directory --> %temp%\damo-net\logs (C:\Users\<user>\AppData\Local\Temp\damo_net)
Scripts executed via task scheduler, even if executed manually, will output logging data from the system's specified log directory --> %temp%\damo-net\logs (C:\Windows\temp)
A new log is generated with the execution's point-in-time date and time stamp appended.

### How the process works
The file will first create and copy itself to C:\scripts\batch, then kick off the file sync between the NAS enforcement folder and the C:\scripts folder locally.
Once syncing completes, all the required files, scripts, and scheduled tasks will be created and then executed.

The 'First Run Enforcement Checks' scheduled task re-runs the above process from within the scripts folder every startup, and then every 2 hours indefinitely.
Any changes made to the scripts directory will automatically be copied to the clients, enabling a method for centrally managing Windows clients.
All scheduled tasks are located within the newly created Damo.net folder. (within the Task Scheduler program)

If the client is off the network, the script will attempt to execute enforcement tasks, which are expected to fail if at least one sync has not occurred or if the files were deleted within the local scripts folder. The next successful re-sync will re-create any missing files.

### Managing Installs
Downloads packages to the C:\Tools folder, except for those that are obtained via the Winget package manager, in which case are installed according to the Winget process. Note, that only the data is downloaded to the C:\Tools folder. Subsequent installs must occur manually post the data retrieval if required. Use this feature for pulling down simple packages. Subsequent download attempts are ignored for each install in which its corresponding directory gets created. For Winget, the script first checks the Winget list command for existing installs. Upgrades are not attempted once the installation is completed. Use Winget update --all instead.

There are three files within the scripts\batch folder which reference the following install methods:
* winget-install.txt - Specify the official widget package names you would like installed. (Recommended). Values are case-sensitive. Use https://winstall.app to check the package name speelling.
* github-release-installs.txt - specify a list of downloadable repo packages against repos that utilize the GitHub package release feature. Use OWNER/REPO format.
* github-raw-installs.txt - specify the full URLs against a raw GitHub downloadable, pointing to the raw.githubusercontent.com domain.

Except for 'widget-install.txt', items removed from the text files will result in their respective directory removal from C:\Tools only. You must still uninstall packages installed via an installer, hence, these methods, except for Winget, should only be used for simple executables.
