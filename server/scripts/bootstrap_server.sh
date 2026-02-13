#!/bin/bash
#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "Run as root"
   exit 1
fi


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
    useradd -m "$MONITOR_USER"
else
    echo "User exist :)"
fi

#Configuring the firewall
echo "Reseting the firewall to clean state"
ufw --force reset

echo "Setting default policies"
ufw default deny incomming
ufw default allow outgoing

echo "Allowing OpenSSH for remote logging"
ufw allow OpenSSH

echo "Allowing the required ports"
for PORT in "${ALLOWED_PORTS[@]}"
do
    ufw allow "$PORT"
done

echo "Enabling the firewall"
ufw --force enable

echo "Firewall status"
ufw status verbose

#Setting up time zones
echo "Setting up timezone to $TIMEZONE"
timedatectl set-timezone "$TIMEZONE"

systemctl enable systemd-timesyncd
systemctl start systemd-timesyncd
systemctl restart systemd-timesyncd

sleep 3

echo "Current time status:"
timedatectl status

echo "NTP status:"
timedatectl show-timesync --all | head -n 15  

#creating dedicated directories for nagios and prometheus
echo "Creating directories for the essential services"

# Creating dir for prometheus (config and database)
mkdir -p /etc/prometheus
mkdir -p /var/lib/prometheus

# Creating dir for nagios (config)
mkdir -p /etc/nagios

# Giving permissions to user
chown "$MONITOR_USER":"$MONITOR_USER" /var/lib/prometheus
chown "$MONITOR_USER":"$MONITOR_USER" /etc/prometheus

echo "Directories created and permissions set."