#! /bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

set -e  # If one command fails, script stops (atomicity)
set -x  # Prints each command before executing

# Variables
NAGIOS_EXP_VERSION="0.8.0" 
USER="monitor_admin"
TMP_DIR="/tmp/nagios_exporter_install"
PROM_CONF="/etc/prometheus/prometheus.yml"
NAGIOS_STATUS_FILE="/usr/local/nagios/var/status.dat"

# 1. Sanity Check: Ensure Prometheus is actually installed first
if [ ! -f "$PROM_CONF" ]; then
    echo "Error: $PROM_CONF not found! Please run your Prometheus install script first."
    exit 1
fi

# 2. Check and Create the System User (Skips if already created by Prometheus script)
if id "$USER" &>/dev/null; then
    echo "User '$USER' already exists. Skipping creation."
else
    echo "User '$USER' does not exist. Creating..."
    useradd --system --no-create-home --shell /bin/false "$USER"
fi

mkdir -p $TMP_DIR
cd $TMP_DIR

# 3. Download & Extract Nagios Exporter
wget -c "https://github.com/prometheus/nagios_exporter/releases/download/v${NAGIOS_EXP_VERSION}/nagios_exporter-${NAGIOS_EXP_VERSION}.linux-amd64.tar.gz"
tar xvf "nagios_exporter-${NAGIOS_EXP_VERSION}.linux-amd64.tar.gz"

# 4. Move Binary to PATH and Set Permissions
mv "nagios_exporter-${NAGIOS_EXP_VERSION}.linux-amd64/nagios_exporter" /usr/local/bin/
chown $USER:$USER /usr/local/bin/nagios_exporter

# 5. Create Nagios Exporter Systemd Service
cat <<EOF | tee /etc/systemd/system/nagios_exporter.service
[Unit]
Description=Nagios Exporter for Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=$USER
Group=$USER
Type=simple
ExecStart=/usr/local/bin/nagios_exporter \
    --nagios.status-file=${NAGIOS_STATUS_FILE}

Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 6. Connect Nagios to Prometheus (Append to prometheus.yml safely)
# This checks if the job already exists so it doesn't duplicate lines if you run the script twice
if grep -q "job_name: 'nagios'" "$PROM_CONF"; then
    echo "Nagios job already exists in prometheus.yml. Skipping append."
else
    echo "Appending Nagios job to prometheus.yml..."
    cat <<EOF >> "$PROM_CONF"

  - job_name: 'nagios'
    static_configs:
      - targets: ['localhost:9115']
EOF
fi

# 7. Reload Daemons and Start/Restart Services
systemctl daemon-reload

# Enable and start the new exporter
systemctl enable nagios_exporter
systemctl start nagios_exporter

# Restart Prometheus so it reads the newly appended scrape job configuration
systemctl restart prometheus

# 8. Cleanup
rm -rf $TMP_DIR

echo "Nagios Exporter Installation & Prometheus Connection Complete!"
systemctl status nagios_exporter --no-pager
