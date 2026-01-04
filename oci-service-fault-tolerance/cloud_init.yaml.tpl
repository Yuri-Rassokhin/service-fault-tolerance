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
  - mkdir -p /etc/ha
  - chmod 700 /etc/ha

  # Optional: log cloud-init progress
  - echo "HA stack bootstrap started" >> /var/log/ha-bootstrap.log

  # Fetch HA scripts bundle
  - mkdir -p /opt/ha
  - curl -fsSL https://codeload.github.com/Yuri-Rassokhin/service-fault-tolerance/tar.gz/refs/heads/main | tar -xz --strip-components=2 -C /opt/ha service-fault-tolerance-main/generic
  - chmod +x /opt/ha/*.sh

  # Configure HA phase 2 (post-reboot)
  - cp /opt/ha/ha-bootstrap.service /etc/systemd/system/ha-bootstrap.service
  - systemctl daemon-reload
  - systemctl enable ha-bootstrap.service

  # Execute HA setup phase 1 (get DRBD-capable kernel and system dependencies)
  - bash /opt/ha/setup.sh >> /var/log/ha-bootstrap.log 2>&1

