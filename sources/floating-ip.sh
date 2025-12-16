#!/usr/bin/env bash

# configure floating ip

INSTANCE_OCID=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | jq -r .id)
VNIC_OCID=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/vnics/ | jq -r '.[0].vnicId')
REGION=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | jq -r .region)
TENANCY_OCID=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/instance/ | jq -r .tenantId)
VNIC_INFO=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/vnics/ | jq '.[0]')
VNIC_OCID=$(echo "$VNIC_INFO" | jq -r .vnicId)
SUBNET_OCID=$(echo "$VNIC_INFO" | jq -r .subnetId)
PRIMARY_PRIVATE_IP=$(echo "$VNIC_INFO" | jq -r .privateIp)
PRIVATE_IPS=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/vnics/ | jq '.[0].privateIpIds')

for IP_OCID in $(echo "$PRIVATE_IPS" | jq -r '.[]'); do
  IP_ADDR=$(curl -s -H "Authorization: Bearer Oracle" \
    http://169.254.169.254/opc/v2/privateIps/$IP_OCID | jq -r .ipAddress)

  if [ "$IP_ADDR" = "10.0.0.50" ]; then
    FLOATING_PRIVATE_IP_OCID="$IP_OCID"
    break
  fi
done

echo "FLOATING_PRIVATE_IP_OCID=$FLOATING_PRIVATE_IP_OCID"

