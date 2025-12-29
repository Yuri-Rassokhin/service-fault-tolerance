#!/usr/bin/env bash
set -euo pipefail
exec >> /var/log/ha-bootstrap.log 2>&1

export OCI_CLI_AUTH=instance_principal

echo "Configuring HA storage"
ISCSI_ATTACHMENT=$(oci compute volume-attachment list --instance-id $(oci-instanceid))
ISCSI_DETAILS=$(oci compute volume-attachment get --volume-attachment-id ${ISCSI_ATTACHMENT})

ISCSI_IP=$(echo "$ISCSI_DETAILS" | jq -r '.data.ipv4')
ISCSI_PORT=$(echo "$ISCSI_DETAILS" | jq -r '.data.port')
ISCSI_IQN=$(echo "$ISCSI_DETAILS" | jq -r '.data.iqn')
ISCSI_DEVICE=$(echo "$ISCSI_DETAILS" | jq -r '.data.device')

echo "iSCSI target = $ISCSI_IP:$ISCSI_PORT"
echo "iSCSI iqn = $ISCSI_IQN"
echo "iSCSI device = $ISCSI_DEVICE"

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

echo "iSCSI block device is ready: ${ISCSI_DEVICE}"
#echo "BLOCK_DEVICE=/dev/${BLOCK_DEVICE}" >> /etc/ha/stack.env
echo "HA storage configured"
