#!/usr/bin/env bash

# *** Mandatory for proper logging and state consistency ***
source /opt/ha/util.sh



# Get major release number of Oracle Linux
. /etc/os-release
OL_MAJOR="${VERSION_ID%%.*}"

# Ensure DNF plugin manager
dnf install -y dnf-plugins-core
dnf install -y 'dnf-command(versionlock)'
# Disable Oracle Linux UEK, if any
dnf config-manager --disable "ol${OL_MAJOR}_UEK*" || true
# Enable base repos
dnf config-manager --enable "ol${OL_MAJOR}_baseos_latest"
dnf config-manager --enable "ol${OL_MAJOR}_appstream"
dnf config-manager --enable "ol${OL_MAJOR}_addons"

# Enabling DRBD repo
rpm -e elrepo-release || true
tee /etc/yum.repos.d/elrepo.repo <<EOF
[elrepo]
name=ELRepo.org Community Enterprise Linux Repository - el${OL_MAJOR}
baseurl=http://elrepo.org/linux/elrepo/el${OL_MAJOR}/$(arch)/
enabled=1
countme=1
gpgcheck=0
EOF

# Guarantee all needed packages are there
dnf -y install --setopt=timeout=30 --setopt=retries=3 oci-utils python-oci-cli python3 python3-pip jq git pacemaker corosync pcs resource-agents fence-agents-all iscsi-initiator-utils

# Get kernel installed BEFORE DRBD installation
BEFORE="$(rpm -q kernel-core --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort)"
# Install DRBD RPM packages
dnf install -y kmod-drbd*x drbd*x-utils
# Get kernel required by DRBD
AFTER="$(rpm -q kernel-core --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort)"
NEW_KERNELS="$(comm -13 <(echo "$BEFORE") <(echo "$AFTER"))"

if [[ -n "$NEW_KERNELS" ]]; then
  # If DRBD brought >1 kernels (which is unlikely), then we'll stick to the newest one
  TARGET_KERNEL="$(echo "$NEW_KERNELS" | sort -V | tail -1)"
else
  # If DRBD brought no new kernel, we'll use current one
  TARGET_KERNEL="$(modinfo -F vermagic drbd 2>/dev/null | awk '{print $1}')"
fi

# If there is no kernel version for DRBD, we can't deploy DRBD at all
if [[ -z "$TARGET_KERNEL" ]]; then
  log "Unable to determine target kernel for DRBD, aborting"
  exit 1
fi

# Rebooting into DRBD-required kernel (unless it's running now)
VMLINUX="/boot/vmlinuz-${TARGET_KERNEL}"

if [[ ! -f "$VMLINUX" ]]; then
  log "Kernel image $VMLINUX for DRBD not found, aborting"
  exit 1
fi

# Locking kernel packages
dnf versionlock add kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra
mkdir -p /etc/dnf/dnf.conf.d
cat >/etc/dnf/dnf.conf.d/99-no-kernel.conf <<'EOF'
[main]
exclude=kernel* kmod*
EOF

# Set the most recent DRBD-enabled kernel
grubby --set-default "$VMLINUX"
log "Default kernel set to $TARGET_KERNEL"

# Unless that kernel is already running, reboot into it
if [[ "$(uname -r)" != "$TARGET_KERNEL" ]]; then
  log "Rebooting into DRBD-compatible kernel"
  reboot
else
  log "Already running DRBD-compatible kernel, no reboot required"
fi

