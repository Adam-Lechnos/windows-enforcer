#!/bin/bash

cd "$(dirname "$0")"
if [ ! -d trusted-root-certificates ]; then echo "Trusted Root Cert folder not found (trusted-root-certificates).. exiting" && exit 1; fi
printf "\n"
echo "File Name - Subject - Expiration - Expires <= 45 Days (X)"
echo "-------------------------------------------------------------------------------------------------"
for certfile in trusted-root-certificates/*.crt
do
    exdays=""
    certfilename=$(basename $certfile)
    subject=$(openssl x509 -in $certfile -noout -subject | sed -e "s/ //g" | sed -n '/^subject/s/^.*CN=//p')
    expiry=$(openssl x509 -in $certfile -enddate -noout | cut -d'=' -f2)
    if ! openssl x509 -in $certfile -checkend 3888000 -noout >/dev/null
    then
      exdays="X"
    fi
    echo "$certfilename - $subject - $expiry    $exdays"
done
printf "\n"