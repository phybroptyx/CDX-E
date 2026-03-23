#!/bin/bash
# =============================================================================
# Install QEMU Guest Agent and SPICE Agent (RHEL/CentOS)
# =============================================================================
# For air-gapped environments, ensure the local package mirror is configured
# in /etc/yum.repos.d/ BEFORE running this script.
# =============================================================================

set -e

# Install packages only if not already present (kickstart may have installed them)
if ! rpm -q qemu-guest-agent &>/dev/null; then
  echo "Installing QEMU Guest Agent..."
  yum install -y qemu-guest-agent
else
  echo "QEMU Guest Agent already installed."
fi

if ! rpm -q spice-vdagent &>/dev/null; then
  echo "Installing SPICE agent..."
  yum install -y spice-vdagent
else
  echo "SPICE agent already installed."
fi

echo "Enabling services..."
systemctl enable qemu-guest-agent
systemctl enable spice-vdagent || true

echo "Guest agent installation complete."
