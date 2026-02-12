#!/bin/bash

set -e      #if one command fails scripts stops (atomicity)

set -x      #prints each command before excuting

#Variable defining
MONITOR_USER="monitor_admin"
ALLOWED_PORTS=("80" "22" "3000" "9090")
TIMEZONE="UTC"

#Update the system first 
apt-get update && apt-get upgrade -y

#installing essential tools
apt install -y curl wget git ufw software-properties-common build-essential

#Checking of existance of user in system 
if ! getent passwd "$MONITOR_USER" > /dev/null; then
    echo "User does not exist, creating......"
    sudo useradd -m "$MONITOR_USER"
else
    echo "User exist :)"
fi

#Configuring the firewall
echo "Reseting the firewall to clean state"
sudo ufw --force reset

echo "Setting default policies"
sudo ufw default deny incomming
sudo ufw default allow outgoing

echo "Allowing OpenSSH for remote logging"
sudo ufw allow OpenSSH

echo "Allowing the required ports"
for PORT in "${ALLOWED_PORTS[@]}"
do
    sudo ufw allow "$PORT"
done

echo "Enabling the firewall"
sudo ufw --force enable

echo "Firewall status"
sudo ufw status verbose

#Setting up time zones
echo "Setting up timezone to $TIMEZONE"
sudo timedatectl set-timezone "$TIMEZONE"

sudo systemctl enable systemd-timesyncd
sudo systemctl start systemd-timesyncd
sudo systemctl restart systemd-timesyncd

sleep 3

echo "Current time status:"
timedatectl status

echo "NTP status:"
timedatectl show-timesync --all | head -n 15  

#creating dedicated directories for nagios and prometheus
echo "Creating directories for the essential services"

# Creating dir for prometheus (config and database)
sudo mkdir -p /etc/prometheus
sudo mkdir -p /var/lib/prometheus

# Creating dir for nagios (config)
sudo mkdir -p /etc/nagios

# Giving permissions to user
sudo chown "$MONITOR_USER":"$MONITOR_USER" /var/lib/prometheus
sudo chown "$MONITOR_USER":"$MONITOR_USER" /etc/prometheus

echo "Directories created and permissions set."