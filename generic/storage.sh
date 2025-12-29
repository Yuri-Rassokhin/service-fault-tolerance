#!/usr/bin/env bash
set -euo pipefail
exec >> /var/log/ha-bootstrap.log 2>&1

echo "Configuring HA storage"
exit

# TODO: 
# 1. Use OCI CLI to get iSCSI attachment command and attach teh volume
# 2. Provide stable device path to the HA status file

#oci compute volume-attachment list --instance-id <instance_OCID>

BLOCK_DEVICE=$(lsblk -ndo NAME,TYPE | grep -v sda | awk '$2=="disk"{print $1}')
#echo "BLOCK_DEVICE=/dev/${BLOCK_DEVICE}" >> /etc/ha/stack.env

echo "HA storage configured"
