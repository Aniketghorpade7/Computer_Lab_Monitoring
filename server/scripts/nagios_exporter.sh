#! /bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

set -e
set -x

USER="monitor_admin"
INSTALL_DIR="/opt/nagios_exporter"
PROM_CONF="/etc/prometheus/prometheus.yml"
NAGIOS_STATUS_FILE="/usr/local/nagios/var/status.dat"

# 1. Sanity Check
if [ ! -f "$PROM_CONF" ]; then
    echo "Error: $PROM_CONF not found!"
    exit 1
fi

# 2. Check and Create the System User
if id "$USER" &>/dev/null; then
    echo "User '$USER' exists."
else
    useradd --system --no-create-home --shell /bin/false "$USER"
fi

# 3. Setup Python Virtual Environment
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR
python3 -m venv venv
source venv/bin/activate
pip install prometheus_client

# 4. Write the Python Parser Script
cat << 'EOF' > $INSTALL_DIR/nagios_exporter.py
import time
import re
from prometheus_client import start_http_server, Gauge

# Define our Prometheus metrics
host_status = Gauge('nagios_host_status', 'Host status (0=UP, 1=DOWN)', ['host'])
service_status = Gauge('nagios_service_status', 'Service status (0=OK, 1=WARN, 2=CRIT, 3=UNK)', ['host', 'service'])

STATUS_FILE = "/usr/local/nagios/var/status.dat"

def parse_status():
    try:
        with open(STATUS_FILE, 'r') as f:
            content = f.read()
        
        # Parse Host blocks
        host_blocks = re.findall(r'hoststatus \{([\s\S]*?)\}', content)
        for block in host_blocks:
            host_match = re.search(r'host_name=(.*)', block)
            state_match = re.search(r'current_state=(\d)', block)
            if host_match and state_match:
                host_status.labels(host=host_match.group(1).strip()).set(int(state_match.group(1)))
        
        # Parse Service blocks
        service_blocks = re.findall(r'servicestatus \{([\s\S]*?)\}', content)
        for block in service_blocks:
            host_match = re.search(r'host_name=(.*)', block)
            service_match = re.search(r'service_description=(.*)', block)
            state_match = re.search(r'current_state=(\d)', block)
            if host_match and service_match and state_match:
                service_status.labels(
                    host=host_match.group(1).strip(), 
                    service=service_match.group(1).strip()
                ).set(int(state_match.group(1)))

    except Exception as e:
        print(f"Error reading status.dat: {e}")

if __name__ == '__main__':
    # Expose metrics on port 9115
    start_http_server(9115)
    print("Custom Nagios Exporter running on port 9115...")
    while True:
        parse_status()
        time.sleep(15) # Parse every 15 seconds
EOF

chown -R $USER:$USER $INSTALL_DIR

# 5. Create Systemd Service
cat <<EOF | tee /etc/systemd/system/nagios_exporter.service
[Unit]
Description=Custom Python Nagios Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=$USER
Group=$USER
Type=simple
WorkingDirectory=$INSTALL_DIR
# We call the python executable directly from the venv
ExecStart=$INSTALL_DIR/venv/bin/python $INSTALL_DIR/nagios_exporter.py

Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 6. Connect to Prometheus
if grep -q "job_name: 'nagios'" "$PROM_CONF"; then
    echo "Nagios job already exists."
else
    cat <<EOF >> "$PROM_CONF"

  - job_name: 'nagios'
    static_configs:
      - targets: ['localhost:9115']
EOF
fi

# 7. Reload and Start
systemctl daemon-reload
systemctl enable nagios_exporter
systemctl start nagios_exporter
systemctl restart prometheus

echo "Python Nagios Exporter Successfully Installed!"
systemctl status nagios_exporter --no-pager
