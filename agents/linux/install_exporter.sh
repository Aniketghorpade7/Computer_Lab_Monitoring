!/bin/bash 
# It tells the OS to use bash interpreter to run this file 

set -e
#  "Exit on Error." If any command fails, the script stops immediately.
# This prevents "cascading failures" where one error breaks everything that follows.


# Variables
VERSION="1.7.0"
ARCH="linux-amd64" 
#We define variables so we don't have to type the version number multiple times. 
# It makes updating the script in the future much easier.


#---  User Management ---
if ! id -u node_exporter >/dev/null 2>&1; then
    sudo useradd --no-create-home --shell /bin/false node_exporter
fi


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

# Create a system user for node_exporter
sudo useradd --no-create-home --shell /bin/false node_exporter

# Move the binary to a system path
# This makes the command 'node_exporter' available everywhere
sudo mv "node_exporter-${VERSION}.${ARCH}/node_exporter" /usr/local/bin/

cd /etc/systemd/system/node_exporter.service
touch config.txt
cat>>config
ExecStart=/usr/local/bin/node_exporter

User=node_exporter

Restart=always

# --- code baki hain  









sudo systemctl daemon-reload 

sudo systemctl enable node_exporter

sudo systemctl start node_exporter

# Clean the mess
rm -rf "node_exporter-${VERSION}.${ARCH}*"

echo "Node Exporter installed and running!"
