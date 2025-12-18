#!/bin/bash
set -e

FLOATING_IP="10.0.0.50"
IFACE="enp0s5"

# 1. Узнать subnet и vnic текущей ноды
VNIC_INFO=$(curl -s -H "Authorization: Bearer Oracle" \
  http://169.254.169.254/opc/v2/vnics/ | jq '.[0]')

VNIC_OCID=$(echo "$VNIC_INFO" | jq -r .vnicId)
SUBNET_OCID=$(echo "$VNIC_INFO" | jq -r .subnetId)

# 2. Найти OCID floating IP в subnet
FLOATING_IP_OCID=$($OCI network private-ip list \
  --subnet-id "$SUBNET_OCID" \
  --query "data[?\"ip-address\"=='${FLOATING_IP}'].id | [0]" \
  --raw-output)

if [ -z "$FLOATING_IP_OCID" ] || [ "$FLOATING_IP_OCID" = "null" ]; then
  echo "ERROR: Floating IP ${FLOATING_IP} not found in subnet"
  exit 1
fi

# 3. Перепривязать IP к текущему VNIC
$OCI network private-ip update \
  --private-ip-id "$FLOATING_IP_OCID" \
  --vnic-id "$VNIC_OCID"

# 4. Добавить IP в ОС
ip addr add ${FLOATING_IP}/24 dev ${IFACE} 2>/dev/null || true

