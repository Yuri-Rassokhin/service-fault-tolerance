#!/usr/bin/env bash

echo "setting Pacemaker and Corosync"

# Persist and spin up pacemaker
sudo systemctl enable pcsd
sudo systemctl start pcsd
# Set password for pacemaker cluster
echo "hacluster:${HA_CLUSTER_PASSWORD}" | sudo chpasswd
sudo pcs client local-auth -u hacluster -p "${HA_CLUSTER_PASSWORD}"

# On Primary node, configure HA resources and policies
if [[ "$ROLE" == "primary" ]]; then
	sudo pcs host auth ${NODE_NAME} ${PEER_NODE_NAME} -u hacluster -p "${HA_CLUSTER_PASSWORD}"
	sudo pcs cluster setup "${CLUSTER_NAME}" ${NODE_NAME} ${PEER_NODE_NAME} --force
	sudo pcs cluster start --all
	sudo pcs cluster enable --all
	sudo pcs property set stonith-enabled=false
	sudo pcs property set no-quorum-policy=stop
	sudo pcs property set cluster-recheck-interval=1s
	sudo pcs status
	# integrate DRBD to Pacemaker
	sudo pcs resource create drbd_${DRBD_RESOURCE} ocf:linbit:drbd drbd_resource=${DRBD_RESOURCE} op monitor interval=1s role=Promoted op monitor interval=1s role=Unpromoted
	sudo pcs resource promotable drbd_${DRBD_RESOURCE} promoted-max=1 promoted-node-max=1 clone-max=2 clone-node-max=1 notify=true
	sudo pcs resource create fs_${DRBD_RESOURCE} Filesystem device=${DRBD_DEVICE} directory="${MOUNT_POINT}" fstype="${FS_TYPE}" options="noatime" op monitor interval=1s
	sudo pcs constraint colocation add fs_${DRBD_RESOURCE} with promoted drbd_${DRBD_RESOURCE}-clone INFINITY
	sudo pcs constraint order promote drbd_${DRBD_RESOURCE}-clone then start fs_${DRBD_RESOURCE}
	echo "waiting 20 seconds for DRBD resource to come under Cosorync control..."
	sleep 20
	sudo pcs status
fi

