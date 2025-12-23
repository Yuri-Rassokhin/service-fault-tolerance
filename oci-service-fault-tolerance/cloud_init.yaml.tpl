#cloud-config

write_files:
  - path: /etc/ha/stack.env
    permissions: "0600"
    content: |
      ############################
      # Cluster identity
      ############################
      CLUSTER_NAME=ha-drbd
      NODE_COUNT=2

      NODE_NAME=${node_name}
      PEER_NODE_NAME=${peer_node_name}

      ############################
      # Storage (DRBD)
      ############################
      VOLUME_OCID=${volume_ocid}
      BLOCK_DEVICE=/dev/oracleoci/oraclevdb
      FS_TYPE=${fs_type}
      MOUNT_POINT=${mount_point}

      ############################
      # OCI networking context
      ############################
      REGION=${region}
      SUBNET_OCID=${subnet_ocid}
      NSG_OCID=${nsg_ocid}

      ############################
      # Service exposure
      ############################
      SERVICE_HOSTNAME=${service_hostname}
      SERVICE_PORT=80
      FLOATING_IP_MODE=secondary-private-ip

      ############################
      # Auth model
      ############################
      USE_INSTANCE_PRINCIPAL=true

runcmd:
  - mkdir -p /etc/ha
  - chmod 700 /etc/ha

  # Optional: log cloud-init progress
  - echo "[cloud-init] HA stack bootstrap started" >> /var/log/ha-bootstrap.log

  # Fetch HA scripts bundle
  - curl -fsSL https://example.com/ha-scripts.tar.gz | tar -xz -C /opt/ha

  # Execute main setup
  - bash /opt/ha/setup.sh >> /var/log/ha-bootstrap.log 2>&1

