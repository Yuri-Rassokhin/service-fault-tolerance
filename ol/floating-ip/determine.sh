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

echo "Node ${NODE_NAME} is determining OCID of Service IP"

METADATA="http://169.254.169.254/opc/v2"
AUTH_HEADER="Authorization: Bearer Oracle"
VNIC_OCID=$(curl -s -H "$AUTH_HEADER" "$METADATA/vnics/" | jq -r '.[0].vnicId')
echo "VNIC OCID: $VNIC_OCID"
SERVICE_IP_OCID=$(oci network private-ip list --subnet-id "$SUBNET_OCID" --query "data[?\"ip-address\"=='$SERVICE_IP'].id | [0]" --raw-output)

#if [[ -n "$SERVICE_IP_OCID" && "$SERVICE_IP_OCID" != "null" ]]; then
#	echo "Detaching existing private IP $FREE_IP (OCID=$SERVICE_IP_OCID)"
#	oci network private-ip delete --private-ip-id "$SERVICE_IP_OCID" --force
#fi

# Assign IP to our VNIC
#SERVICE_IP_OCID=$(oci network vnic assign-private-ip --vnic-id "$VNIC_OCID" --ip-address "$FREE_IP" --query 'data.id' --raw-output)

#if [[ -z "$SERVICE_IP_OCID" || "$SERVICE_IP_OCID" == "null" ]]; then
#	echo "Error: failed to assign floating IP"
#	exit 1
#fi

# Persist OCID of Service IP in HA status file
KEY="SERVICE_IP_OCID"
# Remove existing entry, if any
sed -i "/^${KEY}=.*/d" "$STATE_FILE"
# Append fresh value
echo "${KEY}=${SERVICE_IP_OCID}" >> "$STATE_FILE"

echo "Service IP OCID persisted"

# Persist VNIC OCID of floating IP in HA status file
#KEY="VNIC_OCID"
# Remove existing entry, if any
#sed -i "/^${KEY}=.*/d" "$STATE_FILE"
# Append fresh value
#echo "${KEY}=${VNIC_OCID}" >> "$STATE_FILE"

