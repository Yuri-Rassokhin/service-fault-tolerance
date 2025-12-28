#!/usr/bin/env bash
set -euo pipefail
exec >> /var/log/ha-bootstrap.log 2>&1

source /etc/ha/stack.env

# remove FS label from the volume, if any
echo "Wiping out FS label from ${BLOCK_DEVICE}"
sudo wipefs -a "${BLOCK_DEVICE}"

# Get local IP from OCI metadata
LOCAL_IP=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/vnics | jq -r '.[0].privateIp')

# Get peer IP (via DNS or metadata later)
# For now assume symmetric naming and /etc/hosts based resolution
# Placeholder – will be filled by peer node
PEER_IP=$(getent hosts "${PEER_NODE_NAME}" | awk '{print $1}' || true)

echo "Setting DRBD device configuration file"
# define configuration of DRBD device
sudo tee /etc/drbd.d/${DRBD_RESOURCE}.res <<EOF
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

echo "Spinning up DRBD device"
# spin up DRBD device
sudo drbdadm create-md ${DRBD_RESOURCE} || true
sudo drbdadm up ${DRBD_RESOURCE} || true
sudo drbdadm status ${DRBD_RESOURCE} || true

echo "Preparing mount point for DRBD device"
# prepare mount point for DRBD device
sudo mkdir -p "${MOUNT_POINT}"
sudo chown -R "$USER:$USER" "${MOUNT_POINT}"



# Define who's Primary and who's Secondary
# We use simple lexicographical ordering to avoid ambiguity / race conditions
# This guarantees idempotency, too
if [[ "$NODE_NAME" < "$PEER_NODE_NAME" ]]; then
  ROLE="primary"
else
  ROLE="secondary"
fi

echo "Node role: $ROLE"

if [[ "$ROLE" == "primary" ]]; then
  echo "Promoting current node to primary"
  drbdadm primary --force ${DRBD_RESOURCE}

  if ! blkid ${DRBD_DEVICE} >/dev/null 2>&1; then
    echo "Creating filesystem"
    mkfs.${FS_TYPE} ${DRBD_DEVICE}
  fi

  if ! mountpoint -q "${MOUNT_POINT}"; then
    mount ${DRBD_DEVICE} "${MOUNT_POINT}"
  fi
else
  echo "Current node is secondary, skipping filesystem setup"
fi

