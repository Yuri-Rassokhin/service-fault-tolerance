#!/usr/bin/env bash
# OCF resource agent: ocf:custom:pacemaker

: ${OCF_FUNCTIONS:="${OCF_ROOT}/resource.d/heartbeat/.ocf-shellfuncs"}
[ -r "${OCF_FUNCTIONS}" ] && . "${OCF_FUNCTIONS}"

STATE_FILE="/etc/ha/stack.env"

load_state() {
  if [[ ! -f "$STATE_FILE" ]]; then
    ocf_log err "Fatal: HA state file $STATE_FILE not found"
    return $OCF_ERR_INSTALLED
  fi

  # shellcheck disable=SC1090
  source "$STATE_FILE"

  # Обязательные переменные, которые должны быть в stack.env
  : "${SERVICE_IP:?SERVICE_IP missing in $STATE_FILE}"
  : "${IFACE:?IFACE missing in $STATE_FILE}"

  # VNIC of this node, this will be required to grab Service IP
  VNIC_OCID=$(curl -s -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/vnics/ | jq -r '.[0].vnicId')
}

meta_data() {
  cat <<'EOF'
<?xml version="1.0"?>
<resource-agent name="pacemaker" version="1.0">
  <version>1.1</version>
  <longdesc lang="en">
Custom resource agent to move OCI floating secondary private IP to the active node.
  </longdesc>
  <shortdesc lang="en">OCI floating IP mover</shortdesc>

  <parameters>
    <parameter name="state_file">
      <longdesc lang="en">Path to HA state env file</longdesc>
      <shortdesc lang="en">State file</shortdesc>
      <content type="string" default="/etc/ha/stack.env"/>
    </parameter>
  </parameters>

  <actions>
    <action name="start" timeout="20s"/>
    <action name="stop" timeout="20s"/>
    <action name="monitor" timeout="10s" interval="10s"/>
    <action name="validate-all" timeout="10s"/>
    <action name="meta-data" timeout="5s"/>
  </actions>
</resource-agent>
EOF
}

# Позволим переопределить state_file через параметр ресурса
# pcs resource create floating-ip ocf:custom:pacemaker state_file=/etc/ha/stack.env
: "${OCF_RESKEY_state_file:=$STATE_FILE}"
STATE_FILE="$OCF_RESKEY_state_file"

start() {
  load_state || exit $?
  ocf_log info "Starting floating IP ${SERVICE_IP} on ${IFACE}"
  # Assign Service IP in OCI control plane
  oci network vnic assign-private-ip --ip-address ${SERVICE_IP} --unassign-if-already-assigned --vnic-id ${VNIC_OCID} 2>/dev/null || exit $OCF_ERR_GENERIC
  # Make Service IP visible in OS
  ip addr add ${SERVICE_IP}/24 dev ${IFACE} 2>/dev/null || exit $OCF_ERR_GENERIC
  exit $OCF_SUCCESS
}

stop() {
  load_state || exit $?
  ocf_log info "Stopping floating IP ${SERVICE_IP} on ${IFACE}"
  ip addr del "${SERVICE_IP}/24" dev "${IFACE}" 2>/dev/null || true
  # TODO: make netmask a parameter, remove hardcoded value
  exit $OCF_SUCCESS
}

monitor() {
  load_state || exit $?

  ip addr show dev "${IFACE}" | grep -qw "${SERVICE_IP}"
  if [[ $? -eq 0 ]]; then
    exit $OCF_SUCCESS
  else
    exit $OCF_NOT_RUNNING
  fi
}

validate_all() {
  load_state || exit $?

  command -v ip >/dev/null 2>&1 || { ocf_log err "ip command not found"; exit $OCF_ERR_INSTALLED; }
  exit $OCF_SUCCESS
}

case "${1:-}" in
  meta-data) meta_data; exit $OCF_SUCCESS ;;
  validate-all) validate_all ;;
  start) start ;;
  stop) stop ;;
  monitor) monitor ;;
  *) echo "Usage: $0 {start|stop|monitor|validate-all|meta-data}"; exit $OCF_ERR_UNIMPLEMENTED ;;
esac
