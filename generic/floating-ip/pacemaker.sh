#!/usr/bin/env bash

. /usr/lib/ocf/lib/ocf-shellfuncs

STATE_FILE="/etc/ha/state.env"

if [ ! -f "$STATE_FILE" ]; then
  echo "Fatal: HA state file $STATE_FILE not found"
  exit 1
fi

source "${STATE_FILE}"



log() {
  ocf_log info "$1"
}



case "$1" in
  start)
    log "Starting floating IP ${SERVICE_IP} on ${IFACE}"
    ${MOVE_SCRIPT} || exit $OCF_ERR_GENERIC
    exit $OCF_SUCCESS
    ;;

  stop)
    log "Stopping floating IP ${SERVICE_IP} on ${IFACE}"
    ip addr del ${SERVICE_IP}/24 dev ${IFACE} 2>/dev/null || true
    exit $OCF_SUCCESS
    ;;

  monitor)
    ip addr show dev ${IFACE} | grep -qw "${SERVICE_IP}"
    if [[ $? -eq 0 ]]; then
      exit $OCF_SUCCESS
    else
      exit $OCF_NOT_RUNNING
    fi
    ;;

  *)
    echo "Usage: $0 {start|stop|monitor}"
    exit $OCF_ERR_UNIMPLEMENTED
    ;;
esac

