#!/bin/bash

# download_ubuntu_cloudimg.sh
# Wrapper script to download the Ubuntu Noble Cloud Image with predefined URL.
# Passes all other arguments to download.sh.

# Fixed URL for the Ubuntu Noble Cloud Image
FIXED_URL="https://cloud-images.ubuntu.com/noble/20241004/noble-server-cloudimg-amd64.img"

# Function to display usage information
usage() {
  echo "Usage: $0 [OPTIONS]" >&2
  echo
  echo "This wrapper script invokes download.sh with the predefined Ubuntu Noble Cloud Image URL."
  echo "All other arguments are passed directly to download.sh."
  echo
  echo "Options:" >&2
  echo "  --hash <HASH>          The expected hash value of the file." >&2
  echo "  --filename <FILENAME>  The name to save the downloaded file as." >&2
  echo "  --dst <DIRECTORY>      The directory to download the file into." >&2
  echo "  --destination <DIR>    Same as --dst; specify the destination directory." >&2
  echo "  --overwrite            Overwrite the file if it already exists." >&2
  echo "  --dry_run              Show what would be done without making any changes." >&2
  echo "  --help                 Display this help message and exit." >&2
  echo
  echo "Example:" >&2
  echo "  $0 --dst /tmp --overwrite" >&2
  echo
  echo "This example will download the predefined Ubuntu Noble Cloud Image to /tmp and overwrite if it exists."
  exit 1
}

# Check for help flag
for arg in "$@"; do
  if [[ "$arg" == "--help" ]]; then
    usage
  fi
done

# Invoke download.sh with the fixed URL and pass all other arguments
# Ensure that download.sh is in the same directory or specify the correct path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_SCRIPT="$SCRIPT_DIR/download.sh"

if [[ ! -x "$DOWNLOAD_SCRIPT" ]]; then
  echo "Error: download.sh not found or not executable in $SCRIPT_DIR." >&2
  exit 1
fi

# Execute download.sh with the fixed URL and all other arguments
"$DOWNLOAD_SCRIPT" --url "$FIXED_URL" "$@"

