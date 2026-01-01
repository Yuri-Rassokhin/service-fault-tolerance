#!/usr/bin/env bash
set -euo pipefail
exec >> /var/log/ha-bootstrap.log 2>&1

echo "Post-reboot HA bootstrap started"

# Enable DRBD driver persistently
modprobe drbd
lsmod | grep drbd
echo drbd > /etc/modules-load.d/drbd.conf

CONFIG_PATH="/opt/ha"

# Distinguish node role for the subsequent steps - either primary or secondary
bash ${CONFIG_PATH}/node-role.sh
# Configure network
bash ${CONFIG_PATH}/drbd/network.sh
# Configure block volume
bash ${CONFIG_PATH}/storage.sh
# Determine and configure floating IP
bash ${CONFIG_PATH}/floating-ip/determine.sh
# Configure and spin up DRBD device
bash ${CONFIG_PATH}/drbd/drbd.sh
# Configure and launch Pacemaker and Corosync
bash ${CONFIG_PATH}/pacemaker.sh
# Add floating IP to Pacemaker and Corosync
bash ${CONFIG_PATH}/floating-ip/setup.sh

# Finally, guarantee idempotency:
# 1. Mark that DRBD is launched to avoid creating it from scratch every time node reboots
mkdir -p /var/lib/ha
touch /var/lib/ha/bootstrap.done
# 2. Wipe out HA bootstrap service to prevent it from accidental launch - which would destory all data
systemctl disable ha-bootstrap.service || true
rm -f /etc/systemd/system/ha-bootstrap.service
systemctl daemon-reload

echo "Post-reboot HA bootstrap completed"
