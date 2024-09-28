#!/bin/bash

# Script to restore a Docker volume from a backup
# Usage: ./restore_volume.sh [--clear] backup_file [volume_name]

# Function to display usage information
usage() {
    echo "Usage: $0 [--clear] backup_file [volume_name]"
    echo "  --clear          Optional flag to wipe out all content in the destination volume before restoration."
    echo "  backup_file      Path to the backup tar.gz file."
    echo "  volume_name      (Optional) Name of the Docker volume to restore. If not provided, it is derived from the backup file name by removing the timestamp."
    exit 1
}

# Function to derive volume name from backup file name by removing timestamp
derive_volume_name() {
    local filename
    filename=$(basename "$1")
    # Assuming the timestamp is separated by an underscore and consists of digits
    # Example: my_volume_20230930.tar.gz -> my_volume
    # Adjust the regex according to your timestamp format
    echo "$filename" | sed -E 's/_?[0-9]{8}\.tar\.gz$//'
}

# Initialize variables
CLEAR=0
ARGS=()

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --clear)
            CLEAR=1
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Check if at least one positional argument (backup_file) is provided
if [ "${#ARGS[@]}" -lt 1 ] || [ "${#ARGS[@]}" -gt 2 ]; then
    echo "Error: Incorrect number of arguments."
    usage
fi

BACKUP_FILE="${ARGS[0]}"

# Derive or assign volume name
if [ "${#ARGS[@]}" -eq 2 ]; then
    DEST_VOLUME="${ARGS[1]}"
else
    DEST_VOLUME=$(derive_volume_name "$BACKUP_FILE")
    if [ -z "$DEST_VOLUME" ]; then
        echo "Error: Failed to derive volume name from backup file. Please provide the volume name explicitly."
        exit 1
    fi
    echo "Volume name not provided. Derived volume name: '$DEST_VOLUME' from backup file: '$BACKUP_FILE'"
fi

# Check if the backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Create the destination volume if it doesn't exist
docker volume inspect "$DEST_VOLUME" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Creating Docker volume: $DEST_VOLUME"
    docker volume create "$DEST_VOLUME"
else
    echo "Docker volume '$DEST_VOLUME' already exists."
fi

# If --clear flag is set, wipe out all content in the destination volume
if [ "$CLEAR" -eq 1 ]; then
    echo "Clearing all content in the Docker volume: $DEST_VOLUME"
    docker run --rm -v "${DEST_VOLUME}":/volume alpine sh -c "rm -rf /volume/*"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to clear content in the volume '$DEST_VOLUME'."
        exit 1
    fi
    echo "Volume '$DEST_VOLUME' has been cleared."
fi

# Restore the volume from the backup
echo "Restoring volume '$DEST_VOLUME' from backup file '$BACKUP_FILE'..."
docker run --rm \
    -v "${DEST_VOLUME}":/volume \
    -v "$(dirname "$BACKUP_FILE")":/backup \
    alpine \
    sh -c "cd /volume && tar xzf /backup/$(basename "$BACKUP_FILE")"

# Check if the restore was successful
if [ $? -eq 0 ]; then
    echo "Volume '${DEST_VOLUME}' successfully restored from backup: ${BACKUP_FILE}"
else
    echo "Error: Failed to restore volume '${DEST_VOLUME}' from backup: ${BACKUP_FILE}"
    exit 1
fi
