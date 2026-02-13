#!/bin/bash

set -e
set -x

NAGIOS_VER="4.4.14"
PLUGIN_VER="2.4.6"
HTPASSWD_FILE="/usr/local/nagios/etc/htpasswd.users"

echo "Stopping Nagios..."

sudo systemctl stop nagios || true
sudo systemctl disable nagios || true

echo "Removing Nagios service files..."

sudo rm -f /etc/systemd/system/nagios.service
sudo rm -f /lib/systemd/system/nagios.service
sudo systemctl daemon-reload

echo "Removing Nagios directories..."

sudo rm -rf /usr/local/nagios
sudo rm -rf /usr/local/bin/nagios*
sudo rm -rf /usr/local/libexec

echo "Removing Apache Nagios config..."

sudo rm -f /etc/apache2/sites-enabled/nagios.conf
sudo rm -f /etc/apache2/conf-enabled/nagios.conf
sudo rm -f /etc/apache2/conf-available/nagios.conf

echo "Removing htpasswd..."

sudo rm -f "$HTPASSWD_FILE"

echo "Disabling Apache modules..."

sudo a2dismod cgi || true
sudo a2dismod rewrite || true

echo "Restarting Apache..."

sudo systemctl restart apache2

echo "Removing nagcmd group..."

if getent group nagcmd >/dev/null; then
    sudo groupdel nagcmd
fi

echo "Removing nagios user..."

if id nagios >/dev/null 2>&1; then
    sudo userdel -r nagios || sudo userdel nagios
fi

echo "Removing www-data from nagcmd (if still exists)..."

sudo gpasswd -d www-data nagcmd || true

echo "Removing build artifacts..."

rm -rf /tmp/nagios-${NAGIOS_VER}*
rm -rf /tmp/nagios-plugins-${PLUGIN_VER}*

echo "Optionally removing installed packages..."

sudo apt-get purge -y \
autoconf gcc make wget unzip apache2 php libapache2-mod-php \
libgd-dev libssl-dev || true

sudo apt-get autoremove -y
sudo apt-get autoclean

echo "Rollback complete."
