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

# Function to customize the IMG file
customize_img() {
  local img_file="$1"
  TIMEZONE="America/Chicago"
  IMAGE_SIZE="32G"

  # Check if the IMG file exists
  if [[ ! -f "$img_file" ]]; then
    error_exit "IMG file '$img_file' does not exist."
  fi

  # Resize the image
  echo "Resizing the image to $IMAGE_SIZE..." >&2
  qemu-img resize "$img_file" "$IMAGE_SIZE" || error_exit "Failed to resize IMG file."

  # Customize the image with virt-customize
  echo "Customizing the IMG file with virt-customize..." >&2
  sudo virt-customize -a "$img_file" \
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
    --truncate '/etc/machine-id' \
    || error_exit "Failed to customize IMG file."

  echo "IMG file customized successfully." >&2
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

  customize_img "$img_file"
}

# Invoke the main function with all script arguments
main "$@"
