#!/usr/bin/env bash
set -euo pipefail
exec >> /var/log/ha-bootstrap.log 2>&1

source /etc/ha/stack.env

# Make DRBD commands non-interactive
mkdir -p /etc/drbd.d
tee /etc/drbd.d/global_common.conf <<EOF
global {
    usage-count no;
}
EOF

wipefs -fa "${BLOCK_DEVICE}"

# Get local IP from OCI metadata
LOCAL_IP=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/vnics | jq -r '.[0].privateIp')

# Get peer IP (via DNS or metadata later)
# For now assume symmetric naming and /etc/hosts based resolution
# Placeholder – will be filled by peer node
PEER_IP=$(getent hosts "${PEER_NODE_NAME}" | awk '{print $1}' || true)

echo "Setting DRBD device configuration file"
# define configuration of DRBD device
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

echo "Initializing DRBD device"
drbdadm create-md --force ${DRBD_RESOURCE}
drbdadm up ${DRBD_RESOURCE}
echo "Promoting primary JUST ONCE to create ground truth for Pacemaker to take over from"
if [[ "$ROLE" = "primary" ]]; then
	drbdadm primary --force ${DRBD_RESOURCE}
	mkfs -t ${FS_TYPE} ${DRBD_DEVICE}
fi

