#!/usr/bin/env bash
#
# ocf:custom:oci-dns
#

OCF_ROOT=${OCF_ROOT:-/usr/lib/ocf}
. ${OCF_ROOT}/lib/ocf-shellfuncs

STATE_FILE="/etc/ha/stack.env"

meta_data() {
cat <<EOF
<?xml version="1.0"?>
<resource-agent name="oci-dns" version="1.0">
<version>1.0</version>

<longdesc lang="en">
OCF agent to manage OCI Private DNS A-record for a floating service IP.
The record is created on start and removed on stop.
</longdesc>

<shortdesc lang="en">OCI Private DNS floating record</shortdesc>

<parameters>
</parameters>

<actions>
<action name="start" timeout="20"/>
<action name="stop" timeout="20"/>
<action name="monitor" interval="30" timeout="10"/>
<action name="validate-all" timeout="10"/>
<action name="meta-data" timeout="5"/>
</actions>
</resource-agent>
EOF
}

load_state() {
  if [[ ! -f "$STATE_FILE" ]]; then
    ocf_log err "State file $STATE_FILE not found"
    exit $OCF_ERR_GENERIC
  fi
  source "$STATE_FILE"
}

validate_all() {
  load_state

  for v in SERVICE_HOSTNAME SERVICE_IP DNS_ZONE_OCID; do
    if [[ -z "${!v:-}" ]]; then
      ocf_log err "Missing required variable: $v"
      exit $OCF_ERR_CONFIGURED
    fi
  done

  command -v oci >/dev/null || {
    ocf_log err "oci CLI not found"
    exit $OCF_ERR_INSTALLED
  }

  return $OCF_SUCCESS
}

dns_upsert() {
  ocf_log info "Upserting DNS A-record ${SERVICE_HOSTNAME} → ${SERVICE_IP}"

  oci dns record rrset update \
    --zone-name-or-id "$DNS_ZONE_OCID" \
    --domain "$SERVICE_HOSTNAME" \
    --rtype A \
    --items "[{\"rdata\":\"$SERVICE_IP\",\"ttl\":30}]" \
    --force >/dev/null
}

dns_delete() {
  ocf_log info "Deleting DNS A-record ${SERVICE_HOSTNAME}"

  oci dns record rrset delete \
    --zone-name-or-id "$DNS_ZONE_OCID" \
    --domain "$SERVICE_HOSTNAME" \
    --rtype A \
    --force >/dev/null || true
}

monitor_record() {
  oci dns record rrset get \
    --zone-name-or-id "$DNS_ZONE_OCID" \
    --domain "$SERVICE_HOSTNAME" \
    --rtype A \
    --query "data.items[?rdata=='$SERVICE_IP']" \
    --raw-output | grep -q "$SERVICE_IP"
}

case "$1" in
  meta-data)
    meta_data
    exit $OCF_SUCCESS
    ;;
  validate-all)
    validate_all
    exit $OCF_SUCCESS
    ;;
  start)
    validate_all
    dns_upsert
    exit $OCF_SUCCESS
    ;;
  stop)
    load_state
    dns_delete
    exit $OCF_SUCCESS
    ;;
  monitor)
    load_state
    if monitor_record; then
      exit $OCF_SUCCESS
    else
      exit $OCF_NOT_RUNNING
    fi
    ;;
  *)
    echo "Usage: $0 {start|stop|monitor|validate-all|meta-data}"
    exit $OCF_ERR_UNIMPLEMENTED
    ;;
esac

