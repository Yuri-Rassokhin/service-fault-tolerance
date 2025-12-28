#!/usr/bin/env bash
set -euo pipefail
#exec >> /var/log/ha-bootstrap.log 2>&1

echo "Configuring HA networking"

# Load HA context
source /etc/ha/stack.env

# Get local IP from OCI metadata
LOCAL_IP=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/vnics | jq -r '.[0].privateIp')

# Get peer IP (via DNS or metadata later)
# For now assume symmetric naming and /etc/hosts based resolution
# Placeholder – will be filled by peer node
PEER_IP=$(getent hosts "${PEER_NODE_NAME}" | awk '{print $1}' || true)

# /etc/hosts management
HOSTS_FILE="/etc/hosts"
MARKER_BEGIN="# HA-CLUSTER-BEGIN"
MARKER_END="# HA-CLUSTER-END"

sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" "$HOSTS_FILE"

cat >> "$HOSTS_FILE" <<EOF
$MARKER_BEGIN
$LOCAL_IP $NODE_NAME
${PEER_IP:-"# PEER IP UNKNOWN"} $PEER_NODE_NAME
$MARKER_END
EOF

echo "/etc/hosts updated"

# Disabling firewall as excessive layer of protection
echo "Disabling firewalld (OCI security enforced externally)"

if systemctl list-unit-files | grep -q firewalld.service; then
  systemctl stop firewalld || true
  systemctl disable firewalld || true
  systemctl mask firewalld || true
fi

