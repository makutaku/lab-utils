#!/bin/bash

set -e

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <container_id> [username]"
  echo "       If no username is provided, all container users will be shown."
  exit 1
fi

VMID="$1"
USERNAME="$2"
CURRENT_USER=root
LXC_CONFIG="/etc/pve/lxc/${VMID}.conf"

if [[ ! -f "$LXC_CONFIG" ]]; then
  echo "Error: LXC config not found for container ID $VMID"
  exit 2
fi

# Check if container is unprivileged
if ! grep -q "^unprivileged: 1" "$LXC_CONFIG"; then
  echo "Error: Container $VMID is not unprivileged. This script is for unprivileged containers only."
  exit 3
fi

# Get base UID and GID
BASE_UID=$(grep "^${CURRENT_USER}:" /etc/subuid | cut -d: -f2)
BASE_GID=$(grep "^${CURRENT_USER}:" /etc/subgid | cut -d: -f2)

if [[ -z "$BASE_UID" || -z "$BASE_GID" ]]; then
  echo "Error: Could not determine base UID/GID from /etc/subuid or /etc/subgid"
  exit 4
fi

print_user_info() {
  local user="$1"
  local uid gid host_uid host_gid
  uid=$(pct exec "$VMID" -- id -u "$user" 2>/dev/null) || return
  gid=$(pct exec "$VMID" -- id -g "$user" 2>/dev/null) || return
  host_uid=$((BASE_UID + uid))
  host_gid=$((BASE_GID + gid))

  printf "%-20s %-10s %-10s %-10s %-10s\n" "$user" "$uid" "$gid" "$host_uid" "$host_gid"
}

if [[ -n "$USERNAME" ]]; then
  echo "Container ID: $VMID"
  printf "%-20s %-10s %-10s %-10s %-10s\n" "Username" "UID" "GID" "Host UID" "Host GID"
  print_user_info "$USERNAME"
else
  echo "Container ID: $VMID"
  printf "%-20s %-10s %-10s %-10s %-10s\n" "Username" "UID" "GID" "Host UID" "Host GID"
  pct exec "$VMID" -- awk -F: '{ print $1 }' /etc/passwd | while read user; do
    print_user_info "$user"
  done
fi

