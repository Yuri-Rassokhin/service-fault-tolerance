#!/usr/bin/env bash

echo "setting floating IP ${SERVICE_IP} on the serice hostname '${SERVICE_HOSTNAME}'"



MOVE_SCRIPT="/usr/local/bin/move_floating_ip.sh"
AGENT_DIR="/usr/lib/ocf/resource.d/custom"



sudo cp ${SOURCES}/floating-ip/move.sh ${MOVE_SCRIPT}
sudo chmod +x ${MOVE_SCRIPT}

sudo mkdir -p ${AGENT_DIR}
sudo cp ${SOURCES}/floating-ip/pacemaker.sh /usr/lib/ocf/resource.d/custom/pacemaker
sudo chmod +x /usr/lib/ocf/resource.d/custom/pacemaker

sudo pcs resource create floating-ip ocf:custom:pacemaker op monitor interval=10s timeout=5s
sudo pcs constraint colocation add floating-ip with fs_${DRBD_RESOURCE} INFINITY
sudo pcs constraint order start fs_${DRBD_RESOURCE} then start floating-ip

