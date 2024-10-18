#!/bin/bash

set -euo pipefail

# Default values
IMAGE_PATH=""
CONFIG_FILE=""

# Function to print usage
usage() {
    echo "Usage: $0 --image IMAGE_PATH [OPTIONS]"
    echo ""
    echo "Options:"
    echo "      --image       Path to the image file (required)."
    echo "      --config      Path to the configuration file."
    echo "  -h, --help        Display this help message and exit."
    echo ""
    echo "The configuration file should contain configuration parameters and virt-customize arguments."
}

# Parse arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        --image)
            if [ -z "${2:-}" ]; then
                echo "Error: --image requires a non-empty option argument."
                exit 1
            fi
            IMAGE_PATH="$2"
            shift
            ;;
        --config)
            if [ -z "${2:-}" ]; then
                echo "Error: --config requires a non-empty option argument."
                exit 1
            fi
            CONFIG_FILE="$2"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown parameter passed: $1"
            usage
            exit 1
            ;;
    esac
    shift
done

# Validate required arguments
if [ -z "$IMAGE_PATH" ]; then
    echo "Error: --image is required."
    usage
    exit 1
fi

if [ -z "$CONFIG_FILE" ]; then
    echo "Error: --config is required."
    usage
    exit 1
fi

# Check if configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found."
    exit 1
fi

# Source the configuration file
echo "Reading configuration from: $CONFIG_FILE"
source "$CONFIG_FILE"

# Check if qemu-img is installed
if ! command -v qemu-img >/dev/null 2>&1; then
    echo "Error: qemu-img is not installed. Please install qemu-utils."
    exit 1
fi

# Resize the image if DISK_SIZE is specified
if [ -n "${DISK_SIZE:-}" ]; then
    echo "Resizing the image to $DISK_SIZE..."
    if ! qemu-img resize "$IMAGE_PATH" "$DISK_SIZE"; then
        echo "Error: Failed to resize the image."
        exit 1
    fi
    echo "Image resized."
fi

# Check if virt-customize is installed
if ! command -v virt-customize >/dev/null 2>&1; then
    echo "Error: virt-customize is not installed. Please install libguestfs-tools."
    exit 1
fi

# Initialize virt-customize arguments
VIRT_CUSTOMIZE_ARGS=("-a" "$IMAGE_PATH")

# Collect virt-customize arguments from configuration
if [ "${#VIRT_CUSTOMIZE_ARGS_ARRAY[@]}" -gt 0 ]; then
    VIRT_CUSTOMIZE_ARGS+=("${VIRT_CUSTOMIZE_ARGS_ARRAY[@]}")
fi

# Execute the virt-customize command
echo "Customizing the image with virt-customize..."
virt-customize "${VIRT_CUSTOMIZE_ARGS[@]}"

echo "Customization completed."
