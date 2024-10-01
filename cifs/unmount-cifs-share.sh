#!/bin/bash

# Script to unmount a CIFS (SMB) network share and remove its entry from /etc/fstab.
# Requires only the mount point to identify and remove the share.

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display usage information
usage() {
    cat <<EOF
Usage: $0 --mount-point <mount_point> [--help]

Arguments:
  --mount-point, -m    The local directory where the share is mounted (e.g., /mnt/backups)
  --help, -?           Display this help and exit

Example:
  sudo $0 --mount-point /mnt/backups
  sudo $0 -m /mnt/mybackups
EOF
    exit 1
}

# Function to display informational messages
echo_info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

# Function to display success messages
echo_success() {
    echo -e "\e[32m[SUCCESS]\e[0m $1"
}

# Function to display error messages
echo_error() {
    echo -e "\e[31m[ERROR]\e[0m $1" >&2
}

# Parse named arguments
MOUNT_POINT=""

while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        --mount-point|-m)
            MOUNT_POINT="$2"
            shift 2
            ;;
        --help|-?)
            usage
            ;;
        *)
            echo_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required argument
if [[ -z "$MOUNT_POINT" ]]; then
    echo_error "Missing required argument: --mount-point."
    usage
fi

# Configuration Variables
FSTAB_FILE="/etc/fstab"
BACKUP_DIR="/etc/fstab_backups"
TIMESTAMP=$(date +%F_%T)

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo_error "This script must be run as root. Use sudo."
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Check if the share is mounted
if mountpoint -q "$MOUNT_POINT"; then
    echo_info "The share is currently mounted at $MOUNT_POINT."

    # Unmount the share
    echo_info "Unmounting the share from $MOUNT_POINT..."
    umount "$MOUNT_POINT"
    echo_success "The share has been unmounted from $MOUNT_POINT."
else
    echo_info "The share is not currently mounted at $MOUNT_POINT."
fi

# Backup /etc/fstab
BACKUP_FILE="${BACKUP_DIR}/fstab.bak_${TIMESTAMP}"
echo_info "Backing up $FSTAB_FILE to $BACKUP_FILE..."
cp "$FSTAB_FILE" "$BACKUP_FILE"
echo_success "Backup created at $BACKUP_FILE."

# Identify and remove the fstab entry based on the mount point
FSTAB_ENTRY=$(grep -E "^//[^ ]+ ${MOUNT_POINT} cifs " "$FSTAB_FILE" || true)

if [[ -n "$FSTAB_ENTRY" ]]; then
    echo_info "Removing CIFS mount entry from $FSTAB_FILE..."
    grep -Fxv "$FSTAB_ENTRY" "$FSTAB_FILE" > "${FSTAB_FILE}.tmp" && mv "${FSTAB_FILE}.tmp" "$FSTAB_FILE"
    echo_success "Mount entry removed from $FSTAB_FILE."

    # Reload systemd to recognize the updated fstab
    echo_info "Reloading systemd daemon to recognize updated fstab entries..."
    systemctl daemon-reload
    echo_success "Systemd daemon reloaded successfully."
else
    echo_info "No mount entry found for the specified mount point in $FSTAB_FILE."
fi

echo_success "CIFS (SMB) share unmounting and fstab cleanup completed successfully."

exit 0
