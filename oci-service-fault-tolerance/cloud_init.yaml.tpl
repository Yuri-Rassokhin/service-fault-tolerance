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
    set -euxo pipefail
    echo "$(date -Is) ***** HA STACK BOOTSTRAP STARTED *****" > /var/log/ha-bootstrap.log

    # Location of HA state file
    mkdir -p /etc/ha
    chmod 700 /etc/ha
    # Get HA bootstrap bundle
    mkdir -p /opt/ha
    curl -fsSL https://codeload.github.com/Yuri-Rassokhin/service-fault-tolerance/tar.gz/refs/heads/main | tar -xz --strip-components=2 -C /opt/ha service-fault-tolerance-main/ol
    chmod +x /opt/ha/*.sh

    # Prepare files of Pacemaker agents to prevent race condition later, when Pacemaker cluster will have started
    AGENT_DIR="/usr/lib/ocf/resource.d/custom"
    mkdir -p $${AGENT_DIR}
    chmod 755 "$${AGENT_DIR}"
    CONFIG_PATH="/opt/ha"

    # Agent: Service IP
    MOVE_SCRIPT="/usr/local/bin/move_floating_ip.sh"
    install -m 0755 $${CONFIG_PATH}/floating-ip/move.sh $${MOVE_SCRIPT}
    restorecon -v "$$MOVE_SCRIPT"
    install -m 0755 $${CONFIG_PATH}/floating-ip/pacemaker.sh $${AGENT_DIR}/pacemaker
    restorecon -v "$${AGENT_DIR}/pacemaker"

    # Agent: DNS
    install -m 0755 $${CONFIG_PATH}/dns/oci-dns.sh "$${AGENT_DIR}/oci-dns"
    restorecon -v "$${AGENT_DIR}/oci-dns"

    # Configure HA phase 2 (post-reboot)
    cp /opt/ha/ha-bootstrap.service /etc/systemd/system/ha-bootstrap.service
    systemctl daemon-reload
    systemctl enable ha-bootstrap.service

    # Execute HA setup phase 1 (get DRBD-capable kernel and system dependencies)
    bash /opt/ha/dependencies.sh >> /var/log/ha-bootstrap.log 2>&1

