#!/usr/bin/env bash

# *** Mandatory for proper logging and state consistency ***
source /opt/ha/util.sh



log "Setting systemd ordering: Corosync after iSCSI and when the device has appeared"
mkdir -p /etc/systemd/system/corosync.service.d
mkdir -p /etc/systemd/system/pacemaker.service.d
cat > /etc/systemd/system/corosync.service.d/override.conf <<EOF
[Unit]
Wants=network-online.target iscsid.service iscsi.service dev-oracleoci-oraclevdb.device
After=network-online.target iscsid.service iscsi.service dev-oracleoci-oraclevdb.device
EOF
log "Setting systemd ordering: Pacemaker after Corosync and when the device has appeared"
cat > /etc/systemd/system/pacemaker.service.d/override.conf <<EOF
[Unit]
Wants=corosync.service dev-oracleoci-oraclevdb.device
After=corosync.service dev-oracleoci-oraclevdb.device
EOF
systemctl daemon-reload
log "Spinning up block volume in systemd and waiting for the device to appear"
systemctl enable --now iscsid iscsi
udevadm settle
test -b /dev/oracleoci/oraclevdb
log "Starting Pacemaker PCSD"
systemctl enable --now pcsd

log "Setting password for Pacemaker cluster"
echo "hacluster:${HA_CLUSTER_PASSWORD}" | chpasswd
pcs client local-auth -u hacluster -p "${HA_CLUSTER_PASSWORD}"

if [[ "$ROLE" == "primary" ]]; then
	log "On Primary: configuring failover policies"
	# in case the peer node comes with a delay, we'll do graceful wait period
	log "On Primary: waiting for Secondary node to appear in the cluster..."
	for i in {1..30}; do
		pcs host auth "${NODE_NAME}" "${PEER_NODE_NAME}" -u hacluster -p "${HA_CLUSTER_PASSWORD}" && break
		sleep 2
		log "$i seconds..."
	done
	log "On Primary: initial cluster set-up with Secondary"
	pcs cluster setup "${CLUSTER_NAME}" ${NODE_NAME} ${PEER_NODE_NAME} --force
	sleep 10 # a little hard-coded wait period for the peer node
	log "Stopping the cluster to set further policies and resources"
	pcs cluster stop --all
	log "Setting cluster quorum policies"
	pcs quorum update last_man_standing=1 wait_for_all=1 # TODO: analyze if it's safe enough
	log "Restarting cluster"
	pcs cluster start --all
	pcs cluster enable --all
	log "Setting cluster STONITH policy"
	pcs property set stonith-enabled=false
	log "Setting cluster quorum policy"
	pcs property set no-quorum-policy=stop
	log "Setting cluster recheck policy"
	pcs property set cluster-recheck-interval=5s
	pcs status
	log "Adding cluster resource: DRBD device"
	pcs resource create drbd_${DRBD_RESOURCE} ocf:linbit:drbd drbd_resource=${DRBD_RESOURCE} op monitor interval=10s role=Promoted op monitor interval=20s role=Unpromoted
	pcs resource promotable drbd_${DRBD_RESOURCE} promoted-max=1 promoted-node-max=1 clone-max=2 clone-node-max=1 notify=true
	log "Adding cluster resource: mount point on DRBD"
	pcs resource create fs_${DRBD_RESOURCE} Filesystem device=${DRBD_DEVICE} directory="${MOUNT_POINT}" fstype="${FS_TYPE}" options="noatime" op monitor interval=20s
	pcs constraint colocation add fs_${DRBD_RESOURCE} with promoted drbd_${DRBD_RESOURCE}-clone INFINITY
	pcs constraint order promote drbd_${DRBD_RESOURCE}-clone then start fs_${DRBD_RESOURCE}
	log "Waiting for DRBD resource to come under cluster control"
	sleep 20
	log "Cluster set up:"
	pcs status --full
fi

# on both nodes, after cluster setup may have happened
log "Waiting for Corosync cluster configuration to appear"
for i in {1..60}; do
  [[ -f /etc/corosync/corosync.conf ]] && break
  sleep 1
done
log "Enabling Corosync and Pacemaker in systemd"
systemctl enable --now corosync pacemaker

