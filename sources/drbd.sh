#!/usr/bin/env bash

# deploy and configure drbd, Pacemaker, and Corosync

# on BOTH compute instances

sudo dnf -y install python3 python3-pip jq
pip install oci oci-cli
mkdir -p ~/.oci
chmod 700 ~/.oci
chmod 600 ~/.oci/config
chmod 600 ~/.oci/private_key

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

