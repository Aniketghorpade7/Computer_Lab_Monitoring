#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

set -e
set -x

echo "Stopping Grafana service..."
systemctl stop grafana-server || true
systemctl disable grafana-server || true

echo "Removing Grafana package..."
apt-get purge -y grafana

echo "Removing unused dependencies..."
apt-get autoremove -y

echo "Removing Grafana repository..."
rm -f /etc/apt/sources.list.d/grafana.list

echo "Removing Grafana GPG key..."
rm -f /etc/apt/keyrings/grafana.gpg

echo "Updating package list..."
apt-get update

echo "Cleanup complete."
