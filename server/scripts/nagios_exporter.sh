#! /bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

set -e  # If one command fails, script stops
set -x  # Prints each command before executing

# Using the correct community exporter from Linode
NAGIOS_EXP_VERSION="1.2.2" 
USER="monitor_admin"
TMP_DIR="/tmp/nagios_exporter_install"
PROM_CONF="/etc/prometheus/prometheus.yml"

# 1. Sanity Check
if [ ! -f "$PROM_CONF" ]; then
    echo "Error: $PROM_CONF not found! Please run your Prometheus install script first."
    exit 1
fi

# 2. User Check
if id "$USER" &>/dev/null; then
    echo "User '$USER' already exists. Skipping creation."
else
    echo "User '$USER' does not exist. Creating..."
    useradd --system --no-create-home --shell /bin/false "$USER"
fi

# Clean up any failed previous attempts
rm -rf $TMP_DIR
mkdir -p $TMP_DIR
cd $TMP_DIR

# 3. Download from the correct valid repository
wget -c "https://github.com/linode-obs/nagios_exporter/releases/download/v${NAGIOS_EXP_VERSION}/nagios_exporter_${NAGIOS_EXP_VERSION}_Linux_x86_64.tar.gz"

# 4. Extract safely into a subfolder
mkdir -p extract_folder
tar xvf "nagios_exporter_${NAGIOS_EXP_VERSION}_Linux_x86_64.tar.gz" -C extract_folder

# 5. Move the binary (Named 'prometheus-nagios-exporter' by Linode)
find extract_folder -type f -name "prometheus-nagios-exporter" -exec mv {} /usr/local/bin/ \;
chown $USER:$USER /usr/local/bin/prometheus-nagios-exporter
chmod +x /usr/local/bin/prometheus-nagios-exporter

# 6. Create Nagios Exporter Systemd Service
# NOTE: Ensure the paths to nagiostats and nagios.cfg match your Nagios server!
cat <<EOF | tee /etc/systemd/system/nagios_exporter.service
[Unit]
Description=Nagios Exporter for Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=$USER
Group=$USER
Type=simple
ExecStart=/usr/local/bin/prometheus-nagios-exporter \\
    --nagios.stats_binary=/usr/local/nagios/bin/nagiostats \\
    --nagios.config_path=/usr/local/nagios/etc/nagios.cfg

Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 7. Connect Nagios to Prometheus (Linode exporter uses port 9927)
if grep -q "job_name: 'nagios'" "$PROM_CONF"; then
    echo "Nagios job already exists in prometheus.yml. Skipping append."
else
    echo "Appending Nagios job to prometheus.yml..."
    cat <<EOF >> "$PROM_CONF"

  - job_name: 'nagios'
    static_configs:
      - targets: ['localhost:9927']
EOF
fi

# 8. Reload Daemons and Start Services
systemctl daemon-reload
systemctl enable nagios_exporter
systemctl start nagios_exporter
systemctl restart prometheus

# 9. Cleanup
rm -rf $TMP_DIR

echo "Nagios Exporter Installation & Prometheus Connection Complete!"
systemctl status nagios_exporter --no-pager
