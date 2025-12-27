#!/usr/bin/env bash

source /etc/ha/stack.env

# remove FS label from the volume, if any
sudo wipefs -a "${BLOCK_DEVICE}"

# define configuration of DRBD device
sudo tee /etc/drbd.d/${DRBD_RESOURCE}.res <<EOF
resource ${DRBD_RESOURCE} {
    protocol C;

    on ${NODE_NAME} {
        device     ${DRBD_DEVICE};
        disk       ${BLOCK_DEVICE};
        address    ${NODE_NAME}:7789;
        meta-disk  internal;
    }

    on ${PEER_NODE_NAME} {
        device     ${DRBD_DEVICE};
        disk       ${BLOCK_DEVICE};
        address    ${PEER_NODE_NAME}:7789;
        meta-disk  internal;
    }
}
EOF

# spin up DRBD device
sudo drbdadm create-md ${DRBD_RESOURCE} || true
sudo drbdadm up ${DRBD_RESOURCE} || true
sudo drbdadm status ${DRBD_RESOURCE} || true

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

