#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

set -e
set -x

echo "Stopping Prometheus..."
systemctl stop prometheus || true
systemctl disable prometheus || true

echo "Removing systemd service..."
rm -f /etc/systemd/system/prometheus.service

echo "Reloading systemd..."
systemctl daemon-reload

echo "Removing Prometheus binaries..."
rm -f /usr/local/bin/prometheus
rm -f /usr/local/bin/promtool

echo "Removing configuration..."
rm -rf /etc/prometheus

echo "Removing data directory..."
rm -rf /var/lib/prometheus

echo "Rollback complete. Prometheus fully removed."
