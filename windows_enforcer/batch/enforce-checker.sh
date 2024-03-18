#!/bin/bash

cd "$(dirname "$0")"
outputlist="./enforce-issues.txt"

if [ -f $outputlist ]
then
    rm $outputlist
fi

#echo "[info] Working Directory: $(pwd)" >> $outputlist

## check for install management input files and directories and create if missing
if ! [ -f ./winget-installs.txt ]
then
  touch ./winget-installs.txt
  echo "install management file missing and re-created - winget-installs.txt" >> $outputlist
fi

if ! [ -f ./winget-uninstalls.txt ]
then
  touch ./winget-uninstalls.txt
  echo "install management file missing and re-created - winget-uninstalls.txt" >> $outputlist
fi

if ! [ -f ./github-release-install.txt ]
then
  touch ./github-release-install.txt
  echo "install management file missing and re-created - github-release-install.txt" >> $outputlist
fi

if ! [ -f ./github-raw-installs.txt ]
then
  touch ./github-raw-installs.txt
  echo "install management file missing and re-created - github-raw-installs.txt" >> $outputlist
fi

if ! [ -d ./install-removal ]
then
  mkdir ./install-removal
  echo "install management directory missing and re-created - install-removal" >> $outputlist
fi

if ! [ -d ./cert-removal ]
then
  mkdir ./cert-removal
  echo "cert removal directory missing and re-created - cert-removal" >> $outputlist
fi

# ensuring scripts folder exist
if ! [ -d ./../../scripts ]
then
  mkdir ./../../scripts
  echo "scripts folder missing and re-created - script management" >> $outputlist
fi

# ensure task schedular management files exist
if ! [ -f "./First Run Enforcement Checks.xml" ]
then
  echo "'First Run Enforcement Checks.xml' is missing - task scheduler management" >> $outputlist
fi

if ! [ -f "../powershell/Network Adapters - All - Reset.xml" ]
then
  echo "'Network Adapters - All - Reset.xml' is missing - task scheduler management" >> $outputlist
fi

if ! [ -f "../powershell/Network_Adaperts-All-Reset-Default.ps1" ]
then
  echo "'Network_Adaperts-All-Reset-Default.ps1' is missing - task scheduler management" >> $outputlist
fi

# restore backup copy of certificate-present-list if the original file is missing or corrupt
if ! [ -f ./cert-removal/certificate-present-list.txt ] && [ -f ./cert-removal/certificate-present-list-backup.txt ]
then
  mv ./cert-removal/certificate-present-list-backup.txt ./cert-removal/certificate-present-list.txt
  echo "cert removal list - restored backup copy of 'certificate-present-list'" >> $outputlist
fi

# create on empty certificate-present-list both original and backup copies are missing. This will cause temporary revokation of existing certs.
if ! [ -f ./cert-removal/certificate-present-list.txt ]
then
  touch ./cert-removal/certificate-present-list.txt
  echo "cert removal list - no 'certificate-present-list' or backup copy exists. An empty list was created. Existing cert files in 'trusted-root-certifcates' folder will be revoked then re-added on the next two client runs respectively." >> $outputlist
fi

## ensure proper carriage returns in input files
sed -i -e 's/\r$//' ./winget-installs.txt 2>&1>/dev/null
sed -i -e 's/\r$//' ./winget-uninstalls.txt 2>&1>/dev/null
sed -i -e 's/\r$//' ./github-release-install.txt 2>&1>/dev/null
sed -i -e 's/\r$//' ./github-raw-installs.txt 2>&1>/dev/null
sed -i -e 's/\r$//' ./cert-removal/cert-revoked.txt 2>&1>/dev/null
sed -i -e 's/\r$//' ./cert-removal/certificate-present-list.txt 2>&1>/dev/null
sed -i -e 's/\r$//' ../../last-runs-check.sh 2>&1>/dev/null

## check winget list
listwinget="./winget-installs.txt"
while read -r line || [ -n "$line" ]
do
  retry_curl=0
  while [ $retry_curl -le 5 ]
  do
    curl --retry 3 -s https://winstall.app/apps/$line | grep 'To install' >/dev/null
    rc=$?
    if (($rc == 1))
    then
      retry_curl=$(($retry_curl + 1))
      if [ $retry_curl -eq 6 ]
      then
        echo winget issue = $line >> $outputlist
      fi
    else
      break
    fi
  done
done < "$listwinget"

## check winget uninstall list
listwingetrm="./winget-uninstalls.txt"
while read -r line || [ -n "$line" ]
do
  retry_curl=0
  while [ $retry_curl -le 5 ]
  do
    curl --retry 3 -s https://winstall.app/apps/$line | grep 'To install' >/dev/null
    rc=$?
    if (($rc == 1))
    then
      retry_curl=$(($retry_curl + 1))
      if [ $retry_curl -eq 6 ]
      then
        echo winget issue = $line >> $outputlist
      fi
    else
      break
    fi
  done
done < "$listwingetrm"

