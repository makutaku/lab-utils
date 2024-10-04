#!/bin/bash

# Script to detect, unmount stale NFS/SMB mounts, and remount all entries in /etc/fstab

# Initialize variables
DRY_RUN=false
STALE_MOUNTS=()

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

# Function to detect stale mounts
detect_stale_mounts() {
    echo "Detecting stale NFS/SMB mounts..."
    while read -r mount_point; do
        if is_mount_stale "$mount_point"; then
            echo "Stale mount detected at: $mount_point"
            STALE_MOUNTS+=("$mount_point")
        fi
    done < <(grep -E '^[^ ]+ [^ ]+ (nfs|nfs4|cifs|smbfs) ' /proc/mounts | awk '{print $2}')
}

# Function to unmount all stale mounts
unmount_stale_mounts() {
    for mount_point in "${STALE_MOUNTS[@]}"; do
        echo "Attempting to unmount $mount_point..."

        if $DRY_RUN; then
            echo "[DRY RUN] Would attempt to unmount $mount_point"
        else
            if umount -f "$mount_point" >/dev/null 2>&1; then
                echo "Successfully unmounted $mount_point"
            else
                echo "Failed to unmount $mount_point"
            fi
        fi
    done
}

# Function to remount all mounts in /etc/fstab
remount_all_mounts() {
    echo "Remounting all entries from /etc/fstab..."
    if $DRY_RUN; then
        echo "[DRY RUN] Would run: sudo mount -a"
    else
        if sudo mount -a; then
            echo "All entries from /etc/fstab remounted successfully."
        else
            echo "Failed to remount all entries from /etc/fstab."
        fi
    fi
}

# Main script execution
main() {
    detect_stale_mounts

    if [ ${#STALE_MOUNTS[@]} -eq 0 ]; then
        echo "No stale mounts detected."
    else
        unmount_stale_mounts
        remount_all_mounts
    fi

    echo "Script execution completed."
}

# Execute the main function
main
