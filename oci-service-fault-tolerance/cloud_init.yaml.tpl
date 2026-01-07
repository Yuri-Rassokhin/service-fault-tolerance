#cloud-config

hostname: ${node_name}
fqdn: ${node_name}.local

package_update: false
packages:
  - git
  - jq
  - python3
  - python3-pip
  - curl

write_files:
  - path: /etc/ha/stack.env
    permissions: "0600"
    content: |
      # Cluster identity
      CLUSTER_NAME=ha-drbd
      NODE_COUNT=2
      HA_CLUSTER_PASSWORD=MyStrongPassword
      NODE_NAME=${node_name}
      PEER_NODE_NAME=${peer_node_name}

      # Storage (DRBD)
      VOLUME_OCID=${volume_ocid}
      BLOCK_DEVICE=/dev/oracleoci/oraclevdb
      FS_TYPE=${fs_type}
      MOUNT_POINT=${mount_point}
      DRBD_DEVICE=/dev/drbd0
      DRBD_RESOURCE=r0

      # Networking
      ############################
      REGION=${region}
      SUBNET_OCID=${subnet_ocid}
      NSG_OCID=${nsg_ocid}

      # Service exposure
      SERVICE_HOSTNAME=${service_hostname}
      SERVICE_PORT=80
      SERVICE_IP=${service_ip}
      IFACE=enp0s5
      DNS_ZONE_OCID=${dns_zone_ocid}
      DNS_ZONE_NAME=${dns_zone_name}
      DNS_VIEW_OCID=${dns_view_ocid}

runcmd:
  - |
    exec > >(tee -a /var/log/ha-bootstrap.log) 2>&1
    set -euxo pipefail
    echo "[$(date -Is)] BOOTSTRAP: Phase 0 started (deploying SW bundle)"

    echo "[$(date -Is)] BOOTSTRAP: Fetching HA bootstrap SW bundle"
    mkdir -p /opt/ha
    curl -fsSL https://codeload.github.com/Yuri-Rassokhin/service-fault-tolerance/tar.gz/refs/heads/main | tar -xz --strip-components=2 -C /opt/ha service-fault-tolerance-main/ol
    chmod +x /opt/ha/dependencies.sh
    chmod +x /opt/ha/floating-ip/reassign-service-ip

    # Enable utility functions such as log()
    if [[ -r /opt/ha/util.sh ]]; then
      source /opt/ha/util.sh
    else
      echo "[$(date -Is)] BOOTSTRAP: /opt/ha/util.sh not found, aborting"
      exit 1
    fi

    log "Ensuring persmissions for state directory /etc/ha/"
    install -d -m 700 /etc/ha

    log "Checking if state file exists and has proper permissions"
    STATE="/etc/ha/stack.env"
    if [[ ! -f "$STATE" ]]; then
        log "$STATE missing, aborting"
        exit 1
    fi
    PERM=$$(stat -c '%a' "$STATE")
    OWNER=$$(stat -c '%U' "$STATE")
    if [[ "$OWNER" != "root" ]]; then
        log "$STATE must be owned by root (found: $OWNER), aborting"
        exit 1
    fi
    if (( (PERM & 022) != 0 )); then
        log "$STATE permissions too permissive ($PERM), aborting"
        exit 1
    fi

    log "Deploying agent file(s)"
    install -d -m 755 /usr/lib/ocf/resource.d/custom
    install -m 0755 /opt/ha/floating-ip/reassign-service-ip /usr/lib/ocf/resource.d/custom/
    restorecon -Rv "/usr/lib/ocf/resource.d/custom" || true

    log "Preparing phase 2 (post-reboot SW configuration)"
    cp /opt/ha/ha-bootstrap.service /etc/systemd/system/ha-bootstrap.service
    systemctl daemon-reload
    systemctl enable ha-bootstrap.service

    log "Phase 1 started (configuring kernel and system-level dependencies"
    bash /opt/ha/dependencies.sh

