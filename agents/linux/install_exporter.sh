#!/bin/bash 
# It tells the OS to use bash interpreter to run this file 

set -e
#  "Exit on Error." If any command fails, the script stops immediately.
# This prevents "cascading failures" where one error breaks everything that follows.


# Variables
VERSION="1.7.0"
# Detect Architecture
OS_ARCH=$(uname -m)
if [ "$OS_ARCH" = "x86_64" ]; then
    ARCH="linux-amd64"
elif [ "$OS_ARCH" = "aarch64" ]; then
    ARCH="linux-arm64"
else
    ARCH="linux-386"
fi
#We define variables so we don't have to type the version number multiple times. 
# It makes updating the script in the future much easier.


#---  User Management ---
if ! id -u node_exporter >/dev/null 2>&1; then
    sudo useradd --no-create-home --shell /bin/false node_exporter
fi
# if node_exporter is not exist then create it.
#  -- No home directory created -->> this is system user




# --- Download & Extract ---
cd /tmp
# Move to the temporary folder so we don't clutter the system.
# Lines 10-12: This is an "Idempotent" check. It asks "Does user node_exporter exist?"


#  Download using curl
# We download from the official GitHub releases
curl -LO "https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/node_exporter-${VERSION}.${ARCH}.tar.gz"

# curl -->> fetches the binary from Github


# Extract the contents
tar -xvf "node_exporter-${VERSION}.${ARCH}.tar.gz"
# tar extracts the downloaded archive



# Move the binary to a system path
# This makes the command 'node_exporter' available everywhere
sudo mv "node_exporter-${VERSION}.${ARCH}/node_exporter" /usr/local/bin/
# move the actual executable binary to standard system path


sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
# user ko hamne ownership dedi

# so we are creating service file for node exporter 
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

#This is a "Here Document." It writes the text between '<<EOF' and 'EOF' 
# into the file /etc/systemd/system/node_exporter.service.
# After=network.target: Don't start until the internet is ready.
# ExecStart: The path to the file we just moved.
# Restart=always: If the program crashes, the OS will automatically bring it back.












s


sudo systemctl daemon-reload 

sudo systemctl enable node_exporter

sudo systemctl start node_exporter
# Verify the agent is responding
if curl -s localhost:9100/metrics | grep -q "node_cpu_seconds_total"; then
   echo "Verification Success: Node Exporter is emitting metrics."
else
   echo "Verification Failed: Service is running but metrics are unreachable."
   exit 1
fi

# Clean the mess
rm -rf node_exporter-${VERSION}.${ARCH}*


# Open the port for the Monitoring Server
# Ideally, replace 'any' with your Central Server IP for better security
sudo ufw allow from any to any port 9100 proto tcp

echo "Node Exporter installed and running!"