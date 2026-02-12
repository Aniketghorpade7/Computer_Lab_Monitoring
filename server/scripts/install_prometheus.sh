#! /bin/bash

set -e  #if one command fails scripts stops (atomicity)

set -x  #prints each command before excuting

# Variables
VERSION="2.50.1"
USER="monitor_admin"
TMP_DIR="/tmp/prometheus_install"

mkdir -p $TMP_DIR
cd $TMP_DIR

# Downloading the binary
wget -c "https://github.com/prometheus/prometheus/releases/download/v${VERSION}/prometheus-${VERSION}.linux-amd64.tar.gz"

# Extract
tar xvf "prometheus-${VERSION}.linux-amd64.tar.gz"
cd "prometheus-${VERSION}.linux-amd64"

# Moving to /usr/local/bin ensures they are in the system PATH
sudo mv prometheus promtool /usr/local/bin/
sudo chown $USER:$USER /usr/local/bin/prometheus
sudo chown $USER:$USER /usr/local/bin/promtool

# Prometheus comes with console libraries and a sample config
sudo cp -r consoles console_libraries /etc/prometheus/
sudo cp prometheus.yml /etc/prometheus/prometheus.yml

# Ensure permissions are correct for our service user
sudo chown -R $USER:$USER /etc/prometheus
sudo chown -R $USER:$USER /var/lib/prometheus

# 7. Create the Systemd Service File
# This is a "Here Document" that writes the service configuration
cat <<EOF | sudo tee /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus Monitoring Engine
Wants=network-online.target
After=network-online.target

[Service]
User=$USER
Group=$USER
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries \
    --web.listen-address=0.0.0.0:9090

Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 8. Reload and Start
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

# 9. Cleanup
rm -rf $TMP_DIR

echo "Prometheus Installation Complete!"
systemctl status prometheus --no-pager
