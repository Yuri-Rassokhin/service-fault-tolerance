#!/usr/bin/env bash
set -e

SERVICE_IP="10.0.0.50"
IFACE="enp0s5"

OCI="$HOME/.local/bin/oci"
VNIC_OCID=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/vnics/ | jq -r '.[0].vnicId')
SUBNET_OCID=$($OCI network vnic get --vnic-id "$VNIC_OCID" | jq -r '.data."subnet-id"')
SERVICE_IP_OCID=$($OCI network private-ip list --subnet-id "$SUBNET_OCID" \
  | jq -r --arg ip "$SERVICE_IP" '.data[] | select(."ip-address"==$ip) | .id' | head -n1)



# 3. Перепривязать IP к текущему VNIC
$OCI network private-ip update \
  --private-ip-id "$SERVICE_IP_OCID" \
  --vnic-id "$VNIC_OCID"

# 4. Добавить IP в ОС
ip addr add ${SERVICE_IP}/24 dev ${IFACE} 2>/dev/null || true

