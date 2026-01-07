#!/usr/bin/env bash
set -euo pipefail
exec >> /var/log/ha-bootstrap.log 2>&1

source /etc/ha/stack.env

export OCI_CLI_AUTH=instance_principal

log() {
	echo "[$(date -Is)] BOOTSTRAP: $*"
}
