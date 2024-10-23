#!/bin/bash

# process_download.sh
# Script to process downloaded files based on their extension.

# Function to display usage information
usage() {
  echo "Usage: $0 [OPTIONS]" >&2
  echo
  echo "This script reads a file path from stdin and processes it based on its extension." >&2
  echo
  echo "Options:" >&2
  echo "  --help    Display this help message and exit." >&2
  echo
  echo "Example:" >&2
  echo "  ./download.sh --url <URL> --dst <DIR> | ./process_download.sh" >&2
  exit 1
}

# Handle --help argument
if [[ "$1" == "--help" ]]; then
  usage
fi

# Read the file path from stdin
read -r FILEPATH

# Check if FILEPATH is provided
if [[ -z "$FILEPATH" ]]; then
  echo "Error: No file path provided." >&2
  usage
fi

# Check if the file exists
if [[ ! -f "$FILEPATH" ]]; then
  echo "Error: File '$FILEPATH' does not exist." >&2
  exit 1
fi

# Get the file extension in lowercase
EXT="${FILEPATH##*.}"
EXT="${EXT,,}"  # Convert to lowercase

# Process based on file extension
case "$EXT" in
  iso)
    echo "Processing ISO file: $FILEPATH" >&2
    ./process_iso.sh "$FILEPATH"
    ;;
  img)
    echo "Processing IMG file: $FILEPATH" >&2
    ./process_img.sh "$FILEPATH"
    ;;
  *)
    echo "Error: Unsupported file type '.$EXT'." >&2
    exit 1
    ;;
esac

