#!/bin/bash

# Manually execute to perform a lookup of a host's last runs on the network. Must be executed from the NAS device.

if [ ! -d "../damo_net_last-runs" ]
then
  echo "'damo_net_last-runs' folder not found or command was not executed from the NAS device.. exiting."
else
  echo HOST - Last Run
  echo ---------------
  for filename in ../damo_net_last-runs/*.txt
  do
    basefile=$filename
    host=$(basename $basefile | tr -d .txt)
    filedate=$(cat $filename)
    echo $host - $filedate
  done
fi