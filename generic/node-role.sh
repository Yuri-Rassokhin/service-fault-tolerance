#!/usr/bin/env bash
set -euo pipefail
exec >> /var/log/ha-bootstrap.log 2>&1

STATE_FILE="/etc/ha/stack.env"

# Get HA status
if [[ ! -f "$STATE_FILE" ]]; then
  echo "Fatal: HA state file $STATE_FILE not found"
  exit 1
fi

source "$STATE_FILE"

if [[ -z "${NODE_NAME:-}" || -z "${PEER_NODE_NAME:-}" ]]; then
  echo "Fatal: HA state file is missing NODE_NAME or PEER_NODE_NAME"
  exit 1
fi

# Determine node role in a detereministic, reproducible way for the sake of idempotency
if [[ "$NODE_NAME" < "$PEER_NODE_NAME" ]]; then
  ROLE="primary"
else
  ROLE="secondary"
fi

echo "Determined node role: $ROLE"

# Idempotent writing to HA state file
if grep -q '^ROLE=' "$STATE_FILE"; then
  sed -i "s/^ROLE=.*/ROLE=$ROLE/" "$STATE_FILE"
else
  echo "ROLE=$ROLE" >> "$STATE_FILE"
fi

