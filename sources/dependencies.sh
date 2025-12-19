#!/usr/bin/env bash

echo "setting system dependencies"
sudo dnf -y install https://www.elrepo.org/elrepo-release-9.el9.elrepo.noarch.rpm
sudo dnf -y install python3 python3-pip jq pacemaker corosync pcs resource-agents fence-agents-all kmod-drbd9x drbd9x-utils kernel kernel-core kernel-modules
python3 -m pip install --user --upgrade oci oci-cli