## check github release list
listghrelease="./github-release-install.txt"
while read -r line || [ -n "$line" ]
do
  curl -ks https://api.github.com/repos/$line/releases/latest ^| grep "browser_download_url" >/dev/null
  rc=$?
  #echo $rc
  if ((rc == 1))
  then
    echo gihtub release issue = $line >> $outputlist
  fi
done < "$listghrelease"

## check github raw list
listghrelease="./github-raw-installs.txt"
while read -r line || [ -n "$line" ]
do
  sc=$(curl -s -o /dev/null -w '%{http_code}' $line)
  #echo $sc
  if [ $sc -ne 200 ]
  then
    echo gihtub raw issue = $line >> $outputlist
  fi
done < "$listghrelease"

## feature flag folder and file checker
fffolder="./featureFlags-first-run_enforcement_checks"
if [ ! -d $fffolder ]
then 
  mkdir featureFlags-first-run_enforcement_checks
  echo "feature flag = [$fffolder] parent folder missing and was re-created" >> $outputlist
fi

## cert force refresh list checker
if [ ! -f $fffolder/certificate-refresh_FORCE_renameMe-*.txt ]
then
  touch $fffolder/certificate-refresh_FORCE_renameMe-OFF.txt
  echo "feature flag = [certificate-refresh_FORCE_renameMe-OFF.txt] file missing and was re-created" >> $outputlist
fi
## ensure proper carriage returns
sed -i -e 's/\r$//' $fffolder/certificate-refresh_FORCE_renameMe-*.txt

## check certificate force refresh list
certforceref=$fffolder/certificate-refresh_FORCE_renameMe-ON.txt
if [ -f $certforceref ]
then
  while read -r line || [ -n "$line" ]
  do
    if nslookup $line | grep -w 'No answer'
    then
      echo "cert force refresh list - '$line' is not an accessible hostname. Correct the hostname within the refresh list" >> $outputlist
    fi
  done < "$certforceref"
fi

## trusted root certificate checks
rootcertdir="../../trusted-root-certificates"
#echo "[info] Root Cert Directory: $rootcertdir" >> $outputlist
if [ ! -d $rootcertdir ]
then
  mkdir $rootcertdir
fi

# if [ -f $fffolder/certificate-refresh_renameMe-ON.txt ]
# then
#   rm $fffolder/certificate-refresh_renameMe-ON.txt
#   echo $fffolder/certificate-refresh_renameMe-ON.txt
# fi

if [ -f $fffolder/certificate-refresh_FORCE_LIST.txt ] || [ -f $fffolder/certificate-refresh_FORCE_renameMe-OFF.txt ]
then
  rm -f $fffolder/certificate-refresh_FORCE_LIST.txt 
fi

if [ -z "$(ls -A $rootcertdir)" ]
then

  echo "cert folder $rootcertdir is empty - skipping enumeration of certifcates"
  listlastruncrt="./cert-removal/certificate-present-list.txt"
  while read -r line || [ -n "$line" ]
  do
    echo $line >> ./cert-removal/cert-revoked.txt
    sed -i "s/$line//" ./cert-removal/certificate-present-list.txt 2>&1>/dev/null
    echo cert revocation - $line >> $outputlist
  done < "$listlastruncrt"
  awk -i inplace '!seen[$0]++' ./cert-removal/cert-revoked.txt 2>&1>/dev/null
  sed -i '/^$/d' ./cert-removal/certificate-present-list.txt 2>&1>/dev/null
  sed -i '/^$/d' ./cert-removal/cert-revoked.txt 2>&1>/dev/null

