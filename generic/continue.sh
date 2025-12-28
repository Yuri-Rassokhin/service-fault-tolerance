#!/usr/bin/env bash
set -euo pipefail
exec >> /var/log/ha-bootstrap.log 2>&1

echo "Post-reboot HA bootstrap started"

# Enable DRBD driver
modprobe drbd
lsmod | grep drbd

# Network configuration
bash /opt/ha/drbd/network.sh

# Block Volume
bash /opt/ha/storage.sh

# Determine and configure Floating IP
bash /opt/ha/floating-ip/determine.sh

# Configure and start DRBD device
bash /opt/ha/drbd/drbd.sh

# 4. Corosync + Pacemaker
#bash /opt/ha/sources/cluster.sh

# 5. Floating IP (OCI API, instance principal)
#bash /opt/ha/sources/floating-ip.sh

touch /var/lib/ha/bootstrap.done
echo "Post-reboot HA bootstrap completed"
