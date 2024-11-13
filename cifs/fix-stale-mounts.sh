#!/bin/bash

# Script to detect, unmount stale NFS/SMB mounts, and remount all entries in /etc/fstab

# Initialize variables
DRY_RUN=false
STALE_MOUNTS=()
LOG_FILE="/var/log/fix-stale-mounts.log"

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

# Function to log messages
log() {
    local message="$1"
    echo "$message" | tee -a "$LOG_FILE"
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

# Function to check if a mount point is busy
is_mount_point_busy() {
    local mount_point="$1"
    if lsof +D "$mount_point" >/dev/null 2>&1; then
        return 0  # Mount point is busy
    else
        return 1  # Mount point is free
    fi
}

# Function to detect stale mounts
detect_stale_mounts() {
    log "Detecting stale NFS/SMB mounts..."
    while read -r mount_point; do
        if is_mount_stale "$mount_point"; then
            log "Stale mount detected at: $mount_point"
            STALE_MOUNTS+=("$mount_point")
        fi
    done < <(grep -E '^[^ ]+ [^ ]+ (nfs|nfs4|cifs|smbfs) ' /proc/mounts | awk '{print $2}')
}

# Function to unmount stale mounts
unmount_stale_mounts() {
    for mount_point in "${STALE_MOUNTS[@]}"; do
        log "Attempting to unmount $mount_point..."

        if $DRY_RUN; then
            log "[DRY RUN] Would attempt to unmount $mount_point"
        else
            # First, try to unmount normally
            if umount "$mount_point" >/dev/null 2>&1; then
                log "Successfully unmounted $mount_point"
            else
                log "Normal unmount failed for $mount_point. Checking for busy processes..."
                if is_mount_point_busy "$mount_point"; then
                    log "Processes are using $mount_point:"
                    lsof +D "$mount_point"
                    log "Attempting to terminate processes using $mount_point..."
                    if fuser -km "$mount_point"; then
                        log "Processes terminated. Retrying unmount..."
                        if umount "$mount_point" >/dev/null 2>&1; then
                            log "Successfully unmounted $mount_point after terminating processes"
                        else
                            log "Failed to unmount $mount_point after terminating processes"
                        fi
                    else
                        log "Failed to terminate processes using $mount_point"
                    fi
                else
                    log "$mount_point is not busy. Attempting forced unmount..."
                    if umount -f "$mount_point" >/dev/null 2>&1; then
                        log "Successfully force unmounted $mount_point"
                    else
                        log "Failed to force unmount $mount_point"
                    fi
                fi
            fi
        fi
    done
}

# Function to remount all mounts in /etc/fstab
remount_all_mounts() {
    log "Remounting all entries from /etc/fstab..."
    if $DRY_RUN; then
        log "[DRY RUN] Would run: mount -a"
    else
        if mount -a; then
            log "All entries from /etc/fstab remounted successfully."
        else
            log "Failed to remount all entries from /etc/fstab."
            log "Checking for busy mount points..."
            for mount_point in "${STALE_MOUNTS[@]}"; do
                if is_mount_point_busy "$mount_point"; then
                    log "Mount point $mount_point is still busy. Processes using it:"
                    lsof +D "$mount_point"
                fi
            done
            log "Consider manually resolving issues with busy mount points."
        fi
    fi
}

# Main script execution
main() {
    detect_stale_mounts

    if [ ${#STALE_MOUNTS[@]} -eq 0 ]; then
        log "No stale mounts detected."
    else
        unmount_stale_mounts
        remount_all_mounts
    fi

    log "Script execution completed."
}

# Execute the main function
main