else

  for certfile in $rootcertdir/*.crt
  do
    
    ## create list of certs to check for removal on current run
    listpresentcertscr=$(openssl x509 -in $certfile -noout -subject | sed -e "s/ //g" | sed -n '/^subject/s/^.*CN=//p')
    echo $listpresentcertscr >> ./cert-removal/certificate-present-list-current-run.txt

    ## reconcile both cert removal lists to check for cert removal action
    listlastruncrt="./cert-removal/certificate-present-list.txt"
    while read -r line || [ -n "$line" ]
    do
      if ! cat ./cert-removal/certificate-present-list-current-run.txt | grep -w $line >/dev/null
      then
        echo $line >> ./cert-removal/cert-revoked.txt
        sed -i "s/$line//" ./cert-removal/certificate-present-list.txt 2>&1>/dev/null
        echo cert revocation - $line >> $outputlist
      fi
    done < "$listlastruncrt"
    awk -i inplace '!seen[$0]++' ./cert-removal/cert-revoked.txt 2>&1>/dev/null
    sed -i '/^$/d' ./cert-removal/cert-revoked.txt

    ## create list of certs to check for removal on next run
    listpresentcerts=$(openssl x509 -in $certfile -noout -subject | sed -e "s/ //g" | sed -n '/^subject/s/^.*CN=//p')
    if ! cat ./cert-removal/certificate-present-list.txt | grep -w $listpresentcerts >/dev/null
    then
      echo $listpresentcerts >> ./cert-removal/certificate-present-list.txt
    fi
    sed -i '/^$/d' ./cert-removal/certificate-present-list.txt 2>&1>/dev/null
    rm -f ./cert-removal/certificate-present-list-current-run.txt 2>&1>/dev/null

    ## remove cert from revocation list if cert CN is the same as a revoked cert - for newly added certs (assumes new expiration date and fingerprint)
    removerevoke=$(openssl x509 -in $certfile -noout -subject | sed -e "s/ //g" | sed -n '/^subject/s/^.*CN=//p')
    if cat ./cert-removal/cert-revoked.txt | grep -w $removerevoke >/dev/null
    then
      sed -i "s/$removerevoke//" ./cert-removal/cert-revoked.txt 2>&1>/dev/null
      sed -i '/^$/d' ./cert-removal/cert-revoked.txt
      echo cert revocation removal - $removerevoke >> $outputlist
    fi

    ## force refresh cert list for opted in hosts
    if [ -f $fffolder/certificate-refresh_FORCE_renameMe-ON.txt ]
    then
      listcertforce=$(openssl x509 -in $certfile -noout -subject | sed -e "s/ //g" | sed -n '/^subject/s/^.*CN=//p')
      echo $listcertforce >> $fffolder/certificate-refresh_FORCE_LIST.txt
      echo "cert force refresh active = [certificate-refresh_FORCE_renameMe-ON.txt] is active - opted in hosts will first remove all available certs within '$rootcertdir' for hosts listed in 'certificate-refresh_FORCE_LIST.txt'" >> $outputlist
    fi

    ## warning at 45 days or less expiry
    if ! openssl x509 -in $certfile -checkend 3888000 -noout >/dev/null
    then
      echo "cert issue = [$certfile] warning for cert expiry within 45 days or less of the cert's expiry; renewal must occur at least 15 days prior to the expiry and replaced within the 'trusted-root-certificates' directory" >> $outputlist
    fi

    ## add the cert to feature flag file for replacement at 14 days or less expiry
    if ! openssl x509 -in $certfile -checkend 1209600 -noout >/dev/null
    then
    
      echo "cert issue = [$certfile] cert expiry has crossed the threshold warning set at 2 weeks before or less then the expiration date of the cert or cert is invalid" >> $outputlist
      certname=$(openssl x509 -in $certfile -noout -subject | sed -e "s/ //g" | sed -n '/^subject/s/^.*CN=//p')
      if ! grep -w $certname $fffolder/certificate-refresh_renameMe-ON.txt
      then
        echo $certname >> $fffolder/certificate-refresh_renameMe-ON.txt
        echo "cert issue = [$certfile] added to feature flag file for cert refresh with CN=$certname" >> $outputlist
      fi

    else
      certnameRem=$(openssl x509 -in $certfile -noout -subject | sed -e "s/ //g" | sed -n '/^subject/s/^.*CN=//p')
      sed -i $fffolder/certificate-refresh_renameMe-ON.txt -e "s/$certnameRem//g"
    fi

   ## check if cert was removed from the trusted-root-certificates directory


  done
  ## remove empty lines from cert feature flag file
  sed -i '/^$/d' $fffolder/certificate-refresh_renameMe-ON.txt

fi

## make backup copies of cert removal management lists
cp ./cert-removal/cert-revoked.txt ./cert-removal/cert-revoked-backup.txt
cp ./cert-removal/certificate-present-list.txt ./cert-removal/certificate-present-list-backup.txt

## perform client last run checks, ensuring that each client has performed a successful run in the last 28 days.
if [ ! -d "../../../damo_net_last-runs" ]
then
  mkdir "../../../damo_net_last-runs"
  echo "last runs issue = 'damo_net_last-runs' folder not found and re-created" >> $outputlist
else
  for filename in ../../../damo_net_last-runs/*.txt
  do
    sed -i -e 's/\r$//' $filename
    filedate=$(cat $filename | cut -d- -f2)
    currentdate=$(date | cut -d' ' -f3)
    subtractdays=$(($currentdate-$filedate))
    basefile=$filename
    host=$(basename $basefile | tr -d .txt)
    nslookup $host | grep -i 'no answer' >/dev/null
    rc=$?
    if (($rc == 0))
    then
    echo "nslookup failed = host is not in DNS. If this is expected then remove the hostname file from 'damo_net_last-runs or it will eventually report 'last runs' errors as well at' - $host" >> $outputlist
    fi

    if [ $subtractdays -ge 28 ]
    then
      echo "last runs = host run has not occured in at least the last 28 days - $host" >> $outputlist
    fi
  done
fi

## if enforce warnings or issues exist, send as email attachment
if [ -f  $outputlist ]
then
    echo "emailing list"
    echo "Enforce checker script has detected info, issues, and warnings. Refer to the attached text file for details." | mail -A "./enforce-issues.txt" -s "Host Enforcement Checker" -- adam.lechnos@gmail.com
fi

## outputting last run txt
date > last_run_enforce-checker.txt