#!/bin/bash

# Manually execute to perform a lookup of a host's last runs on the network. Must be executed from the NAS device.
if [ ! -d "../damo_net_last-runs" ]
then
  echo "'damo_net_last-runs' folder not found or command was not executed from the NAS device.. exiting."
else
  printf "\n"
  echo "HOST - Last Run Date - Days Since Last Run - Exceeded 21 Days (X)"
  echo "-----------------------------------------------------------------"
  for filename in ../damo_net_last-runs/*.txt
  do
    exdays=""
    basefile=$filename
    host=$(basename $basefile | tr -d .txt)
    filedate=$(cat $filename)
    filedatelap=$(cat $filename | cut -d_ -f1 | cut -c 4-14 | sed 's/-//g' | sed 's/\(.*\)\(.\{4\}\)/\2\1/')
    currentdate=$(date '+%Y%m%d')
    let subtractdays=(`date +%s -d $currentdate`-`date +%s -d $filedatelap`)/86400

    if [ $subtractdays -ge 21 ]
    then
      exdays="X"
    fi

    echo "$host  -  $filedate  -  $subtractdays    $exdays"
  done
  printf "\n"
fi