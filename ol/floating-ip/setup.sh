#!/usr/bin/env bash
set -euo pipefail
exec >> /var/log/ha-bootstrap.log 2>&1

export OCI_CLI_AUTH=instance_principal

STATE_FILE="/etc/ha/stack.env"

if [ ! -f "$STATE_FILE" ]; then
  echo "Fatal: HA state file $STATE_FILE not found"
  exit 1
fi

source "$STATE_FILE"

echo "Setting floating IP ${SERVICE_IP} on the serice hostname '${SERVICE_HOSTNAME}'"

AGENT_DIR="/usr/lib/ocf/resource.d/custom"
mkdir -p ${AGENT_DIR}
CONFIG_PATH="/opt/ha"

MOVE_SCRIPT="/usr/local/bin/move_floating_ip.sh"
install -m 0755 ${CONFIG_PATH}/floating-ip/move.sh ${MOVE_SCRIPT}
restorecon -v "$MOVE_SCRIPT"

install -m 0755 ${CONFIG_PATH}/floating-ip/pacemaker.sh ${AGENT_DIR}/pacemaker
restorecon -v "${AGENT_DIR}/pacemaker"

if [[ "$ROLE" == "primary" ]]; then
	pcs resource create floating-ip ocf:custom:pacemaker op monitor interval=10s timeout=5s
	pcs constraint colocation add floating-ip with fs_${DRBD_RESOURCE} INFINITY
	pcs constraint order start fs_${DRBD_RESOURCE} then start floating-ip
fi

