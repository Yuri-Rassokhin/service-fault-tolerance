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

install -m 0755 /opt/ha/floating-ip/reassign-service-ip.sh ${AGENT_DIR}/

if [[ "$ROLE" == "primary" ]]; then
	pcs resource create service-ip ocf:custom:reassign-service-ip op monitor interval=10s timeout=5s
	pcs constraint colocation add service-ip with fs_${DRBD_RESOURCE} INFINITY
	pcs constraint order start fs_${DRBD_RESOURCE} then start service-ip
fi

# grace period to wait for Service IP to becoming assigned (to proceed with DNS record consistently)
sleep 10

echo "Creating DNS record for Service IP"
FQDN="${SERVICE_HOSTNAME}.${DNS_ZONE_NAME%\.}"
ITEMS_JSON=$(jq -cn --arg domain "$FQDN" --arg ip "$SERVICE_IP" \
  '[{
    domain: $domain,
    rtype: "A",
    rdata: $ip,
    ttl: "86400",
    operation: "ADD"
  }]')
oci dns record zone patch --zone-name-or-id "$DNS_ZONE_OCID" --scope PRIVATE --items "$ITEMS_JSON"

