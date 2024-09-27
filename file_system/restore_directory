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

# Check for help option
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
fi

# Check if at least the backup file argument is provided
if [ $# -lt 1 ]; then
  echo "Error: Backup file is required."
  usage
fi

# Assign meaningful variable names
BACKUP_FILE="$1"
DEST_DIR="${2:-.}"  # Default to current directory if destination is not provided

# Validate backup file
if [ ! -e "$BACKUP_FILE" ]; then
  echo "Error: Backup file '$BACKUP_FILE' does not exist."
  exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: '$BACKUP_FILE' is not a regular file."
  exit 1
fi

# Validate backup file extension
if [[ "$BACKUP_FILE" != *.tar.gz ]]; then
  echo "Error: Backup file '$BACKUP_FILE' does not have a .tar.gz extension."
  exit 1
fi

# Validate destination directory
if [ ! -d "$DEST_DIR" ]; then
  echo "Error: Destination directory '$DEST_DIR' does not exist."
  exit 1
fi

if [ ! -w "$DEST_DIR" ]; then
  echo "Error: Destination directory '$DEST_DIR' is not writable."
  exit 1
fi

# Extract the directory name from the backup file name
# Assuming the backup file is named like <DIR_NAME>_YYYYMMDD_HHMMSS.tar.gz
BASE_NAME=$(basename "$BACKUP_FILE" .tar.gz)
DIR_NAME="${BASE_NAME%_*}"  # Remove the timestamp part

# Check if the target directory already exists to prevent overwriting
TARGET_PATH="${DEST_DIR%/}/$DIR_NAME"
if [ -e "$TARGET_PATH" ]; then
  echo "Error: Target directory '$TARGET_PATH' already exists."
  exit 1
fi

# Create the target directory
mkdir -p "$TARGET_PATH"

# Extract the tar.gz archive
if tar -xzpf "$BACKUP_FILE" -C "$DEST_DIR"; then
  echo "Restore completed successfully to: $TARGET_PATH"
else
  echo "Error: Restore failed."
  exit 1
fi
