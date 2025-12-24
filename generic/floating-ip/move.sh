#!/usr/bin/env bash
set -e

STATE_FILE="/var/lib/ha/ha_state.env"

if [ ! -f "$STATE_FILE" ]; then
  echo "Error: HA state file not found: $STATE_FILE"
  exit 1
fi

source "$STATE_FILE"



# Reassign to the current VNIC
$OCI network private-ip update --private-ip-id "$SERVICE_IP_OCID" --vnic-id "$VNIC_OCID"
# Make it visible in the OS
ip addr add ${SERVICE_IP}/24 dev ${IFACE} 2>/dev/null || true

