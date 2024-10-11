#!/bin/bash

# process_img.sh
# Script to process IMG files by copying to a destination directory,
# setting the time zone to Chicago, converting to QCOW2 format,
# prepending "ak-" to the final file, and managing hashes for idempotency.

set -euo pipefail

# Function to display error messages and exit
error_exit() {
  echo "Error: $1" >&2
  exit 1
}

# Function to display usage information
usage() {
  echo "Usage: $0 [OPTIONS] <path_to_img_file>" >&2
  echo
  echo "Options:" >&2
  echo "  --dst <DIRECTORY>          Specify the destination directory for the processed IMG file." >&2
  echo "  --destination <DIR>        Same as --dst; specify the destination directory." >&2
  echo "  --help                     Display this help message and exit." >&2
  echo
  echo "If neither --dst nor --destination is specified, the default './output' directory is used." >&2
  echo
  echo "Examples:" >&2
  echo "  $0 --dst /path/to/destination /path/to/image.img" >&2
  echo "  $0 --destination /path/to/destination /path/to/image.img" >&2
  exit 1
}

# Check if no arguments were provided
if [[ $# -lt 1 ]]; then
  echo "Error: No arguments provided." >&2
  usage
fi

# Initialize variables
DST_DIR="./output"
IMG_FILE=""
HASH_FILE=""
DEST_IMG_FILE=""
QCOW2_IMG_FILE=""
AK_QCOW2_IMG_FILE=""
FINAL_HASH_FILE=""

# Parse named arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dst|--destination)
      if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
        DST_DIR="$2"
        shift 2
      else
        error_exit "Argument for $1 is missing."
      fi
      ;;
    --help)
      usage
      ;;
    -*)
      error_exit "Unknown option: $1"
      ;;
    *)
      # Assume the first non-option argument is the IMG file path
      if [[ -z "$IMG_FILE" ]]; then
        IMG_FILE="$1"
        shift
      else
        error_exit "Multiple IMG file paths provided. Only one is allowed."
      fi
      ;;
  esac
done

# Check if IMG_FILE is set
if [[ -z "${IMG_FILE:-}" ]]; then
  echo "Error: No IMG file provided." >&2
  usage
fi

# Check if the IMG file exists and is a regular file
if [[ ! -f "$IMG_FILE" ]]; then
  error_exit "File '$IMG_FILE' does not exist or is not a regular file."
fi

# Check if virt-customize is installed
if ! command -v virt-customize &> /dev/null; then
  error_exit "virt-customize is not installed. Please install 'libguestfs-tools'."
fi

# Check if qemu-img is installed
if ! command -v qemu-img &> /dev/null; then
  error_exit "qemu-img is not installed. Please install it to perform image conversions."
fi

# Create the destination directory if it doesn't exist
if [[ ! -d "$DST_DIR" ]]; then
  echo "Destination directory '$DST_DIR' does not exist. Creating it..." >&2
  mkdir -p "$DST_DIR" || error_exit "Failed to create directory '$DST_DIR'."
fi

# Determine the base name of the IMG file
IMG_BASE_NAME="$(basename "$IMG_FILE")"

# Define the destination IMG file path
DEST_IMG_FILE="$DST_DIR/$IMG_BASE_NAME"

# Define the hash file path
HASH_FILE="$DST_DIR/$IMG_BASE_NAME.sha256"

# Compute the SHA256 hash of the original IMG file
echo "Computing SHA256 hash of '$IMG_FILE'..." >&2
CURRENT_HASH="$(sha256sum "$IMG_FILE" | awk '{print $1}')"

# Check if the hash file exists and matches the current hash
if [[ -f "$HASH_FILE" ]]; then
  STORED_HASH="$(cat "$HASH_FILE")"
  if [[ "$CURRENT_HASH" == "$STORED_HASH" ]]; then
    # Define the final QCOW2 file path with "ak-" prefix
    AK_QCOW2_IMG_FILE="$DST_DIR/ak-${IMG_BASE_NAME%.img}.qcow2"
    if [[ -f "$AK_QCOW2_IMG_FILE" ]]; then
      echo "Hash matches the stored hash. Skipping processing." >&2
      echo "$AK_QCOW2_IMG_FILE"
      echo "IMG processing completed for: $AK_QCOW2_IMG_FILE" >&2
      exit 0
    else
      echo "Hash matches but final QCOW2 file '$AK_QCOW2_IMG_FILE' does not exist. Reprocessing..." >&2
    fi
  else
    echo "Hash mismatch detected. Reprocessing the IMG file." >&2
  fi
else
  echo "No existing hash file found. Proceeding with processing." >&2
fi

