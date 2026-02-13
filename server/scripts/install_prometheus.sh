#! /bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

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
mv prometheus promtool /usr/local/bin/
chown $USER:$USER /usr/local/bin/prometheus
chown $USER:$USER /usr/local/bin/promtool

# Prometheus comes with console libraries and a sample config
mkdir -p /etc/prometheus
cp -r consoles console_libraries /etc/prometheus/
cp prometheus.yml /etc/prometheus/prometheus.yml

# Ensure permissions are correct for our service user
chown -R $USER:$USER /etc/prometheus
chown -R $USER:$USER /var/lib/prometheus

# 7. Create the Systemd Service File
# This is a "Here Document" that writes the service configuration
cat <<EOF |  tee /etc/systemd/system/prometheus.service
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
 systemctl daemon-reload
 systemctl enable prometheus
 systemctl start prometheus

# 9. Cleanup
rm -rf $TMP_DIR

echo "Prometheus Installation Complete!"
systemctl status prometheus --no-pager
