#!/bin/bash

# process_iso.sh
# Script to process ISO files.

FILEPATH="$1"

if [[ -z "$FILEPATH" ]]; then
  echo "Error: No ISO file provided." >&2
  exit 1
fi

# Example processing: Mount the ISO and list its contents
echo "Mounting ISO file: $FILEPATH" >&2
MOUNT_POINT="/mnt/iso_$(basename "$FILEPATH" .iso)"

# Create mount point directory
mkdir -p "$MOUNT_POINT"

# Mount the ISO
sudo mount -o loop "$FILEPATH" "$MOUNT_POINT"

# List contents
echo "Contents of $FILEPATH:" >&2
ls -la "$MOUNT_POINT"

# Unmount after listing (optional)
sudo umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"

echo "ISO processing completed for: $FILEPATH" >&2

