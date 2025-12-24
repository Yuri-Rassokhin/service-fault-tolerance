#!/usr/bin/env bash
set -e

STATE_FILE="/var/lib/ha/ha_state.env"

if [ ! -f "$STATE_FILE" ]; then
  echo "Error: HA state file not found: $STATE_FILE"
  exit 1
fi

source "$STATE_FILE"



if ip addr show dev "$IFACE" | grep -q "$SERVICE_IP"; then
  echo "Removing IP $SERVICE_IP from $IFACE"
  sudo ip addr del "$SERVICE_IP/$CIDR_PREFIX" dev "$IFACE"
else
  echo "IP $SERVICE_IP not present on $IFACE"
fi

