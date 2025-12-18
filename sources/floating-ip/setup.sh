#!/bin/bash

echo "setting floating IP ${SERVICE_IP} on the serice hostname '${SERVICE_HOSTNAME}'"



MOVE_SCRIPT="/usr/local/bin/move_floating_ip.sh"
AGENT_DIR="/usr/lib/ocf/resource.d/custom"



sudo cp ${SOURCES}/floating-ip/floating-ip-move.sh ${MOVE_SCRIPT}

sudo mkdir -p ${AGENT_DIR}
sudo cp ${SOURCES}/floating-ip/floating-ip-pacemaker.sh /usr/lib/ocf/resource.d/custom/
sudo chmod +x /usr/lib/ocf/resource.d/custom/floating-ip-pacemaker.sh

sudo pcs resource create floating-ip ocf:custom:floating-ip-pacemaker.sh op monitor interval=10s timeout=5s
sudo pcs constraint colocation add floating-ip with fs_r0 INFINITY
sudo pcs constraint order start fs_r0 then start floating-ip

