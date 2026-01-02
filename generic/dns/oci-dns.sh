#!/usr/bin/env bash
#
# ocf:custom:oci-dns
# Manage OCI Private DNS A-record for floating service IP
#

: "${OCF_ROOT:=/usr/lib/ocf}"

# Load OCF shell functions
if [[ -r "${OCF_ROOT}/resource.d/heartbeat/.ocf-shellfuncs" ]]; then
  . "${OCF_ROOT}/resource.d/heartbeat/.ocf-shellfuncs"
elif [[ -r "${OCF_ROOT}/resource.d/pacemaker/.ocf-shellfuncs" ]]; then
  . "${OCF_ROOT}/resource.d/pacemaker/.ocf-shellfuncs"
else
  echo "Cannot find OCF shell functions" >&2
  exit 1
fi

STATE_FILE="/etc/ha/stack.env"

###############################################################################
# Metadata
###############################################################################
meta_data() {
cat <<EOF
<?xml version="1.0"?>
<resource-agent name="oci-dns" version="1.0">
  <version>1.0</version>

  <longdesc lang="en">
OCF resource agent that manages an OCI *private* DNS A-record for a floating
service IP. The record is created on start, verified on monitor, and removed
on stop. Intended to be colocated with a floating IP resource.
  </longdesc>

  <shortdesc lang="en">OCI Private DNS floating A-record</shortdesc>

  <parameters>
    <parameter name="ttl">
      <longdesc lang="en">DNS record TTL</longdesc>
      <shortdesc lang="en">TTL</shortdesc>
      <content type="integer" default="30"/>
    </parameter>

    <parameter name="scope">
      <longdesc lang="en">DNS zone scope (PRIVATE only is supported)</longdesc>
      <shortdesc lang="en">Zone scope</shortdesc>
      <content type="string" default="PRIVATE"/>
    </parameter>
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

###############################################################################
# Helpers
###############################################################################
load_state() {
  if [[ ! -f "$STATE_FILE" ]]; then
    ocf_log err "State file $STATE_FILE not found"
    exit $OCF_ERR_CONFIGURED
  fi

  # shellcheck disable=SC1090
  source "$STATE_FILE"

  : "${OCF_RESKEY_ttl:=30}"
  : "${OCF_RESKEY_scope:=PRIVATE}"

  FQDN="${SERVICE_HOSTNAME}.${DNS_ZONE_NAME}"
}

validate_all() {
  load_state

  for v in SERVICE_HOSTNAME SERVICE_IP DNS_ZONE_OCID DNS_ZONE_NAME; do
    if [[ -z "${!v:-}" ]]; then
      ocf_log err "Missing required variable in state file: $v"
      exit $OCF_ERR_CONFIGURED
    fi
  done

  if [[ "$OCF_RESKEY_scope" != "PRIVATE" ]]; then
    ocf_log err "Only PRIVATE DNS zones are supported"
    exit $OCF_ERR_CONFIGURED
  fi

  if ! command -v oci >/dev/null 2>&1; then
    ocf_log err "oci CLI not found"
    exit $OCF_ERR_CONFIGURED
  fi

  return $OCF_SUCCESS
}

###############################################################################
# DNS operations
###############################################################################
dns_upsert() {
  ocf_log info "Upserting DNS A-record ${FQDN} -> ${SERVICE_IP}"

  oci dns record zone patch \
    --zone-name-or-id "$DNS_ZONE_OCID" \
    --view-id "$DNS_VIEW_OCID" \
    --scope PRIVATE \
    --items "[{
      \"domain\":\"${FQDN}\",
      \"rtype\":\"A\",
      \"rdata\":\"${SERVICE_IP}\",
      \"ttl\":${OCF_RESKEY_ttl},
      \"operation\":\"ADD\"
    }]" \
    --force >/dev/null
}

dns_delete() {
  ocf_log info "Deleting DNS A-record ${FQDN} rdata=${SERVICE_IP}"

  oci dns record zone patch \
    --zone-name-or-id "$DNS_ZONE_OCID" \
    --view-id "$DNS_VIEW_OCID" \
    --scope PRIVATE \
    --items "[{
      \"domain\":\"${FQDN}\",
      \"rtype\":\"A\",
      \"rdata\":\"${SERVICE_IP}\",
      \"ttl\":${OCF_RESKEY_ttl},
      \"operation\":\"REMOVE\"
    }]" \
    --force >/dev/null || true
}

monitor_record() {
  oci dns record domain get \
    --zone-name-or-id "$DNS_ZONE_OCID" \
    --view-id "$DNS_VIEW_OCID" \
    --domain "$FQDN" \
    --rtype A \
    --query "data.items[].rdata" \
    --raw-output 2>/dev/null \
  | grep -qx "$SERVICE_IP"
}

###############################################################################
# Main
###############################################################################
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
