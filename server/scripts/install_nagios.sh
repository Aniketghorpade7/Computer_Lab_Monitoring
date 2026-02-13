#!/bin/bash

set -e  #if one command fails scripts stops (atomicity)
set -x  #prints each command before excuting

NAGIOS_VER="4.4.14"
PLUGIN_VER="2.4.6"
NAGIOSADMIN_USER="nagiosadmin"
NAGIOSADMIN_PASS="it" 
HTPASSWD_FILE="/usr/local/nagios/etc/htpasswd.users"

#Installing the dependancies
sudo apt-get update
sudo apt-get install -y autoconf gcc libc6 make wget unzip apache2 php libapache2-mod-php libgd-dev libssl-dev

# Creating the nagcmd group allows the web UI to interact with the engine
if id "nagios" &>/dev/null; then
    echo "User nagios already exists. Skipping..."
else
    echo "Creating user nagios..."
    sudo useradd nagios || { echo "Failed to create user"; exit 1; }
fi
# Create nagcmd group if it doesn't exist
if getent group "nagcmd" > /dev/null; then
    echo "Group nagcmd already exists. Skipping..."
else
    echo "Creating group nagcmd..."
    sudo groupadd nagcmd || { echo "Failed to create group"; exit 1; }
fi
# Add nagios to nagcmd group if not already added
if id -nG "nagios" | grep -qw "nagcmd"; then
    echo "nagios already in nagcmd group. Skipping..."
else
    echo "Adding nagios to nagcmd group..."
    sudo usermod -a -G nagcmd nagios || { echo "Failed to modify nagios"; exit 1; }
fi
# Add www-data to nagcmd group if not already added
if id -nG "www-data" | grep -qw "nagcmd"; then
    echo "www-data already in nagcmd group. Skipping..."
else
    echo "Adding www-data to nagcmd group..."
    sudo usermod -a -G nagcmd www-data || { echo "Failed to modify www-data"; exit 1; }
fi

#Installing the nagios core
cd /tmp
wget https://assets.nagios.com/downloads/nagioscore/releases/nagios-${NAGIOS_VER}.tar.gz
tar -xvf nagios-${NAGIOS_VER}.tar.gz
cd nagios-${NAGIOS_VER}
# Compile
./configure --with-httpd-conf=/etc/apache2/sites-enabled
make all

# Installing binaries + configs + web UI
sudo make install-groups-users 
sudo make install
sudo make install-daemoninit
sudo make install-commandmode
sudo make install-config
sudo make install-webconf

# Download and compile nagios plugins
cd /tmp
wget https://nagios-plugins.org/download/nagios-plugins-${PLUGIN_VER}.tar.gz
tar -xvf nagios-plugins-${PLUGIN_VER}.tar.gz
cd nagios-plugins-${PLUGIN_VER}
#compile
./configure
make
sudo make install


#Set web credentials
echo "Configuring Web UI Credentials..."

if [ ! -f "$HTPASSWD_FILE" ]; then
    sudo htpasswd -bc "$HTPASSWD_FILE" "$NAGIOSADMIN_USER" "$NAGIOSADMIN_PASS"
    echo "Created new htpasswd file and added user $NAGIOSADMIN_USER."
else
    sudo htpasswd -b "$HTPASSWD_FILE" "$NAGIOSADMIN_USER" "$NAGIOSADMIN_PASS"
    echo "Updated $NAGIOSADMIN_USER in existing htpasswd file."
fi
    # Ensure the web server can read it
sudo chown www-data:www-data "$HTPASSWD_FILE"
sudo chmod 640 "$HTPASSWD_FILE"

# enabaling apache2
sudo a2enmod rewrite
sudo a2enmod cgi
sudo systemctl restart apache2

#Starting nagios daemon
sudo systemctl start nagios
sudo systemctl enable nagios

echo "Cleaning up build files..."
rm -rf /tmp/nagios-${NAGIOS_VER}
rm -rf /tmp/nagios-plugins-${PLUGIN_VER}