# Copy the IMG file to the destination directory
echo "Copying IMG file to '$DEST_IMG_FILE'..." >&2
cp "$IMG_FILE" "$DEST_IMG_FILE" || error_exit "Failed to copy '$IMG_FILE' to '$DEST_IMG_FILE'."

# Export debugging variables for virt-customize
export LIBGUESTFS_DEBUG=1
export LIBGUESTFS_TRACE=1

TIMEZONE="America/Chicago"
IMAGE_SIZE="32G"

# Resize the image
echo "Resizing the image..."
qemu-img resize "$DEST_IMG_FILE" "$IMAGE_SIZE"

# Customize the image with qemu-guest-agent, timezone, and SSH settings
echo "Using virt-customize on '$DEST_IMG_FILE'..." >&2
sudo virt-customize -a "$DEST_IMG_FILE" \
  --install qemu-guest-agent,cloud-init,smbclient,cifs-utils \
  --timezone $TIMEZONE \
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
  || error_exit "Failed to set time zone on '$DEST_IMG_FILE'."

  #--run-command 'echo "vm.nr_hugepages=2048" >> /etc/sysctl.d/99-hugepages.conf'
  #--run-command 'echo "net.core.rmem_max=16777216" >> /etc/sysctl.d/99-network.conf'
  #--run-command 'echo "net.core.wmem_max=16777216" >> /etc/sysctl.d/99-network.conf'
  #--run-command 'echo "net.ipv4.tcp_fastopen=3" >> /etc/sysctl.d/99-network.conf'
  #--run-command 'echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
  #--run-command 'systemctl disable unnecessary-service.service'
  #--run-command 'mount -o remount,noatime /'
  #--run-command 'mount -o remount,noatime /var'
  #--run-command 'echo "noatime" >> /etc/fstab'


echo "Customized successfully on '$DEST_IMG_FILE'." >&2

# Define the QCOW2 image file path
if [[ "$DEST_IMG_FILE" == *.img ]]; then
  QCOW2_IMG_FILE="${DEST_IMG_FILE%.img}.qcow2"
else
  error_exit "Destination IMG file does not have a .img extension."
fi

# Convert the IMG file to QCOW2 format
echo "Converting '$DEST_IMG_FILE' to QCOW2 format as '$QCOW2_IMG_FILE'..." >&2
qemu-img convert -f raw -O qcow2 "$DEST_IMG_FILE" "$QCOW2_IMG_FILE" || error_exit "Failed to convert '$DEST_IMG_FILE' to QCOW2 format."

echo "Conversion to QCOW2 format completed successfully: '$QCOW2_IMG_FILE'." >&2

# Rename the QCOW2 file to prepend "ak-"
AK_QCOW2_IMG_FILE="${DST_DIR}/ak-${IMG_BASE_NAME%.img}.qcow2"
echo "Renaming '$QCOW2_IMG_FILE' to '$AK_QCOW2_IMG_FILE'..." >&2
mv "$QCOW2_IMG_FILE" "$AK_QCOW2_IMG_FILE" || error_exit "Failed to rename '$QCOW2_IMG_FILE' to '$AK_QCOW2_IMG_FILE'."

echo "Renaming completed successfully: '$AK_QCOW2_IMG_FILE'." >&2

# Compute hash of the final QCOW2 file
echo "Computing SHA256 hash of '$AK_QCOW2_IMG_FILE'..." >&2
FINAL_HASH="$(sha256sum "$AK_QCOW2_IMG_FILE" | awk '{print $1}')"

# Define the final hash file path
FINAL_HASH_FILE="$AK_QCOW2_IMG_FILE.sha256"

# Save the final hash to the hash file
echo "Saving SHA256 hash of final file to '$FINAL_HASH_FILE'..." >&2
echo "$FINAL_HASH" > "$FINAL_HASH_FILE" || error_exit "Failed to write hash to '$FINAL_HASH_FILE'."

echo "Hash of final file saved successfully." >&2

# Save the hash of the input IMG file to the hash file
echo "Saving SHA256 hash of original IMG file to '$HASH_FILE'..." >&2
echo "$CURRENT_HASH" > "$HASH_FILE" || error_exit "Failed to write hash to '$HASH_FILE'."

echo "Hash of original IMG file saved successfully." >&2

echo "Removing temporary RAW IMG file '$DEST_IMG_FILE'..." >&2
rm "$DEST_IMG_FILE" || error_exit "Failed to remove original IMG file '$DEST_IMG_FILE'."
echo "Temporary RAW IMG file removed." >&2

# Output the full path of the final QCOW2 file to stdout
echo "$AK_QCOW2_IMG_FILE"

echo "IMG processing completed for: $AK_QCOW2_IMG_FILE" >&2
