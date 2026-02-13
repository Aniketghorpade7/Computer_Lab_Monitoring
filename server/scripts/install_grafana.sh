#!/bin/bash

set -e  #if one command fails scripts stops (atomicity)
set -x  #prints each command before excuting

# Install the dependancies
# apt-transport-https is needed to handle external repos.
#software-properties-common is a supporting utility that makes managing software repositories much easier and safer.
sudo apt-get install -y apt-transport-https software-properties-common wget

#impoerting the GPG key
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null

# update and install
sudo apt-get update
sudo apt-get install -y grafana

# starting the grafana servies
sudo systemctl daemon-reload
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

echo "Grafana Installation Script Complete!"
echo "Default port: 3000 | Default credentials: admin / admin"