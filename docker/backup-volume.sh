#!/bin/bash

# Script to back up a Docker volume
# Usage: ./backup_volume.sh volume_name backup_directory

SOURCE_VOLUME=$1
BACKUP_DIR=$2

# Check if both volume name and backup directory are provided
if [ -z "$SOURCE_VOLUME" ] || [ -z "$BACKUP_DIR" ]; then
    echo "Usage: $0 volume_name backup_directory"
    exit 1
fi

# Create the backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Generate a timestamped backup file name
BACKUP_FILE="${BACKUP_DIR}/${SOURCE_VOLUME}_$(date +%Y%m%d%H%M%S).tar.gz"

# Use a temporary container to back up the volume using tar
docker run --rm \
  -v "${SOURCE_VOLUME}":/volume \
  -v "${BACKUP_DIR}":/backup \
  alpine \
  sh -c "cd /volume && tar czf /backup/$(basename "$BACKUP_FILE") ."

echo "Backup of volume '${SOURCE_VOLUME}' completed: ${BACKUP_FILE}"

