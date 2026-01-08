#!/usr/bin/env bash
set -euo pipefail
exec >> /var/log/ha-bootstrap.log 2>&1

STATE="etc/ha/stack.env"
source "$STATE"

export OCI_CLI_AUTH=instance_principal

# general log message
log() {
	echo "[$(date -Is)] BOOTSTRAP: $*"
}

state_upsert() {
    local key="$1"
    local value="$2"

    local escaped_key
    escaped_key=$(printf '%s\n' "$key" | sed 's/[.[\*^$]/\\&/g')

    if grep -q "^${escaped_key}=" "$STATE"; then
        sed -i "s|^${escaped_key}=.*|${key}=${value}|" "$STATE"
    else
        echo "${key}=${value}" >> "$STATE"
    fi
}

