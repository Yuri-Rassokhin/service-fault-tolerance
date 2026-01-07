#!/usr/bin/env bash

# *** Mandatory for proper logging and state consistency ***
source /opt/ha/util.sh



log "Phase 2 started (post-reboot SW configuration"

log "Persist DRBD driver after reboot"
modprobe drbd
lsmod | grep drbd
echo drbd > /etc/modules-load.d/drbd.conf

CFG="/opt/ha"
log "Deciding which node is Primary and which is Secondary"
bash ${CFG}/node-role.sh
log "Configuring networking"
bash ${CFG}/drbd/network.sh
log "Configuring block volume for the future DRBD device"
bash ${CFG}/storage.sh
log "Fetching parameters of Service IP"
bash ${CFG}/floating-ip/determine.sh
log "Configuring and spinning up DRBD device"
bash ${CFG}/drbd/drbd.sh
log "Configuring and spinning up Pacemaker and Corosync"
bash ${CFG}/pacemaker.sh
log "Adding Service IP as a resource to Pacemaker"
bash ${CFG}/floating-ip/setup.sh

log "Wiping out bootstrapping services to prevent them from accidental re-run"
# Mark that DRBD is launched to avoid creating it from scratch every time node reboots
mkdir -p /var/lib/ha
touch /var/lib/ha/bootstrap.done
# Wipe out bootstrap service to prevent it from accidental launch - which would destory all data
systemctl disable ha-bootstrap.service || true
rm -f /etc/systemd/system/ha-bootstrap.service
systemctl daemon-reload

log "Congratulations! Configuration completed successfully"
