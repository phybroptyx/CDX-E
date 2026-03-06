#!/bin/bash
# =============================================================================
# Install QEMU Guest Agent and SPICE Agent (Linux)
# =============================================================================
# For air-gapped environments, ensure the local package mirror is configured
# in /etc/apt/sources.list BEFORE running this script.
# =============================================================================

set -e

export DEBIAN_FRONTEND=noninteractive

echo "Updating package index..."
apt-get update -y

echo "Installing QEMU Guest Agent..."
apt-get install -y qemu-guest-agent

echo "Installing SPICE agent..."
apt-get install -y spice-vdagent

echo "Enabling services..."
systemctl enable qemu-guest-agent
systemctl enable spice-vdagent

echo "Guest agent installation complete."
