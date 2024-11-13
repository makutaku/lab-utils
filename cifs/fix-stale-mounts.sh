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
            # Attempt to unmount normally
            if umount "$mount_point" >/dev/null 2>&1; then
                log "Successfully unmounted $mount_point"
            else
                log "Failed to unmount $mount_point normally."

                # Check if the mount point is still mounted
                if mountpoint -q "$mount_point"; then
                    log "$mount_point is still mounted. Attempting lazy unmount..."
                    if umount -l "$mount_point" >/dev/null 2>&1; then
                        log "Successfully lazy unmounted $mount_point"
                    else
                        log "Failed to lazy unmount $mount_point"

                        # As a last resort, force unmount
                        log "Attempting forced unmount..."
                        if umount -f "$mount_point" >/dev/null 2>&1; then
                            log "Successfully force unmounted $mount_point"
                        else
                            log "Failed to force unmount $mount_point"
                        fi
                    fi
                else
                    log "$mount_point is no longer mounted."
                fi
            fi

            # Verify if unmounting was successful
            if mountpoint -q "$mount_point"; then
                log "Warning: $mount_point is still mounted after unmount attempts."
                # Optionally, add additional diagnostics here
            else
                log "$mount_point is unmounted."
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
        if output=$(mount -a 2>&1); then
            log "All entries from /etc/fstab remounted successfully."
        else
            log "Failed to remount all entries from /etc/fstab."
            log "Mount output:"
            log "$output"

            # Check for busy mount points
            log "Checking for busy mount points..."
            for mount_point in "${STALE_MOUNTS[@]}"; do
                if mountpoint -q "$mount_point"; then
                    log "$mount_point is still mounted."
                else
                    log "$mount_point is not mounted."
                fi

                if lsof_output=$(lsof +D "$mount_point" 2>/dev/null); then
                    if [ -n "$lsof_output" ]; then
                        log "Processes using $mount_point:"
                        log "$lsof_output"
                    else
                        log "No processes are using $mount_point."
                    fi
                else
                    log "Could not check processes using $mount_point."
                fi
            done

            # Optionally, log kernel messages related to mount errors
            log "Kernel messages related to CIFS mounts:"
            dmesg | tail -n 20 | grep -i cifs | tee -a "$LOG_FILE"

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
