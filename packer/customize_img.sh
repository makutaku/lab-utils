#!/bin/bash

# customize_img.sh
# Script to customize IMG files by resizing and applying various configurations
# using virt-customize.

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
  echo "  --force                    Force reprocessing by overriding existing configurations." >&2
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

# Function to customize the IMG file
customize_img() {
  local img_file="$1"

  # Default configurations
  TIMEZONE="America/Chicago"
  IMAGE_SIZE="32G"

  # Check if the IMG file exists
  if [[ ! -f "$img_file" ]]; then
    error_exit "IMG file '$img_file' does not exist."
  fi

  # Resize the image
  if [ "$DRY_RUN" = true ]; then
    log_info "Dry-run: Would resize the image to $IMAGE_SIZE."
  else
    log_info "Resizing the image to $IMAGE_SIZE..."
    if ! qemu-img resize "$img_file" "$IMAGE_SIZE"; then
      error_exit "Failed to resize IMG file."
    fi
    log_info "Image resized successfully."
  fi

  # Customize the image with virt-customize
  if [ "$DRY_RUN" = true ]; then
    log_info "Dry-run: Would customize the IMG file with virt-customize."
  else
    log_info "Customizing the IMG file with virt-customize..."
    if ! sudo virt-customize -a "$img_file" \
      --install qemu-guest-agent,cloud-init,smbclient,cifs-utils \
      --timezone "$TIMEZONE" \
      --run-command 'sed -i "s/^PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config' \
      --run-command 'sed -i "s/^#PermitRootLogin.*/PermitRootLogin prohibit-password/" /etc/ssh/sshd_config' \
      --run-command 'apt-get update && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && apt-get clean' \
      --run-command 'rm -rf /var/lib/apt/lists/*' \
      --run-command 'dd if=/dev/zero of=/EMPTY bs=1M || true' \
      --run-command 'rm -f /EMPTY' \
      --run-command 'cloud-init clean' \
      --run-command 'echo "vm.overcommit_memory=1" > /etc/sysctl.d/99-overcommit.conf' \
      --run-command 'echo "vm.swappiness=10" >> /etc/sysctl.d/99-custom.conf' \
      --run-command 'echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.d/99-custom.conf' \
      --run-command 'echo "fs.inotify.max_user_watches=262144" >> /etc/sysctl.d/99-custom.conf' \
      --truncate '/etc/machine-id'; then
        error_exit "Failed to customize IMG file."
    fi
    log_info "IMG file customized successfully."
  fi

  # Convert IMG to QCOW2 format
  if [ "$DRY_RUN" = true ]; then
    log_info "Dry-run: Would convert IMG to QCOW2 format."
  else
    log_info "Converting IMG to QCOW2 format..."
    if ! qemu-img convert -p -f raw -O qcow2 "$img_file" "${img_file}.qcow2"; then
      error_exit "Failed to convert IMG to QCOW2 format."
    fi
    mv "${img_file}.qcow2" "$img_file"
    log_info "Conversion to QCOW2 format completed successfully."
  fi
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

  # If FORCE is enabled, you might want to adjust behavior accordingly
  if [ "$FORCE" = true ]; then
    log_info "Force mode enabled. Overriding default behaviors as needed."
    # Implement any force-specific logic here if necessary
    # For example, skipping certain checks or forcing overwrites
  fi

  # Call the customization function
  customize_img "$INPUT_FILE"
}

# Invoke the main function with all script arguments
main "$@"
