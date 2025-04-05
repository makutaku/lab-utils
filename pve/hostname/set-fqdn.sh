#!/bin/bash
# set-fqdn.sh
#
# Usage: sudo ./set-fqdn.sh <short-hostname> <domain> <static-ip>
#
# This script sets the Fully Qualified Domain Name (FQDN) for a Proxmox node,
# updates /etc/hostname with the short hostname, and revises /etc/hosts to map
# the provided static IP to the new FQDN and short hostname.
#
# Recommended for production Proxmox clusters where each node has a static IP.
#

# Ensure the script is run as root.
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root. Exiting."
  exit 1
fi

# Validate input arguments.
if [ $# -ne 3 ]; then
  echo "Usage: $0 <short-hostname> <domain> <static-ip>"
  exit 1
fi

SHORT_HOSTNAME="$1"
DOMAIN="$2"
STATIC_IP="$3"
FQDN="${SHORT_HOSTNAME}.${DOMAIN}"

# Validate static IP address format (simple IPv4 check).
if ! [[ $STATIC_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid static IP address: $STATIC_IP"
  exit 1
fi

echo "Setting FQDN to $FQDN with static IP $STATIC_IP"

# Set the system hostname to the FQDN.
if hostnamectl set-hostname "$FQDN"; then
  echo "Hostname successfully set to $FQDN"
else
  echo "Failed to set hostname using hostnamectl"
  exit 1
fi

# Update /etc/hostname with the short hostname.
if echo "$SHORT_HOSTNAME" > /etc/hostname; then
  echo "/etc/hostname updated with $SHORT_HOSTNAME"
else
  echo "Failed to update /etc/hostname"
  exit 1
fi

# Backup /etc/hosts before modifying it.
cp /etc/hosts "/etc/hosts.bak.$(date +%Y%m%d%H%M%S)"

# Update /etc/hosts:
# Remove any lines containing the short hostname or FQDN (as whole words),
# then add the new entry using the provided static IP.
HOSTS_FILE="/etc/hosts"
TMP_FILE=$(mktemp)

grep -vE "(\b$SHORT_HOSTNAME\b|\b$FQDN\b)" "$HOSTS_FILE" > "$TMP_FILE"

# Append the new entry.
echo "$STATIC_IP   $FQDN $SHORT_HOSTNAME" >> "$TMP_FILE"

# Replace the original /etc/hosts with the updated version.
if cp "$TMP_FILE" "$HOSTS_FILE"; then
  echo "/etc/hosts updated successfully."
else
  echo "Failed to update /etc/hosts"
  exit 1
fi

rm "$TMP_FILE"

echo "Final /etc/hosts entries for $SHORT_HOSTNAME:"
grep -E "(\b$SHORT_HOSTNAME\b|\b$FQDN\b)" "$HOSTS_FILE"

echo "Verification: 'hostname --fqdn' returns: $(hostname --fqdn)"

