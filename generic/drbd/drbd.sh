#!/usr/bin/env bash



# on BOTH instances

# remove FS label from the volume, if any
sudo wipefs -a "${DRBD_BLOCK_VOLUME_PATH}"

# define configuration of DRBD device
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

# spin up DRBD device
sudo drbdadm create-md r0
sudo drbdadm up r0
sudo drbdadm status r0
cat /proc/drbd

# prepare mount point for DRBD device
sudo mkdir -p "${MOUNT_POINT}"
sudo chown -R "$USER:$USER" "${MOUNT_POINT}"



# on ONE instance only

# promote one AND ONLY ONE DRBD instance to be Primary
sudo drbdadm primary --force r0
sudo mkfs.${FS} ${DRBD_DEVICE}

# pacemaker will mount it itself
#sudo mount ${DRBD_DEVICE} ${MOUNT_POINT} 

