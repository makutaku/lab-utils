#!/bin/bash

# customize_img_noop.sh
# No-op customization script that logs actions without performing any modifications.

set -euo pipefail

# ----------------------------
# Function Definitions
# ----------------------------

# Function to display error messages and exit
error_exit() {
  echo "Error: $1" >&2
  exit 1
}

# Function to display usage information
usage() {
  echo "Usage: $0 <path_to_working_img_file>" >&2
  echo
  echo "Arguments:" >&2
  echo "  <path_to_working_img_file>   Path to the working IMG file to be customized." >&2
  echo
  echo "Examples:" >&2
  echo "  $0 /tmp/ak_image.img" >&2
  exit 1
}

# Function to perform no-op customization
noop_customize_img() {
  local img_file="$1"

  # Check if the IMG file exists
  if [[ ! -f "$img_file" ]]; then
    error_exit "IMG file '$img_file' does not exist."
  fi

  # Log that no customization is being performed
  echo "No-op customization script invoked for IMG file: $img_file" >&2
  echo "No changes have been made to the IMG file." >&2

  # Exit successfully
  exit 0
}

# ----------------------------
# Main Execution Flow
# ----------------------------

main() {
  # Check if help is requested
  if [[ $# -ne 1 || "$1" == "--help" || "$1" == "-h" ]]; then
    usage
  fi

  local img_file="$1"

  noop_customize_img "$img_file"
}

# Invoke the main function with all script arguments
main "$@"
