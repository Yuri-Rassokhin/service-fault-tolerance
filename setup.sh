#!/usr/bin/env bash
set -euo pipefail

# === USER VARIABLES ===

HA_SERVICE_NAME="my-service" # optional; hostname of the floating HA IP address
SERVICE_IP="10.0.0.50" # optional - TO BE REPLACTED WITH SUBNET
MOUNT_POINT="/resilient" # optional
FS="xfs" # optional



# INTERNAL PARAMETERS

NODE1_IP="10.0.0.32"
NODE2_IP="10.0.0.160"
NODE1_NAME="ha-instance-1"
NODE2_NAME="ha-instance-2"
CLUSTER_NAME="ha-cluster"
HACLUSTER_PASSWORD="ChangeMeStrongPassword"
DRBD_RESOURCE="r0"

echo "setting up DRBD, Pacemaker, and Corosync"
source ./sources/drbd.sh
echo "setting up floating IP for '${HA_SERVICE_NAME}'"
source ./sources/floating-ip.sh

