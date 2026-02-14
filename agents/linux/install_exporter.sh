#!/bin/bash 

set -e
# Exit on Error. Stops the script if any command fails.

# --- Variables ---
VERSION="1.7.0"

# Detect Architecture automatically
OS_ARCH=$(uname -m)
if [ "$OS_ARCH" = "x86_64" ]; then
    ARCH="linux-amd64"
elif [ "$OS_ARCH" = "aarch64" ]; then
    ARCH="linux-arm64"
else
    ARCH="linux-386"
fi

#--- Install Prerequisites ---
echo "Installing prereuisties
(curl)..."
sudo apt-get update
sudo apt-get install -y curl


# Define explicit paths in /tmp to avoid permission issues in project folders
DOWNLOAD_PATH="/tmp/node_exporter-${VERSION}.${ARCH}.tar.gz"
EXTRACT_DIR="/tmp/node_exporter-${VERSION}.${ARCH}"

# --- User Management ---
if ! id -u node_exporter >/dev/null 2>&1; then
    echo "Creating node_exporter system user..."
    sudo useradd --no-create-home --shell /bin/false node_exporter
fi

# --- Download & Extract ---
echo "Cleaning up old temporary files..."
sudo rm -f "$DOWNLOAD_PATH"
sudo rm -rf "$EXTRACT_DIR"

echo "Downloading Node Exporter v${VERSION} to $DOWNLOAD_PATH..."
# Using sudo with curl to ensure write access to /tmp
sudo curl -L "https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/node_exporter-${VERSION}.${ARCH}.tar.gz" -o "$DOWNLOAD_PATH"

echo "Extracting archive to /tmp..."
sudo tar -xvf "$DOWNLOAD_PATH" -C /tmp/

# --- Installation ---
echo "Moving binary to /usr/local/bin..."
sudo mv "$EXTRACT_DIR/node_exporter" /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

# --- Systemd Service Creation ---
echo "Creating systemd service..."
sudo tee /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# --- Start Service ---
echo "Reloading systemd and starting service..."
sudo systemctl daemon-reload 
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

# --- Verification ---
echo "Verifying service metrics..."
sleep 2 # Give the service a second to bind to the port

if curl -s localhost:9100/metrics | grep -q "node_cpu_seconds_total"; then
   echo "------------------------------------------------"
   echo "Verification Success: Node Exporter is ONLINE!"
   echo "------------------------------------------------"
else
   echo "Verification Failed: Service is running but metrics are unreachable."
   exit 1
fi

# --- Firewall ---
if command -v ufw > /dev/null; then
    echo "Updating UFW firewall rules..."
    sudo ufw allow 9100/tcp
fi

# --- Cleanup ---
sudo rm -rf "$EXTRACT_DIR"
sudo rm -f "$DOWNLOAD_PATH"

echo "Installation complete!"
