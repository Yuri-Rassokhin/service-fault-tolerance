#!/usr/bin/env bash
set -euo pipefail
exec >> /var/log/ha-bootstrap.log 2>&1

# OCI SDK / CLI
echo "Installing OCI CLI"
dnf -y install python3 python3-pip
dnf -y install python-oci-cli

echo "Selecting and assigning floating private IP"

export OCI_CLI_AUTH=instance_principal

# Load HA context
source /etc/ha/stack.env

METADATA="http://169.254.169.254/opc/v2"
AUTH_HEADER="Authorization: Bearer Oracle"

# Get instance + VNIC context
INSTANCE_OCID=$(curl -s -H "$AUTH_HEADER" "$METADATA/instance/" | jq -r '.id')
VNIC_OCID=$(curl -s -H "$AUTH_HEADER" "$METADATA/vnics/" | jq -r '.[0].vnicId')

echo "Instance OCID: $INSTANCE_OCID"
echo "VNIC OCID: $VNIC_OCID"

# Collect used IPs in subnet
USED_IPS=$(oci network private-ip list --subnet-id "$SUBNET_OCID" --query 'data[]."ip-address"' --raw-output)

SUBNET_CIDR=$(oci network subnet get --subnet-id "$SUBNET_OCID" --query 'data."cidr-block"' --raw-output)

# Find free IP in subnet
FREE_IP=$(python3 - <<EOF
import ipaddress

subnet = ipaddress.ip_network("$SUBNET_CIDR")
used = set("""
$USED_IPS
""".split())

RESERVED_OFFSET = 4
for ip in subnet.hosts():
    if ip.exploded in used:
        continue
    if int(ip) - int(subnet.network_address) < RESERVED_OFFSET:
        continue
    print(ip)
    break
EOF
)

if [[ -z "$FREE_IP" ]]; then
  echo "Error: No free IPs left in subnet"
  exit 1
fi

echo "Selected floating IP: $FREE_IP"

# Check if IP already exists somewhere
SERVICE_IP_OCID=$(oci network private-ip list \
  --subnet-id "$SUBNET_OCID" \
  --query "data[?\"ip-address\"=='$FREE_IP'].id | [0]" \
  --raw-output)

if [[ -n "$SERVICE_IP_OCID" && "$SERVICE_IP_OCID" != "null" ]]; then
  echo "[fip] Detaching existing private IP $FREE_IP (OCID=$SERVICE_IP_OCID)"
  oci network private-ip delete \
    --private-ip-id "$SERVICE_IP_OCID" \
    --force
fi

# Assign IP to our VNIC
SERVICE_IP_OCID=$(oci network vnic assign-private-ip \
  --vnic-id "$VNIC_OCID" \
  --ip-address "$FREE_IP" \
  --query 'data.id' \
  --raw-output)

if [[ -z "$SERVICE_IP_OCID" || "$SERVICE_IP_OCID" == "null" ]]; then
  echo "Error: failed to assign floating IP"
  exit 1
fi

echo "Assigned floating IP $FREE_IP (OCID=$SERVICE_IP_OCID)"

# Persist result
echo "SERVICE_IP=$FREE_IP" >> /etc/ha/stack.env
# TODO: avoid duplicated entries in stack.env

