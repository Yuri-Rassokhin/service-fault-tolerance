#!/usr/bin/env bash

# *** Mandatory for proper logging and state consistency ***
source /opt/ha/util.sh



if [[ -z "${NODE_NAME:-}" || -z "${PEER_NODE_NAME:-}" ]]; then
  log "State file is missing NODE_NAME or PEER_NODE_NAME, aborting"
  exit 1
fi

# Determine node role in a detereministic, reproducible way for the sake of idempotency
if [[ "$NODE_NAME" < "$PEER_NODE_NAME" ]]; then
  ROLE="primary"
else
  ROLE="secondary"
fi
log "Determined node role: $ROLE"

state_upsert("ROLE", "$ROLE")

