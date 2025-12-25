#!/usr/bin/env bash
set -euo pipefail

echo "Post-reboot HA bootstrap started"

# Enable DRBD driver
modprobe drbd
lsmod | grep drbd

# 2. Network prep
#bash /opt/ha/sources/network.sh

# 3. DRBD
#bash /opt/ha/sources/drbd.sh

# 4. Corosync + Pacemaker
#bash /opt/ha/sources/cluster.sh

# 5. Floating IP (OCI API, instance principal)
#bash /opt/ha/sources/floating-ip.sh

touch /var/lib/ha/bootstrap.done
echo "Post-reboot HA bootstrap completed"
