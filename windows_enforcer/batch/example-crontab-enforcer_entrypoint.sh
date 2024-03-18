#!/bin/bash

# entrypoint to execute windows enforcer enforce-checker.sh via crontab
fullfilepath=$1
sed -i -e 's/\r$//' $fullfilepath
/bin/bash $fullfilepath
