#!/bin/bash

# Script to clone a Docker volume using tar
# Usage: ./clone_volume.sh source_volume destination_volume

SOURCE_VOLUME=$1
DEST_VOLUME=$2

# Check if both source and destination volume names are provided
if [ -z "$SOURCE_VOLUME" ] || [ -z "$DEST_VOLUME" ]; then
    echo "Usage: $0 source_volume destination_volume"
    exit 1
fi

# Create the destination volume if it doesn't exist
docker volume create "$DEST_VOLUME"

# Use a temporary container to clone the volume using tar
docker run --rm \
  -v "${SOURCE_VOLUME}":/from \
  -v "${DEST_VOLUME}":/to \
  alpine \
  sh -c "cd /from && tar cf - . | tar xf - -C /to"

echo "Volume '${SOURCE_VOLUME}' cloned to '${DEST_VOLUME}'"

