#!/usr/bin/env bash
set -euo pipefail
exec >> /var/log/ha-bootstrap.log 2>&1

echo "Configuring HA networking"
BLOCK_DEVICE=$(lsblk -ndo NAME,TYPE | grep -v sda | awk '$2=="disk"{print $1}')
echo "BLOCK_DEVICE=/dev/${BLOCK_DEVICE}" >> /etc/ha/stack.env
