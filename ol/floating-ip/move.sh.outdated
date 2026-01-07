#!/usr/bin/env bash
set -euo pipefail
exec >> /var/log/ha-bootstrap.log 2>&1

export OCI_CLI_AUTH=instance_principal

STATE_FILE="/etc/ha/stack.env"

if [ ! -f "$STATE_FILE" ]; then
  echo "Fatal: HA state file $STATE_FILE not found"
  exit 1
fi

source "${STATE_FILE}"

# Reassign to the current VNIC
VNIC_OCID=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/vnics/ | jq -r '.[0].vnicId')
oci network vnic assign-private-ip --ip-address ${SERVICE_IP} --unassign-if-already-assigned --vnic-id ${VNIC_OCID}
# Make it visible in the OS
ip addr add ${SERVICE_IP}/${SERVICE_PREFIXLEN} dev ${IFACE} 2>/dev/null || true

