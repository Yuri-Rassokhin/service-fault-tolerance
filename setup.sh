#!/usr/bin/env bash
set -euo pipefail

# user parameters

SERVICE_HOSTNAME="ha-service"		# optional; hostname of the floating HA IP address
SERVICE_IP="10.0.0.50"			# optional - TO BE REPLACTED WITH SUBNET
MOUNT_POINT="/resilient" 		# optional
FS="xfs" 				# optional
IFACE="enp0s5"				# TO BE REMOVED



# internal parameters

NODE1_IP="10.0.0.253"
NODE2_IP="10.0.0.150"
NODE1_NAME="ha-1"
NODE2_NAME="ha-2"
CLUSTER_NAME="ha-cluster"
HACLUSTER_PASSWORD="ChangeMeStrongPassword"
DRBD_DEVICE="/dev/drbd0"
DRBD_RESOURCE="r0"
DRBD_BLOCK_VOLUME_PATH="/dev/oracleoci/oraclevdb"

source ./sources/dependencies.sh

SOURCES="./sources"
OCI="$HOME/.local/bin/oci"
VNIC_OCID=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/vnics/ | jq -r '.[0].vnicId')
SUBNET_OCID=$($OCI network vnic get --vnic-id "$VNIC_OCID" | jq -r '.data."subnet-id"')
SERVICE_IP_OCID=$($OCI network private-ip list --subnet-id "$SUBNET_OCID" \
  | jq -r --arg ip "$SERVICE_IP" '.data[] | select(."ip-address"==$ip) | .id' | head -n1)

if [[ -z "$SERVICE_IP_OCID" || "$SERVICE_IP_OCID" == "null" ]]; then
  echo "Error: service IP $SERVICE_IP not found in subnet $SUBNET_OCID" >&2
  exit 1
fi



# main entry point

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up DRBD..."
source "$DIR/sources/kernel.sh"
source "$DIR/sources/network.sh"
source "$DIR/sources/drbd.sh"

echo "Setting up Pacemaker & Corosync..."
source "$DIR/sources/pacemaker/setup.sh"

echo "Setting up Floating IP..."
source "$DIR/sources/floating-ip/setup.sh"

