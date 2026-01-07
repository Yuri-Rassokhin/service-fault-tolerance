#!/usr/bin/env bash

# *** Mandatory for proper logging and state consistency ***
source /opt/ha/util.sh



log "Configuring block volume for future resilient storage"
ISCSI_ATTACHMENT=$(oci compute volume-attachment list --instance-id $(oci-instanceid) --query 'data[0].id' --raw-output)
ISCSI_DETAILS=$(oci compute volume-attachment get --volume-attachment-id ${ISCSI_ATTACHMENT})
ISCSI_IP=$(echo "$ISCSI_DETAILS" | jq -r '.data.ipv4')
ISCSI_PORT=$(echo "$ISCSI_DETAILS" | jq -r '.data.port')
ISCSI_IQN=$(echo "$ISCSI_DETAILS" | jq -r '.data.iqn')
ISCSI_DEVICE=$(echo "$ISCSI_DETAILS" | jq -r '.data.device')

log "iSCSI target = $ISCSI_IP:$ISCSI_PORT"
log "iSCSI iqn = $ISCSI_IQN"
log "iSCSI device = $ISCSI_DEVICE"

# enable iSCSI system service, if needed
systemctl enable --now iscsid || true
# create iSCSI node
iscsiadm -m node -o new -T "${ISCSI_IQN}" -p "${ISCSI_IP}:${ISCSI_PORT}" || true
# enabel iSCSI autologin
iscsiadm -m node -o update -T "${ISCSI_IQN}" -p "${ISCSI_IP}:${ISCSI_PORT}" -n node.startup -v automatic
# iSCSI login
iscsiadm -m node -T "${ISCSI_IQN}" -p "${ISCSI_IP}:${ISCSI_PORT}" -l || true
# wait for the device to appear (this is important to avoid race conditions in case of non-deterministic delay)
udevadm settle
sleep 2
if [[ ! -b "${ISCSI_DEVICE}" ]]; then
  echo "Fatal: expected iSCSI block device ${ISCSI_DEVICE} did not appear"
  ls -l /dev/oracleoci || true
  ls -l /dev/disk/by-path || true
  exit 1
fi
log "block device is ready: ${ISCSI_DEVICE}"

# Sanity check
if [[ ! -b "$BLOCK_DEVICE" ]]; then
  log "block device $DEVICE_PATH not found, aborting"
  exit 1
fi

