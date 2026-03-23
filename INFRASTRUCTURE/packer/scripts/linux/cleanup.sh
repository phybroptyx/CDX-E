#!/bin/bash
# =============================================================================
# Template Cleanup - Generalize Linux for Cloning
# =============================================================================
# Removes host-specific state so cloud-init runs cleanly on first boot.
# This must be the LAST provisioner in the Packer build.
# =============================================================================

set -e

echo "Cleaning apt cache..."
apt-get autoremove -y
apt-get clean

echo "Removing SSH host keys (regenerated on first boot)..."
rm -f /etc/ssh/ssh_host_*

echo "Clearing machine-id (regenerated on first boot)..."
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id

echo "Cleaning cloud-init state..."
cloud-init clean --logs

echo "Clearing temp files..."
rm -rf /tmp/* /var/tmp/*

echo "Clearing shell history..."
unset HISTFILE
rm -f /root/.bash_history /home/*/.bash_history

echo "Zeroing free space for thin provisioning efficiency..."
dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true
rm -f /EMPTY
sync

echo "Template cleanup complete."
