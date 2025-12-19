#!/usr/bin/env bash

# establish node resolution
sudo tee /etc/hosts <<EOF
127.0.0.1   localhost
${NODE1_IP} ${NODE1_NAME}
${NODE2_IP} ${NODE2_NAME}
EOF

# make drives visible via network
sudo firewall-cmd --zone=public --add-port=7789/tcp --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
# open ports for pacemaker and corosync
sudo firewall-cmd --add-service=high-availability --permanent
sudo firewall-cmd --reload
