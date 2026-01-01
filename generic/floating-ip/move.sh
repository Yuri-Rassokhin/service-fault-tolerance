#!/usr/bin/env bash
set -euo pipefail
exec >> /var/log/ha-bootstrap.log 2>&1

export OCI_CLI_AUTH=instance_principal

STATE_FILE="/etc/ha/state.env"

if [ ! -f "$STATE_FILE" ]; then
  echo "Fatal: HA state file $STATE_FILE not found"
  exit 1
fi

source "${STATE_FILE}"

# Reassign to the current VNIC
oci network private-ip update --private-ip-id "$SERVICE_IP_OCID" --vnic-id "$VNIC_OCID"
# Make it visible in the OS
ip addr add ${SERVICE_IP}/24 dev ${IFACE} 2>/dev/null || true

