#!/bin/bash

# process_img.sh
# Script to process IMG files.

FILEPATH="$1"

if [[ -z "$FILEPATH" ]]; then
  echo "Error: No IMG file provided." >&2
  exit 1
fi

# Example processing: Display disk image information
echo "Processing IMG file: $FILEPATH" >&2

# Display disk image info using fdisk
sudo fdisk -l "$FILEPATH"

echo "IMG processing completed for: $FILEPATH" >&2

