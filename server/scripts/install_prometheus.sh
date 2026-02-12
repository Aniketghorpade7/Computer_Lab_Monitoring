#! /bin/bash

set -e  #if one command fails scripts stops (atomicity)

set -x  #prints each command before excuting

# Variables
VERSION="2.50.1"
USER="monitor_admin"
TMP_DIR="/tmp/prometheus_install"

mkdir -p $TMP_DIR
cd $TMP_DIR

# Downloading the binary
