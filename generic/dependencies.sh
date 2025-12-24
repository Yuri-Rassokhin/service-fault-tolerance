#!/usr/bin/env bash
set -euo pipefail

echo "Configuring system dependencies"

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

# Install ELRepo for DRBD
if ! rpm -q elrepo-release >/dev/null 2>&1; then
  ELREPO_RPM="https://www.elrepo.org/elrepo-release-${OL_MAJOR}.el${OL_MAJOR}.elrepo.noarch.rpm"
  echo "[deps] Installing ELRepo from ${ELREPO_RPM}"
  dnf install -y "${ELREPO_RPM}"
fi

# Install core HA packages
dnf install -y \
  jq \
  git \
  python3 \
  python3-pip \
  pacemaker \
  corosync \
  pcs \
  resource-agents \
  fence-agents-all

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
  echo "Fatal: unable to determine target kernel for DRBD"
  exit 1
fi

# Rebooting into DRBD-required kernel (unless it's running now)
VMLINUX="/boot/vmlinuz-${TARGET_KERNEL}"

if [[ ! -f "$VMLINUX" ]]; then
  echo "Fatal: kernel image for DRBD not found: $VMLINUX"
  exit 1
fi

echo "Locking kernel packages in DNF to prevent future updates"
dnf versionlock add \
  kernel \
  kernel-core \
  kernel-modules \
  kernel-modules-core \
  kernel-modules-extra

echo "Locking kernel packages hard way in DNF config"
mkdir -p /etc/dnf/dnf.conf.d
cat >/etc/dnf/dnf.conf.d/99-no-kernel.conf <<'EOF'
[main]
exclude=kernel* kmod*
EOF

grubby --set-default "$VMLINUX"
echo "Default kernel set to $TARGET_KERNEL"

if [[ "$(uname -r)" != "$TARGET_KERNEL" ]]; then
  echo "Rebooting into DRBD-compatible kernel"
  reboot
else
  echo "Already running DRBD-compatible kernel, no reboot required"
fi

# OCI SDK / CLI
#python3 -m pip install --user --upgrade oci oci-cli
#export PATH="$HOME/.local/bin:$PATH"

