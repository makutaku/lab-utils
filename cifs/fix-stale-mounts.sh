#!/bin/bash

# Script to unmount stale NFS and SMB mounts and remount them.
# Works both on Proxmox VE nodes and regular Ubuntu servers.
# On Proxmox VE nodes, handles mounts defined in both storage.cfg and /etc/fstab.
# Supports a --dry-run option to simulate actions without making changes.

DRY_RUN=false  # Default to performing real actions

# Function to print actions when dry run is enabled
dry_run_msg() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] $1"
    fi
}

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
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_msg "Would attempt to unmount $mount_point"
        return 0
    fi

    echo "Attempting to unmount $mount_point..."
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
    storage_info=$(pvesm status --storage-type nfs,cifs | awk -v mp="$mount_point" '$0 ~ mp {print $1, $2}')
    storage_id=$(echo "$storage_info" | awk '{print $1}')
    storage_type=$(echo "$storage_info" | awk '{print $2}')

    if [[ -n "$storage_id" && -n "$storage_type" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            dry_run_msg "Would remount storage: $storage_id (Type: $storage_type)"
            return 0
        fi

        echo "Remounting storage: $storage_id (Type: $storage_type)"
        if pvesm set "$storage_id" >/dev/null 2>&1; then
            echo "Successfully remounted $storage_id"
            return 0
        else
            echo "Failed to remount $storage_id"
            return 1
        fi
    else
        # Not found in pvesm, try remounting using mount
        remount_storage_standard "$mount_point"
    fi
}

# Function to remount storage using mount (for non-Proxmox systems or fstab entries)
remount_storage_standard() {
    local mount_point="$1"

    if [[ "$DRY_RUN" == true ]]; then
        dry_run_msg "Would remount $mount_point using /etc/fstab"
        return 0
    fi

    echo "Remounting $mount_point using /etc/fstab entries..."
    if mount "$mount_point" >/dev/null 2>&1; then
        echo "Successfully remounted $mount_point"
        return 0
    else
        echo "Failed to remount $mount_point"
        return 1
    fi
}

# Function to process each mount point
process_mount_point() {
    local mount_point="$1"

    echo "Checking mount point: $mount_point"

    if is_mount_stale "$mount_point"; then
        echo "Stale mount detected at $mount_point"

        if unmount_stale_mount "$mount_point"; then
            if command -v pvesm >/dev/null 2>&1; then
                # We are on a Proxmox VE node
                remount_storage_pve "$mount_point"
            else
                # We are on a regular server
                remount_storage_standard "$mount_point"
            fi
        fi
    else
        echo "$mount_point is accessible"
    fi
}

# Function to get the list of NFS and SMB mount points
get_mount_points() {
    grep -E '^[^ ]+ [^ ]+ (nfs|nfs4|cifs|smbfs) ' /proc/mounts | awk '{print $2}'
}

# Function to parse arguments (checks for --dry-run option)
parse_args() {
    while [[ "$1" != "" ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                ;;
            *)
                echo "Invalid option: $1"
                echo "Usage: $0 [--dry-run]"
                exit 1
                ;;
        esac
        shift
    done
}

# Main script execution starts here
main() {
    # Parse script arguments
    parse_args "$@"

    # Iterate over each mount point
    for mount_point in $(get_mount_points); do
        process_mount_point "$mount_point"
    done

    echo "Script execution completed."
}

# Execute the main function with passed arguments
main "$@"
