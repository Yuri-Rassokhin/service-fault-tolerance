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

echo "Configuring Pacemaker agent that will be moving DNS record '${SERVICE_HOSTNAME}' referring to floating IP ${SERVICE_IP} across nodes"

AGENT_DIR="/usr/lib/ocf/resource.d/custom"
mkdir -p ${AGENT_DIR}
CONFIG_PATH="/opt/ha"

install -m 0755 ${CONFIG_PATH}/dns/oci-dns.sh "${AGENT_DIR}/oci-dns"
restorecon -v "$AGENT_DIR/oci-dns"

if [[ "$ROLE" == "primary" ]]; then
	pcs resource create dns_service ocf:custom:oci-dns op monitor interval=30s timeout=10s
	pcs constraint colocation add dns_service with floating-ip INFINITY
	pcs constraint order start floating-ip then start dns_service
fi

echo "DNS service for Floating IP has been created"
