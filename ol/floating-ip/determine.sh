#!/usr/bin/env bash

# *** Mandatory for proper logging and state consistency ***
source /opt/ha/util.sh



log "Node ${NODE_NAME} is determining parameters of Service IP"
METADATA="http://169.254.169.254/opc/v2"
AUTH_HEADER="Authorization: Bearer Oracle"
VNIC_OCID=$(curl -s -H "$AUTH_HEADER" "$METADATA/vnics/" | jq -r '.[0].vnicId')
log "Service IP VNIC OCID: $VNIC_OCID"
SERVICE_IP_OCID=$(oci network private-ip list --subnet-id "$SUBNET_OCID" --query "data[?\"ip-address\"=='$SERVICE_IP'].id | [0]" --raw-output)

log "Persisting OCID of Service IP in state file"
KEY="SERVICE_IP_OCID"
# Remove existing entry, if any
sed -i "/^${KEY}=.*/d" "$STATE_FILE"
# Append fresh value
echo "${KEY}=${SERVICE_IP_OCID}" >> "$STATE_FILE"

# Persist VNIC OCID of floating IP in HA status file
#KEY="VNIC_OCID"
# Remove existing entry, if any
#sed -i "/^${KEY}=.*/d" "$STATE_FILE"
# Append fresh value
#echo "${KEY}=${VNIC_OCID}" >> "$STATE_FILE"

log "Persisting subnet mask of Service IP in state file"
PREFIXLEN=$(curl -s -H "$AUTH_HEADER" "$METADATA/vnics/" | jq -r '.[0].subnetCidrBlock' | cut -d/ -f2)
echo "SERVICE_PREFIXLEN=${PREFIXLEN}" >> /etc/ha/stack.env

