#!/usr/bin/env bash
set -euo pipefail
exec >> /var/log/ha-bootstrap.log 2>&1

echo "BOOTSTRAP $(date -Is) Post-reboot HA bootstrapping started"

# Enable DRBD driver persistently
modprobe drbd
lsmod | grep drbd
echo drbd > /etc/modules-load.d/drbd.conf

CONFIG_PATH="/opt/ha"

echo "BOOTSTRAP $(date -Is) Deciding which node is Primary and which is Secondary"
bash ${CONFIG_PATH}/node-role.sh
echo "BOOTSTRAP $(date -Is) Configuring networking"
bash ${CONFIG_PATH}/drbd/network.sh
echo "BOOTSTRAP $(date -Is) Configuring block volume for the future DRBD device"
bash ${CONFIG_PATH}/storage.sh
echo "BOOTSTRAP $(date -Is) Fetching parameters of Service IP"
bash ${CONFIG_PATH}/floating-ip/determine.sh
echo "BOOTSTRAP $(date -Is) Configuring and spinning up DRBD device"
bash ${CONFIG_PATH}/drbd/drbd.sh
echo "BOOTSTRAP $(date -Is) Configuring and spinning up Pacemaker and Corosync"
bash ${CONFIG_PATH}/pacemaker.sh
echo "BOOTSTRAP $(date -Is) Adding Service IP as a resource to Pacemaker"
bash ${CONFIG_PATH}/floating-ip/setup.sh
echo "BOOTSTRAP $(date -Is) Adding DNS record of Service IP as a resource to Pacemaker"
bash ${CONFIG_PATH}/dns/setup.sh

echo "BOOTSTRAP $(date -Is) Finally, guarantee idempotency to NOT let this bootstrapping launch accidently again"
# Finally, guarantee idempotency:
# 1. Mark that DRBD is launched to avoid creating it from scratch every time node reboots
mkdir -p /var/lib/ha
touch /var/lib/ha/bootstrap.done
# 2. Wipe out HA bootstrap service to prevent it from accidental launch - which would destory all data
systemctl disable ha-bootstrap.service || true
rm -f /etc/systemd/system/ha-bootstrap.service
systemctl daemon-reload

echo "BOOTSTRAP $(date -Is) Post-reboot bootstraping completed, Fault Tolerant Compute Resource configured successfully"
