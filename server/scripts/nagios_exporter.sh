#!/usr/bin/env bash

set -euo pipefail
set -x

USER="monitor_admin"
TMP_DIR="/tmp/nagios_exporter_install"
PROM_CONF="/etc/prometheus/prometheus.yml"
SERVICE_FILE="/etc/systemd/system/nagios_exporter.service"

# 1. Root check
if [[ $EUID -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

# 2. Prometheus config check
if [[ ! -f "$PROM_CONF" ]]; then
  echo "Error: $PROM_CONF not found! Install Prometheus first."
  exit 1
fi

# 3. Create system user if not exists
if id "$USER" &>/dev/null; then
  echo "User exists"
else
  useradd --system --no-create-home --shell /usr/sbin/nologin "$USER"
fi

# 4. Prepare temp directory
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

# 5. Fetch latest release dynamically
echo "Fetching latest Nagios exporter release..."
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/linode-obs/nagios_exporter/releases/latest \
  | grep browser_download_url \
  | grep -E "linux.*amd64|Linux_x86_64" \
  | cut -d '"' -f 4 \
  | head -n 1)

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "Failed to fetch download URL"
  exit 1
fi

wget -q --show-progress "$DOWNLOAD_URL"

# 6. Extract archive
ARCHIVE_NAME=$(basename "$DOWNLOAD_URL")
tar -xf "$ARCHIVE_NAME"

# 7. Find and install binary
BINARY_PATH=$(find . -type f -executable | grep -E "nagios.*exporter" | head -n 1)
if [[ -z "$BINARY_PATH" ]]; then
  echo "Binary not found in archive"
  exit 1
fi

install -m 0755 "$BINARY_PATH" /usr/local/bin/prometheus-nagios-exporter
chown "$USER:$USER" /usr/local/bin/prometheus-nagios-exporter

# 8. Create systemd service
cat <<EOF > "$SERVICE_FILE"
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

# 9. Update Prometheus config safely
if ! grep -q "job_name: 'nagios'" "$PROM_CONF"; then
  echo "Adding Nagios job to Prometheus config..."

  cat <<EOF >> "$PROM_CONF"

  - job_name: 'nagios'
    static_configs:
      - targets: ['localhost:9927']
EOF
else
  echo "Prometheus job already exists"
fi

# 10. Reload and start services
systemctl daemon-reexec
systemctl daemon-reload

systemctl enable nagios_exporter
systemctl restart nagios_exporter
systemctl restart prometheus

# 11. Cleanup
rm -rf "$TMP_DIR"

# 12. Status
systemctl status nagios_exporter --no-pager

echo "Nagios Exporter installation completed successfully"
