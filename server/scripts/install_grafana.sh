#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

set -e  #if one command fails scripts stops (atomicity)
set -x  #prints each command before excuting

# Install the dependancies
# apt-transport-https is needed to handle external repos.
#software-properties-common is a supporting utility that makes managing software repositories much easier and safer.
apt-get install -y apt-transport-https software-properties-common wget

#impoerting the GPG key
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null

# ADD THE REPOSITORY
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" \
> /etc/apt/sources.list.d/grafana.list

# update and install
apt-get update
apt-get install -y grafana

# starting the grafana servies
systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server

echo "Grafana Installation Script Complete!"
echo "Default port: 3000 | Default credentials: admin / admin"