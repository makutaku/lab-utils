#!/bin/bash

# customize_img_noop.sh
# No-op customization script that logs actions without performing any modifications.

set -euo pipefail

# ----------------------------
# Function Definitions
# ----------------------------

# Function to display error messages and exit
error_exit() {
  echo "[ERROR] $1" >&2
  exit 1
}

# Function to display usage information
usage() {
  echo "Usage: $0 [options] <path_to_working_img_file>" >&2
  echo
  echo "Options:" >&2
  echo "  --force                    Force reprocessing (no effect in no-op script)." >&2
  echo "  --dry-run                  Simulate the customization process without making changes." >&2
  echo "  --verbose                  Enable detailed debug logging." >&2
  echo "  -h, --help                 Display this help message." >&2
  echo
  echo "Arguments:" >&2
  echo "  <path_to_working_img_file> Path to the working IMG file to be customized." >&2
  echo
  echo "Examples:" >&2
  echo "  $0 --verbose /tmp/ak_image.img" >&2
  echo "  $0 --force --dry-run /tmp/ak_image.img" >&2
  exit 1
}

# Function to log informational messages
log_info() {
  echo "[INFO] $@" >&2
}

# Function to log debug messages (only when verbose is enabled)
log_debug() {
  if [ "$VERBOSE" = true ]; then
    echo "[DEBUG] $@" >&2
  fi
}

# Function to perform no-op customization
noop_customize_img() {
  local img_file="$1"

  # Check if the IMG file exists
  if [[ ! -f "$img_file" ]]; then
    error_exit "IMG file '$img_file' does not exist."
  fi

  log_info "No-op customization script invoked for IMG file: $img_file"

  if [ "$DRY_RUN" = true ]; then
    log_info "Dry-run: No changes would be made to the IMG file."
  else
    log_info "No changes have been made to the IMG file."
  fi

  # Exit successfully
  exit 0
}

# ----------------------------
# Main Execution Flow
# ----------------------------

main() {
  # Initialize flag variables
  FORCE=false
  DRY_RUN=false
  VERBOSE=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force)
        FORCE=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      -h|--help)
        usage
        ;;
      --)
        shift
        break
        ;;
      -*)
        error_exit "Unknown option: $1"
        ;;
      *)
        INPUT_FILE="$1"
        shift
        ;;
    esac
  done

  # Check if input file is provided
  if [[ -z "${INPUT_FILE:-}" ]]; then
    usage
  fi

  # Display parsed flags
  log_debug "Flags set: FORCE=$FORCE, DRY_RUN=$DRY_RUN, VERBOSE=$VERBOSE"

  # Acknowledge FORCE flag even though it has no effect
  if [ "$FORCE" = true ]; then
    log_info "Force mode enabled (no effect in no-op script)."
  fi

  # Call the no-op customization function
  noop_customize_img "$INPUT_FILE"
}

# Invoke the main function with all script arguments
main "$@"
