#!/bin/bash



# on BOTH instances

sudo wipefs -a "${DRBD_BLOCK_VOLUME_PATH}"

sudo tee /etc/drbd.d/r0.res <<EOF
resource r0 {
    protocol C;

    on ${NODE1_NAME} {
        device     ${DRBD_DEVICE};
        disk       ${DRBD_BLOCK_VOLUME_PATH};
        address    ${NODE1_IP}:7789;
        meta-disk  internal;
    }

    on ${NODE2_NAME} {
        device     ${DRBD_DEVICE};
        disk       ${DRBD_BLOCK_VOLUME_PATH};
        address    ${NODE2_IP}:7789;
        meta-disk  internal;
    }
}
EOF

sudo drbdadm create-md r0
sudo drbdadm up r0
sudo drbdadm status r0
cat /proc/drbd

sudo mkdir -p "${MOUNT_POINT}"
chown -R "$USER:$USER" "${MOUNT_POINT}"



# on ONE instance only

sudo drbdadm primary --force r0
sudo mkfs.${FS} ${DRBD_DEVICE}
sudo mount ${DRBD_DEVICE} ${MOUNT_POINT}

