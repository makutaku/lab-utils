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

# Function to display error messages
error_exit() {
  echo "Error: $1"
  exit 1
}

# Check for help option
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
fi

# Check if at least the source directory argument is provided
if [ $# -lt 1 ]; then
  error_exit "Source directory is required."
  usage
fi

# Assign meaningful variable names
SOURCE_DIR="$1"
DEST_DIR="${2:-.}"  # Default to current directory if destination is not provided

# Validate source directory
if [ ! -e "$SOURCE_DIR" ]; then
  error_exit "Source directory '$SOURCE_DIR' does not exist."
fi

if [ ! -d "$SOURCE_DIR" ]; then
  error_exit "'$SOURCE_DIR' is not a directory."
fi

# Validate destination directory
if [ ! -d "$DEST_DIR" ]; then
  error_exit "Destination directory '$DEST_DIR' does not exist."
fi

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
  echo "  brew install pv               # macOS with Homebrew"
fi

# Get the directory name without the trailing slash
DIR_NAME=$(basename "$SOURCE_DIR")
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TARFILE="${DIR_NAME}_${TIMESTAMP}.tar.gz"
BACKUP_PATH="${DEST_DIR%/}/$TARFILE"

# Check if the backup file already exists
if [ -e "$BACKUP_PATH" ]; then
  error_exit "Backup file '$BACKUP_PATH' already exists."
fi

# Create the tar.gz archive with symbolic links dereferenced
echo "Starting backup of '$SOURCE_DIR' to '$BACKUP_PATH'..."

if [ "$USE_PV" = true ]; then
  # Calculate total size in bytes for progress indication, following symlinks
  TOTAL_SIZE=$(du -sbL "$SOURCE_DIR" | awk '{print $1}')

  # Create the archive using tar, pipe through pv for progress, then gzip
  tar -cphf - -C "$(dirname "$SOURCE_DIR")" "$DIR_NAME" | pv -s "$TOTAL_SIZE" | gzip > "$BACKUP_PATH"
else
  # Create the archive without progress indication
  tar -czphf "$BACKUP_PATH" -C "$(dirname "$SOURCE_DIR")" "$DIR_NAME"
fi

echo "Backup completed successfully: $BACKUP_PATH"
