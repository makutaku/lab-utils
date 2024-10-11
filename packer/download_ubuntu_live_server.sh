#!/bin/bash

# download_ubuntu_live_server.sh
# Wrapper script to download the Ubuntu 24.04.1 Live Server ISO with predefined URL.
# Passes all other arguments to download.sh.

# Fixed URL for the Ubuntu 24.04.1 Live Server ISO
FIXED_URL="https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso"

# Function to display usage information
usage() {
  echo "Usage: $0 [OPTIONS]" >&2
  echo
  echo "This wrapper script invokes download.sh with the predefined Ubuntu 24.04.1 Live Server ISO URL."
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
  echo "If neither --dst nor --destination is specified, the current directory is used." >&2
  echo
  echo "Example:" >&2
  echo "  $0 --dst /tmp --overwrite" >&2
  echo
  echo "This example will download the predefined Ubuntu 24.04.1 Live Server ISO to /tmp and overwrite if it exists." >&2
  exit 1
}

# Check for help flag
for arg in "$@"; do
  if [[ "$arg" == "--help" ]]; then
    usage
  fi
done

# Path to download.sh (assumes it's in the same directory as this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_SCRIPT="$SCRIPT_DIR/download.sh"

# Check if download.sh exists and is executable
if [[ ! -x "$DOWNLOAD_SCRIPT" ]]; then
  echo "Error: download.sh not found or not executable in $SCRIPT_DIR." >&2
  exit 1
fi

# Execute download.sh with the fixed URL and pass all other arguments
"$DOWNLOAD_SCRIPT" --url "$FIXED_URL" "$@"

