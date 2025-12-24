#!/usr/bin/env bash
set -euo pipefail



# USER PARAMETERS

SERVICE_HOSTNAME="ha-service"		# optional; hostname of the floating HA IP address
MOUNT_POINT="/resilient" 		# optional
FS="xfs" 				# optional



# DEFINE INTERNAL PARAMETERS

NODE1_IP="10.0.0.253"
NODE2_IP="10.0.0.150"
NODE1_NAME="ha-1"
NODE2_NAME="ha-2"
CLUSTER_NAME="ha-cluster"
HACLUSTER_PASSWORD="ChangeMeStrongPassword"
DRBD_DEVICE="/dev/drbd0"
DRBD_RESOURCE="r0"
DRBD_BLOCK_VOLUME_PATH="/dev/oracleoci/oraclevdb"
SOURCES="./sources"
IFACE="enp0s5"

source ./sources/dependencies.sh

# DEBUGGING
echo "DONE"
exit

OCI="$HOME/.local/bin/oci"
OCI_CONFIG="$HOME/.oci/config"

if [ ! -x "$OCI" ]; then
  echo "Error: OCI CLI not found or not executable at $OCI"
  exit 1
fi

if [ ! -f "$OCI_CONFIG" ]; then
  echo "Error: OCI CLI config not found at $OCI_CONFIG"
  exit 1
fi

REGION=$("$OCI" iam region-subscription list --query 'data[0]."region-name"' --raw-output)
VNIC_OCID=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/vnics/ | jq -r '.[0].vnicId')
SUBNET_OCID=$($OCI network vnic get --vnic-id "$VNIC_OCID" | jq -r '.data."subnet-id"')
SUBNET_CIDR=$("$OCI" network subnet get --subnet-id "$SUBNET_OCID" | jq -r '.data["ipv4-cidr-blocks"][0]')

[ -z "$SUBNET_CIDR" ] && { echo "Error: Subnet CIDR not found"; exit 1; }

USED_IPS=$("$OCI" network private-ip list --subnet-id "$SUBNET_OCID" --query 'data[]."ip-address"' --raw-output)

FREE_IP=$(python3 - <<EOF
import ipaddress

subnet = ipaddress.ip_network("$SUBNET_CIDR")
used = set("""
$USED_IPS
""".split())

RESERVED_OFFSET = 4
hosts = list(subnet.hosts())
for ip in hosts[RESERVED_OFFSET:]:
    ip = str(ip)
    if ip not in used:
        print(ip)
        break
EOF
)

[ -z "$FREE_IP" ] && { echo "Error: No free IPs in subnet"; exit 1; }

echo "Selected floating IP: $FREE_IP"

# unassign FREE_IP, if it is assigned anywhere
SERVICE_IP_OCID=$("$OCI" network private-ip list --subnet-id "$SUBNET_OCID" --query "data[?\"ip-address\"=='$FREE_IP'].id | [0]" --raw-output)
if [ -z "$SERVICE_IP_OCID" ] || [ "$SERVICE_IP_OCID" = "null" ]; then
  echo "No existing private IP for $FREE_IP, nothing to detach"
  SERVICE_IP_OCID=""
fi
if [ -n "$SERVICE_IP_OCID" ]; then
  echo "Detaching existing private IP $FREE_IP (OCID=$SERVICE_IP_OCID)"
  "$OCI" network private-ip delete --private-ip-id "$SERVICE_IP_OCID" --force
  echo "Private IP $FREE_IP detached"
fi

# reassign FREE_IP for our purposes
SERVICE_IP_OCID=$("$OCI" network vnic assign-private-ip --vnic-id "$VNIC_OCID" --ip-address "$FREE_IP" --query 'data.id' --raw-output)
[ -z "$SERVICE_IP_OCID" ] && { echo "Error: Failed to assign private IP"; exit 1; }
echo "Assigned floating IP $FREE_IP with OCID $SERVICE_IP_OCID"
SERVICE_IP=$FREE_IP



# SAVE HA STATE FOR REUSE IN RELATED SCRIPTS

STATE_DIR="/var/lib/ha"
STATE_FILE="${STATE_DIR}/ha_state.env"

sudo mkdir -p "$STATE_DIR"
sudo chmod 700 "$STATE_DIR"

sudo tee "$STATE_FILE" >/dev/null <<EOF
OCI="$OCI"
SERVICE_IP="$SERVICE_IP"
SERVICE_IP_OCID="$SERVICE_IP_OCID"
SUBNET_OCID="$SUBNET_OCID"
VNIC_OCID="$VNIC_OCID"
REGION="$REGION"
IFACE="$IFACE"
CIDR_PREFIX="$SUBNET_CIDR"
CREATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF

sudo chmod 600 "$STATE_FILE"
echo "HA state saved to $STATE_FILE"



# OPEN FIREWALL FOR FLOATING IPs

# NOTE: Rocky Linux comes without firewall RPM at all
#sudo firewall-cmd --permanent --add-service=http
#sudo firewall-cmd --permanent --add-service=https
#sudo firewall-cmd --reload



# main entry point

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up DRBD..."
source "$DIR/sources/drbd/kernel.sh"
source "$DIR/sources/drbd/network.sh"
source "$DIR/sources/drbd/drbd.sh"

echo "Setting up Pacemaker & Corosync..."
source "$DIR/sources/pacemaker/setup.sh"

echo "Setting up Floating IP..."
source "$DIR/sources/floating-ip/setup.sh"

