#!/usr/bin/env bash
set -euo pipefail

# NOTE: open VCN Security List ports for the services involved
# NOTE: Deprecation Warning: configuring meta attributes without specifying the 'meta' keyword is deprecated and will be removed in a future release
# добавить STONITH через OCI API
# Floating IP как кластерный ресурс
# привести corosync.conf к best-practice для OCI (mtu, ring0 addr)

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



# === PACEMAKER, COROSYNC, AND DRBD ===

# on BOTH compute instances

sudo mkdir -p "${MOUNT_POINT}"
chown -R USER "${MOUNT_POINT}"

sudo tee /etc/hosts <<EOF
127.0.0.1   localhost
${NODE1_IP} ${NODE1_NAME}
${NODE2_IP} ${NODE2_NAME}
EOF

# open ports for pacemaker and corosync
sudo firewall-cmd --add-service=high-availability --permanent
sudo firewall-cmd --reload

# install and launch pacemaker and corosync
sudo dnf -y install pacemaker corosync pcs resource-agents fence-agents-all
sudo systemctl enable pcsd
sudo systemctl start pcsd

# configure pacemaker
echo "hacluster:${HACLUSTER_PASSWORD}" | sudo chpasswd
sudo pcs client local-auth -u hacluster -p "${HACLUSTER_PASSWORD}"

# NOTE! Run this on ONE compute instance
sudo pcs host auth ${NODE1_NAME} ${NODE2_NAME} -u hacluster -p "${HACLUSTER_PASSWORD}"
sudo pcs cluster setup "${CLUSTER_NAME}" ${NODE1_NAME} ${NODE2_NAME} --force
sudo pcs cluster start --all
sudo pcs cluster enable --all
sudo pcs property set stonith-enabled=false
sudo pcs property set no-quorum-policy=stop
sudo pcs property set cluster-recheck-interval=5s
sudo pcs status

# integrate DRBD to Pacemaker
sudo pcs resource create drbd_${DRBD_RESOURCE} ocf:linbit:drbd drbd_resource=${DRBD_RESOURCE} op monitor interval=30s role=Promoted op monitor interval=60s role=Unpromoted
sudo pcs resource promotable drbd_${DRBD_RESOURCE} promoted-max=1 promoted-node-max=1 clone-max=2 clone-node-max=1 notify=true
sudo pcs resource create fs_${DRBD_RESOURCE} Filesystem device="/dev/drbd0" directory="${MOUNT_POINT}" fstype="${FS}" options="noatime" op monitor interval=20s
sudo pcs constraint colocation add fs_${DRBD_RESOURCE} with promoted drbd_${DRBD_RESOURCE}-clone INFINITY
sudo pcs constraint order promote drbd_${DRBD_RESOURCE}-clone then start fs_${DRBD_RESOURCE}

echo "waiting 20 seconds for DRBD resource to come under Cosorync control..."
sleep 20

sudo pcs status



# CONFIGURE FLOATING IP

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









