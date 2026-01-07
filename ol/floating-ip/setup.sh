#!/usr/bin/env bash

# *** Mandatory for proper logging and state consistency ***
source /opt/ha/util.sh



log "Setting Service IP (floating IP) ${SERVICE_IP} on the serice hostname '${SERVICE_HOSTNAME}'"
if [[ "$ROLE" == "primary" ]]; then
	pcs resource create service-ip ocf:custom:reassign-service-ip op monitor interval=10s timeout=5s
	pcs constraint colocation add service-ip with fs_${DRBD_RESOURCE} INFINITY
	pcs constraint order start fs_${DRBD_RESOURCE} then start service-ip
fi
# grace period to wait for Service IP to becoming assigned (to proceed with DNS record consistently)
sleep 10

log "Creating DNS record for Service IP"
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

