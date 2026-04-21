#! /bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

set -e  # If one command fails, script stops (atomicity)
set -x  # Prints each command before executing

# Variables
PROM_VERSION="2.50.1"
NAGIOS_EXP_VERSION="0.8.0" # Make sure to check for the latest version if needed
USER="monitor_admin"
TMP_DIR="/tmp/prometheus_install"

# 1. Create the System User (Fixes the missing user issue)
if ! id "$USER" &>/dev/null; then
    useradd --system --no-create-home --shell /bin/false "$USER"
fi

mkdir -p $TMP_DIR
cd $TMP_DIR

# 2. Download Core Prometheus & Nagios Exporter
wget -c "https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz"
wget -c "https://github.com/prometheus/nagios_exporter/releases/download/v${NAGIOS_EXP_VERSION}/nagios_exporter-${NAGIOS_EXP_VERSION}.linux-amd64.tar.gz"

# 3. Extract Binaries
tar xvf "prometheus-${PROM_VERSION}.linux-amd64.tar.gz"
tar xvf "nagios_exporter-${NAGIOS_EXP_VERSION}.linux-amd64.tar.gz"

# 4. Move Binaries to PATH and Set Permissions
mv "prometheus-${PROM_VERSION}.linux-amd64/prometheus" "prometheus-${PROM_VERSION}.linux-amd64/promtool" /usr/local/bin/
mv "nagios_exporter-${NAGIOS_EXP_VERSION}.linux-amd64/nagios_exporter" /usr/local/bin/

chown $USER:$USER /usr/local/bin/prometheus /usr/local/bin/promtool /usr/local/bin/nagios_exporter

# 5. Setup Prometheus Directories and Console Libraries
mkdir -p /etc/prometheus /var/lib/prometheus
cd "prometheus-${PROM_VERSION}.linux-amd64"
cp -r consoles console_libraries /etc/prometheus/

# 6. Create the Prometheus Configuration File (Includes Nagios Scrape Job)
cat <<EOF > /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # This is the translator job that pulls from the Nagios Exporter
  - job_name: 'nagios'
    static_configs:
      - targets: ['localhost:9115'] 
EOF

chown -R $USER:$USER /etc/prometheus /var/lib/prometheus

# 7. Create Prometheus Systemd Service
cat <<EOF | tee /etc/systemd/system/prometheus.service
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

# 8. Create Nagios Exporter Systemd Service
# Note: You may need to point --nagios.status-file to wherever your actual status.dat lives!
cat <<EOF | tee /etc/systemd/system/nagios_exporter.service
[Unit]
Description=Nagios Exporter for Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=$USER
Group=$USER
Type=simple
# Update the path below if your status.dat is located elsewhere
ExecStart=/usr/local/bin/nagios_exporter \
    --nagios.status-file=/usr/local/nagios/var/status.dat

Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 9. Reload and Start Services
systemctl daemon-reload
systemctl enable prometheus nagios_exporter
systemctl start prometheus nagios_exporter

# 10. Cleanup
rm -rf $TMP_DIR

echo "Prometheus and Nagios Exporter Installation Complete!"
systemctl status prometheus --no-pager
systemctl status nagios_exporter --no-pager
