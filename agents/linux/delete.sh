#!/bin/bash
# Line 1: The "Shebang." It tells the OS to use the Bash interpreter to run this file.

set -e
# Line 2: "Exit on Error." If any command fails, the script stops immediately. 
# This prevents "cascading failures" where one error breaks everything that follows.

# --- 1. Variables ---
VERSION="1.7.0"
ARCH="linux-amd64"
# Lines 5-6: We define variables so we don't have to type the version number multiple times. 
# It makes updating the script in the future much easier.

# --- 2. User Management ---
if ! id -u node_exporter >/dev/null 2>&1; then
    sudo useradd --no-create-home --shell /bin/false node_exporter
fi
# Lines 10-12: This is an "Idempotent" check. It asks "Does user node_exporter exist?"
# If not, it creates a SYSTEM user. 
# --no-create-home: This user doesn't need a /home folder.
# --shell /bin/false: This user CANNOT log in. It only exists to run the service safely.

# --- 3. Download & Extract ---
cd /tmp
# Line 15: Move to the temporary folder so we don't clutter the system.

curl -LO "https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/node_exporter-${VERSION}.${ARCH}.tar.gz"
# Line 17: 'curl' fetches the binary from GitHub. 
# -L: Follow redirects. -O: Save the file using the remote name.

tar -xvf "node_exporter-${VERSION}.${ARCH}.tar.gz"
# Line 20: 'tar' extracts (un-zips) the downloaded archive.

# --- 4. Installation ---
sudo mv "node_exporter-${VERSION}.${ARCH}/node_exporter" /usr/local/bin/
# Line 23: Move the actual executable binary to a standard system path. 
# Now, typing 'node_exporter' anywhere in the terminal will run the program.

sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
# Line 26: Change Ownership. This ensures our service user owns the file it's running.

# --- 5. Systemd Service Creation ---
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
# Lines 29-43: This is a "Here Document." It writes the text between '<<EOF' and 'EOF' 
# into the file /etc/systemd/system/node_exporter.service.
# After=network.target: Don't start until the internet is ready.
# ExecStart: The path to the file we just moved.
# Restart=always: If the program crashes, the OS will automatically bring it back.

# --- 6. Activation ---
sudo systemctl daemon-reload
# Line 46: Tell the OS to "refresh" its list of services to see our new file.

sudo systemctl enable node_exporter
# Line 48: Set the service to start automatically whenever the PC boots up.

sudo systemctl start node_exporter
# Line 50: Start the service right now.

# --- 7. Cleanup ---
rm -rf /tmp/node_exporter-${VERSION}.${ARCH}*
# Line 53: Delete the leftover zip file and extracted folder. We don't need them anymore.

echo "Node Exporter installed and running!"