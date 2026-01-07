#!/usr/bin/env bash

# *** Mandatory for proper logging and state consistency ***
source /opt/ha/util.sh



log "Making DRBD commands non-interactive"
mkdir -p /etc/drbd.d
tee /etc/drbd.d/global_common.conf <<EOF
global {
    usage-count no;
}
EOF

log "Wiping out everything from block device ${BLOCK_DEVICE}"
wipefs -fa "${BLOCK_DEVICE}"

log "Getting IP address of the nodes"
LOCAL_IP=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/vnics | jq -r '.[0].privateIp')
# Get peer IP (via DNS or metadata later)
# For now assume symmetric naming and /etc/hosts based resolution
# Placeholder – will be filled by peer node
PEER_IP=$(getent hosts "${PEER_NODE_NAME}" | awk '{print $1}' || true)

log "Creating DRBD device configuration file"
tee /etc/drbd.d/${DRBD_RESOURCE}.res <<EOF
resource ${DRBD_RESOURCE} {
    protocol C;

    on ${NODE_NAME} {
        device     ${DRBD_DEVICE};
        disk       ${BLOCK_DEVICE};
        address    ${LOCAL_IP}:7789;
        meta-disk  internal;
    }

    on ${PEER_NODE_NAME} {
        device     ${DRBD_DEVICE};
        disk       ${BLOCK_DEVICE};
        address    ${PEER_IP}:7789;
        meta-disk  internal;
    }
}
EOF

log "Initializing DRBD device"
drbdadm create-md --force ${DRBD_RESOURCE}
log "Spinning up DRBD device"
drbdadm up ${DRBD_RESOURCE}
log "Promoting current node to Primary just once to create ground truth for Pacemaker"
if [[ "$ROLE" = "primary" ]]; then
	drbdadm primary --force ${DRBD_RESOURCE}
	mkfs -t ${FS_TYPE} ${DRBD_DEVICE}
fi

