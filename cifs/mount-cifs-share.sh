#!/bin/bash

# Script to mount a CIFS (SMB) network share based on user-provided named arguments
# Ensures idempotency and does not modify existing /etc/fstab entries or the credentials file.

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display usage information
usage() {
    cat <<EOF
Usage: $0 --host <host> --share <share> --credentials <credentials_file> [--mount-point <mount_point>]

Arguments:
  --host, -h           The IP address or hostname of the SMB/CIFS server (e.g., 192.168.1.214)
  --share, -s          The name of the shared folder on the server (e.g., ak-backups)
  --credentials, -c    The path to the credentials file (e.g., /root/.ak-netops-smb-cred)
  --mount-point, -m    (Optional) The local directory where the share will be mounted (e.g., /mnt/ak-backups)
                       If not provided, defaults to /mnt/<share>
  --help, -?           Display this help and exit

Example:
  sudo $0 --host 192.168.1.214 --share ak-backups --credentials /etc/samba/.ak-netops-smb-cred
  sudo $0 -h 192.168.1.214 -s ak-backups -c /etc/samba/.ak-netops-smb-cred -m /mnt/mybackups
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

# Function to check if an exact fstab entry exists
fstab_entry_exists() {
    grep -Fxq "$1" "$FSTAB_FILE"
}

# Function to validate mount point format
is_mountpoint_valid() {
    if [[ "$MOUNT_POINT" =~ ^/mnt/[^/]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Parse named arguments using getopts
# Initialize variables
HOST=""
SHARE=""
CREDENTIALS_FILE=""
MOUNT_POINT=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        --host|-h)
            HOST="$2"
            shift 2
            ;;
        --share|-s)
            SHARE="$2"
            shift 2
            ;;
        --credentials|-c)
            CREDENTIALS_FILE="$2"
            shift 2
            ;;
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

# Validate required arguments
if [[ -z "$HOST" || -z "$SHARE" || -z "$CREDENTIALS_FILE" ]]; then
    echo_error "Missing required arguments: --host, --share, and/or --credentials."
    usage
fi

# Set default mount point if not provided
if [[ -z "$MOUNT_POINT" ]]; then
    MOUNT_POINT="/mnt/${SHARE}"
fi

# Configuration Variables
FSTAB_FILE="/etc/fstab"
BACKUP_DIR="/etc/fstab_backups"
TIMESTAMP=$(date +%F_%T)
FSTAB_ENTRY="//${HOST}/${SHARE} ${MOUNT_POINT} cifs credentials=${CREDENTIALS_FILE},uid=99,gid=100,_netdev,vers=3.0,noserverino,noperm 0 0"

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo_error "This script must be run as root. Use sudo."
    exit 1
fi

# Validate mount point format
if ! is_mountpoint_valid; then
    echo_error "Invalid mount point format. It should be a direct subdirectory under /mnt (e.g., /mnt/ak-backups)."
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Create Mount Point if it doesn't exist
if [ ! -d "$MOUNT_POINT" ]; then
    echo_info "Creating mount point at $MOUNT_POINT..."
    mkdir -p "$MOUNT_POINT"
    echo_success "Mount point created."
else
    echo_info "Mount point $MOUNT_POINT already exists."
fi

# Backup /etc/fstab
BACKUP_FILE="${BACKUP_DIR}/fstab.bak_${TIMESTAMP}"
echo_info "Backing up $FSTAB_FILE to $BACKUP_FILE..."
cp "$FSTAB_FILE" "$BACKUP_FILE"
echo_success "Backup created at $BACKUP_FILE."

# Add the fstab entry if it doesn't already exist
if ! fstab_entry_exists "$FSTAB_ENTRY"; then
    echo_info "Adding CIFS mount entry to $FSTAB_FILE..."
    echo "$FSTAB_ENTRY" >> "$FSTAB_FILE"
    echo_success "Mount entry added to $FSTAB_FILE."
    
    # Reload systemd to recognize the new fstab entry
    echo_info "Reloading systemd daemon to recognize new fstab entries..."
    systemctl daemon-reload
    echo_success "Systemd daemon reloaded successfully."
else
    echo_info "Mount entry already exists in $FSTAB_FILE."
fi

# Verify credentials file exists
if [ -f "$CREDENTIALS_FILE" ]; then
    echo_info "Credentials file '$CREDENTIALS_FILE' exists."
    
    # Optional: Warn if permissions are not 600
    CURRENT_PERMS=$(stat -c "%a" "$CREDENTIALS_FILE")
    if [[ "$CURRENT_PERMS" != "600" ]]; then
        echo_error "Warning: Permissions on '$CREDENTIALS_FILE' are set to '$CURRENT_PERMS'. It is recommended to set them to '600' for security."
    fi
else
    echo_error "Credentials file '$CREDENTIALS_FILE' does not exist."
    exit 1
fi

# Check if the share is already mounted
if mountpoint -q "$MOUNT_POINT"; then
    echo_info "The share is already mounted at $MOUNT_POINT."
else
    # Mount the share
    echo_info "Mounting the share at $MOUNT_POINT..."
    mount "$MOUNT_POINT"
    echo_success "The share has been mounted at $MOUNT_POINT."
fi

exit 0
