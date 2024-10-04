#!/bin/bash

# Script to unmount stale NFS and SMB mounts and remount them.
# Works both on Proxmox VE nodes and regular Ubuntu servers.
# On Proxmox VE nodes, handles mounts defined in both storage.cfg and /etc/fstab.
# Supports a dry run mode using --dry-run or -n options.

# Initialize variables
DRY_RUN=false

# Function to display usage information
usage() {
    echo "Usage: $0 [--dry-run|-n]"
    exit 1
}

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--dry-run)
            DRY_RUN=true
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown parameter passed: $1"
            usage
            ;;
    esac
    shift
done

# Function to check if a mount point is stale
is_mount_stale() {
    local mount_point="$1"
    if ! stat -t "$mount_point" >/dev/null 2>&1; then
        return 0  # Mount is stale
    else
        return 1  # Mount is accessible
    fi
}

# Function to unmount a mount point
unmount_stale_mount() {
    local mount_point="$1"
    echo "Attempting to unmount $mount_point..."

    if $DRY_RUN; then
        echo "[DRY RUN] Would attempt to unmount $mount_point"
        return 0
    fi

    if umount -f "$mount_point" >/dev/null 2>&1; then
        echo "Successfully unmounted $mount_point"
        return 0
    else
        echo "Failed to unmount $mount_point"
        return 1
    fi
}

# Function to remount storage on Proxmox VE using pvesm
remount_storage_pve() {
    local mount_point="$1"

    # Find the storage ID and type associated with this mount point
    storage_info=$(pvesm status 2>/dev/null | awk -v mp="$mount_point" '$0 ~ mp {print $1}')
    storage_id="$storage_info"

    if [[ -n "$storage_id" ]];
