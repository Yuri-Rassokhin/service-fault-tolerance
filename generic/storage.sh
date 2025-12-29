#!/usr/bin/env bash
set -euo pipefail
exec >> /var/log/ha-bootstrap.log 2>&1

echo "Configuring HA storage"
ISCSI_ATTACHMENT=$(oci compute volume-attachment list --instance-id $(oci-instanceid))
ISCSI_DETAILS=$(oci compute volume-attachment get --volume-attachment-id ${ISCSI_ATTACHMENT})

echo "ATTACHMENT: ${ISCSI_ATTACHMENT}"
echo "DETAILS: ${ISCSI_DETAILS}"

exit
BLOCK_DEVICE=$(lsblk -ndo NAME,TYPE | grep -v sda | awk '$2=="disk"{print $1}')
#echo "BLOCK_DEVICE=/dev/${BLOCK_DEVICE}" >> /etc/ha/stack.env

echo "HA storage configured"
