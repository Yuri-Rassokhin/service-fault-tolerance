#!/usr/bin/env bash
set -euo pipefail
exec >> /var/log/ha-bootstrap.log 2>&1

STATE_FILE="/etc/ha/stack.env"
source "$STATE_FILE"


# TODO: remove hard-wired block volume path
# Make Pacemaker start ONLY after iSCSI has block volume mounted, otherwise DRBD will go panic
echo "Set systemd ordering for corosync/pacemaker (wait for iSCSI and device)"
mkdir -p /etc/systemd/system/corosync.service.d
mkdir -p /etc/systemd/system/pacemaker.service.d
# corosync after iSCSI and after the device appears
cat > /etc/systemd/system/corosync.service.d/override.conf <<EOF
[Unit]
Wants=network-online.target iscsid.service iscsi.service dev-oracleoci-oraclevdb.device
After=network-online.target iscsid.service iscsi.service dev-oracleoci-oraclevdb.device
EOF
# pacemaker after corosync and after the device appears
cat > /etc/systemd/system/pacemaker.service.d/override.conf <<EOF
[Unit]
Wants=corosync.service dev-oracleoci-oraclevdb.device
After=corosync.service dev-oracleoci-oraclevdb.device
EOF
systemctl daemon-reload
# Firstly, iSCSI - and we're waiting for the device to appear
systemctl enable --now iscsid iscsi
udevadm settle
test -b /dev/oracleoci/oraclevdb
# Secondly, pcsd (and only pcsd)
systemctl enable --now pcsd

# Set password for pacemaker cluster
echo "hacluster:${HA_CLUSTER_PASSWORD}" | chpasswd
pcs client local-auth -u hacluster -p "${HA_CLUSTER_PASSWORD}"

# On Primary node, configure HA resources and policies
if [[ "$ROLE" == "primary" ]]; then
	echo "Configuring HA policies"
	# in case the peer node comes with a delay, we'll do graceful wait period
	for i in {1..30}; do
		pcs host auth "${NODE_NAME}" "${PEER_NODE_NAME}" -u hacluster -p "${HA_CLUSTER_PASSWORD}" && break
		sleep 2
	done
	pcs cluster setup "${CLUSTER_NAME}" ${NODE_NAME} ${PEER_NODE_NAME} --force
	pcs quorum update last_man_standing=1 wait_for_all=1 # TODO: analyze if it's safe enough
	pcs cluster start --all
	pcs cluster enable --all
	pcs property set stonith-enabled=false
	pcs property set no-quorum-policy=stop
	pcs property set cluster-recheck-interval=5s
	pcs status
	echo "Configuring HA resources"
	# integrate DRBD to Pacemaker
	pcs resource create drbd_${DRBD_RESOURCE} ocf:linbit:drbd drbd_resource=${DRBD_RESOURCE} op monitor interval=10s role=Promoted op monitor interval=20s role=Unpromoted
	pcs resource promotable drbd_${DRBD_RESOURCE} promoted-max=1 promoted-node-max=1 clone-max=2 clone-node-max=1 notify=true
	pcs resource create fs_${DRBD_RESOURCE} Filesystem device=${DRBD_DEVICE} directory="${MOUNT_POINT}" fstype="${FS_TYPE}" options="noatime" op monitor interval=20s
	pcs constraint colocation add fs_${DRBD_RESOURCE} with promoted drbd_${DRBD_RESOURCE}-clone INFINITY
	pcs constraint order promote drbd_${DRBD_RESOURCE}-clone then start fs_${DRBD_RESOURCE}
	echo "waiting 20 seconds for DRBD resource to come under Cosorync control..."
	sleep 20
	pcs status --full
fi

# on both nodes, after cluster setup may have happened
for i in {1..60}; do
  [[ -f /etc/corosync/corosync.conf ]] && break
  sleep 1
done
systemctl enable --now corosync pacemaker

echo "HA cluster has been configured"


