#!/bin/bash

# Exit immediately if a command exits with a non-zero status,
# if undefined variables are used, and if any command in a pipeline fails
set -euo pipefail

# Function to display usage information
usage() {
  echo "Usage: $0 <backup_file> [destination_directory]"
  echo
  echo "Arguments:"
  echo "  backup_file            The .tar.gz backup file to restore."
  echo "  destination_directory  (Optional) Directory where the backup will be restored."
  echo "                         Defaults to the current directory if not provided."
  exit 1
}

# Function to display error messages
error_exit() {
  echo "Error: $1" >&2
  exit 1
}

# Check for help option
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
fi

# Check if at least the backup file argument is provided
if [ $# -lt 1 ]; then
  error_exit "Backup file is required."
  usage
fi

# Assign meaningful variable names
BACKUP_FILE="$1"
DEST_DIR="${2:-.}"  # Default to current directory if destination is not provided

# Validate backup file
if [ ! -e "$BACKUP_FILE" ]; then
  error_exit "Backup file '$BACKUP_FILE' does not exist."
fi

if [ ! -f "$BACKUP_FILE" ]; then
  error_exit "'$BACKUP_FILE' is not a regular file."
fi

# Validate backup file extension
if [[ "$BACKUP_FILE" != *.tar.gz ]]; then
  error_exit "Backup file '$BACKUP_FILE' does not have a .tar.gz extension."
fi

# Check if destination directory exists; if not, attempt to create it
if [ ! -d "$DEST_DIR" ]; then
  echo "Destination directory '$DEST_DIR' does not exist. Attempting to create it..."
  if mkdir -p "$DEST_DIR"; then
    echo "Successfully created destination directory '$DEST_DIR'."
  else
    error_exit "Failed to create destination directory '$DEST_DIR'. Please check your permissions."
  fi
fi

# Validate that destination directory is writable
if [ ! -w "$DEST_DIR" ]; then
  error_exit "Destination directory '$DEST_DIR' is not writable."
fi

# Check if 'pv' is installed
if command -v pv >/dev/null 2>&1; then
  USE_PV=true
else
  USE_PV=false
  echo "Warning: 'pv' is not installed. Progress indicator will not be shown."
  echo "To install 'pv', you can use your package manager. For example:"
  echo "  sudo apt-get install pv       # Debian/Ubuntu"
  echo "  sudo yum install pv           # CentOS/RHEL"
  echo "  sudo dnf install pv           # Fedora"
  echo "  sudo pacman -S pv             # Arch Linux"
fi

# Extract the directory name from the backup file name
# Assuming the backup file is named like <DIR_NAME>_YYYYMMDD_HHMMSS.tar.gz
BASE_NAME=$(basename "$BACKUP_FILE" .tar.gz)
# Remove the last two parts (date and time) to get the original directory name
DIR_NAME=$(echo "$BASE_NAME" | sed -E 's/_[0-9]{8}_[0-9]{6}$//')

# Check if the target directory already exists to prevent overwriting
TARGET_PATH="${DEST_DIR%/}/$DIR_NAME"
if [ -e "$TARGET_PATH" ]; then
  error_exit "Target directory '$TARGET_PATH' already exists."
fi

# Extract the tar.gz archive
echo "Starting restoration of '$BACKUP_FILE' to '$DEST_DIR'..."

if [ "$USE_PV" = true ]; then
  # Calculate total size in bytes of the backup file for progress indication
  TOTAL_SIZE=$(du -sb "$BACKUP_FILE" | awk '{print $1}')

  # Restore the archive using pv for progress indication
  pv -s "$TOTAL_SIZE" "$BACKUP_FILE" | gzip -dc | tar xpf - -C "$DEST_DIR"
else
  # Restore the archive without progress indication
  tar -xzpf "$BACKUP_FILE" -C "$DEST_DIR"
fi

echo "Restore completed successfully to: $DEST_DIR/$DIR_NAME"
