#!/usr/bin/env bash
set -e

# configure kernel
sudo dnf install -y https://www.elrepo.org/elrepo-release-9.el9.elrepo.noarch.rpm
sudo dnf install -y kmod-drbd9x drbd-utils drbd-pacemaker

# tune kernel for performance
sudo tee /etc/sysctl.d/99-drbd.conf >/dev/null <<'EOF'
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
EOF

sudo sysctl --system

# ensure DRBD module is available (reboot once if needed)
REBOOT_MARKER="/var/lib/drbd/.reboot_done"
sudo mkdir -p /var/lib/drbd

if ! sudo modprobe drbd 2>/dev/null; then
  if [ ! -f "$REBOOT_MARKER" ]; then
    echo "DRBD module not available, rebooting once..."
    sudo touch "$REBOOT_MARKER"
    sudo reboot
    exit 0
  else
    echo "ERROR: DRBD still not available after reboot"
    exit 1
  fi
fi

echo "DRBD kernel module loaded successfully"
sudo rm $REBOOT_MARKER
sudo rmdir /var/lib/drbd

