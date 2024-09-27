#!/bin/bash

# Exit immediately if a command exits with a non-zero status,
# if undefined variables are used, and if any command in a pipeline fails
set -euo pipefail

# Function to display usage information
usage() {
  echo "Usage: $0 <source_directory> [destination_directory]"
  echo
  echo "Arguments:"
  echo "  source_directory       The directory to back up."
  echo "  destination_directory  (Optional) Directory where the backup will be saved."
  echo "                         Defaults to the current directory if not provided."
  exit 1
}

# Check for help option
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
fi

# Check if at least the source directory argument is provided
if [ $# -lt 1 ]; then
  echo "Error: Source directory is required."
  usage
fi

# Assign meaningful variable names
SOURCE_DIR="$1"
DEST_DIR="${2:-.}"  # Default to current directory if destination is not provided

# Validate source directory
if [ ! -e "$SOURCE_DIR" ]; then
  echo "Error: Source directory '$SOURCE_DIR' does not exist."
  exit 1
fi

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: '$SOURCE_DIR' is not a directory."
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

# Get the directory name without the trailing slash
DIR_NAME=$(basename "$SOURCE_DIR")
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TARFILE="${DIR_NAME}_${TIMESTAMP}.tar.gz"
BACKUP_PATH="${DEST_DIR%/}/$TARFILE"

# Check if the backup file already exists
if [ -e "$BACKUP_PATH" ]; then
  echo "Error: Backup file '$BACKUP_PATH' already exists."
  exit 1
fi

# Create the tar.gz archive with symbolic links dereferenced
if tar -czphf "$BACKUP_PATH" -C "$(dirname "$SOURCE_DIR")" "$DIR_NAME"; then
  echo "Backup completed successfully: $BACKUP_PATH"
else
  echo "Error: Backup failed."
  exit 1
fi
