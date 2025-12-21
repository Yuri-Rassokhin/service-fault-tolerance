#!/usr/bin/env bash
set -e

STATE_FILE="/var/lib/ha/ha_state.env"

if [ ! -f "$STATE_FILE" ]; then
  echo "Error: HA state file not found: $STATE_FILE"
  exit 1
fi

source "$STATE_FILE"



# Has it already been assigned?
if ip addr show dev "$IFACE" | grep -q "$SERVICE_IP"; then
  echo "IP $SERVICE_IP already present on $IFACE"
  exit 0
fi

echo "Assigning IP $SERVICE_IP/$CIDR_PREFIX to $IFACE"
sudo ip addr add "$SERVICE_IP/$CIDR_PREFIX" dev "$IFACE"

