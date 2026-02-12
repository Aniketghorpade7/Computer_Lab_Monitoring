#!/bin/bash

set -e      #if one command fails scripts stops (atomicity)

set -x      #prints each command before excuting

#Variable defining
MONITOR_USER="monitor_admin"
ALLOWED_PORTS=("80" "22" "3000" "9090")

#Update the system first 
apt-get update && apt-get upgrade -y

#installing essential tools
apt install curl wget git ufw software-properties-common build-essential

#Checking of existance of user in system 
if ! getent passwd "$MONITOR_USER" > /dev/null; then
    echo "User does not exist, creating......"
    sudo useradd -m "$MONITOR_USER"
else
    echo "User exist :)"
fi
