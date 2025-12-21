#!/usr/bin/env bash
set -e

echo "Setting system dependencies"

# Disable Oracle Linux repos if present (OCI image pollution)
sudo dnf config-manager --disable 'oraclelinux-*' || true
sudo dnf config-manager --set-enabled highavailability

# Clean cache
sudo dnf clean all
sudo dnf makecache

# Core dependencies
sudo dnf -y install python3 python3-pip jq pacemaker corosync pcs resource-agents fence-agents-all

# OCI SDK / CLI
python3 -m pip install --user --upgrade oci oci-cli
export PATH="$HOME/.local/bin:$PATH"

