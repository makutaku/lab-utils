#!/bin/bash

set -e

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <container_id> [groupname]"
  echo "       If no group name is provided, all container groups will be shown."
  exit 1
fi

VMID="$1"
GROUPNAME="$2"
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

# Get base GID
BASE_GID=$(grep "^${CURRENT_USER}:" /etc/subgid | cut -d: -f2)
if [[ -z "$BASE_GID" ]]; then
  echo "Error: Could not determine base GID from /etc/subgid"
  exit 4
fi

print_group_info() {
  local group="$1"
  local gid host_gid
  gid=$(pct exec "$VMID" -- getent group "$group" 2>/dev/null | cut -d: -f3) || return
  host_gid=$((BASE_GID + gid))

  printf "%-20s %-10s %-10s\n" "$group" "$gid" "$host_gid"
}

echo "Container ID: $VMID"
printf "%-20s %-10s %-10s\n" "Group Name" "GID" "Host GID"

if [[ -n "$GROUPNAME" ]]; then
  print_group_info "$GROUPNAME"
else
  pct exec "$VMID" -- awk -F: '{ print $1 }' /etc/group | while read group; do
    print_group_info "$group"
  done
fi

