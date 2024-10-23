#!/bin/bash

# Function to print usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "      --vmid          VM ID for template creation (default 900)"
    echo "  -f, --force         Force re-download of the Ubuntu image and recreate the VM template."
    echo "  -u, --username      Set a custom username for the cloud-init user (default: 'admin')."
    echo "  -p, --pass          Set a custom password for the cloud-init user."
    echo "  -k, --sshkeys       Set SSH keys for the cloud-init user."
    echo "  -i, --image         Specify a custom image URL or local path for the VM template."
    echo "      --script        Specify a script to customize the image."
    echo "      --script-config Specify a configuration file for the customization script."
    echo "  -s, --storage       Specify the storage location for the VM template (default: 'local-zfs')."
    echo "  -n, --name          Set the name of the VM."
    echo "  -c, --clean         Remove libguestfs-tools."
    echo "  -h, --help          Display this help message and exit."
    echo ""
    echo "This script creates a Proxmox VM template based on a specified or default Ubuntu Cloud Image."
}

set -euo pipefail
# set -x  # Uncomment to enable shell debugging

# Default values
VMID="900"
USERNAME="admin"
PASSWORD=""
SSHKEYS=""
FORCE=0
STORAGE="local-zfs"
IMAGE_URL=""
DEFAULT_IMAGE_URL="https://cloud-images.ubuntu.com/noble/20241004/noble-server-cloudimg-amd64.img"
NAME=""
CLEAN=0
SCRIPT=""
SCRIPT_CONFIG=""

# Parse command line arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        --vmid)
            if [ -z "${2:-}" ]; then
                echo "Error: --vmid requires a non-empty option argument."
                exit 1
            fi
            VMID="$2"
            shift
            ;;
        -f|--force)
            FORCE=1
            ;;
        -u|--username)
            if [ -z "${2:-}" ]; then
                echo "Error: --username requires a non-empty option argument."
                exit 1
            fi
            USERNAME="$2"
            shift
            ;;
        -p|--pass)
            if [ -z "${2:-}" ]; then
                echo "Error: --pass requires a non-empty option argument."
                exit 1
            fi
            PASSWORD="$2"
            shift
            ;;
        -k|--sshkeys)
            if [ -z "${2:-}" ]; then
                echo "Error: --sshkeys requires a non-empty option argument."
                exit 1
            fi
            SSHKEYS="$2"
            shift
            ;;
        -i|--image)
            if [ -z "${2:-}" ]; then
                echo "Error: --image requires a non-empty option argument."
                exit 1
            fi
            IMAGE_URL="$2"
            shift
            ;;
        --script)
            if [ -z "${2:-}" ]; then
                echo "Error: --script requires a non-empty option argument."
                exit 1
            fi
            SCRIPT="$2"
            shift
            ;;
        --script-config)
            if [ -z "${2:-}" ]; then
                echo "Error: --script-config requires a non-empty option argument."
                exit 1
            fi
            SCRIPT_CONFIG="$2"
            shift
            ;;
        -s|--storage)
            if [ -z "${2:-}" ]; then
                echo "Error: --storage requires a non-empty option argument."
                exit 1
            fi
            STORAGE="$2"
            shift
            ;;
        -n|--name)
            if [ -z "${2:-}" ]; then
                echo "Error: --name requires a non-empty option argument."
                exit 1
            fi
            NAME="$2"
            shift
            ;;
        -c|--clean)
            CLEAN=1
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

# If IMAGE_URL is not set, use the default image URL
if [ -z "$IMAGE_URL" ]; then
    IMAGE_URL="$DEFAULT_IMAGE_URL"
fi

# Determine if IMAGE_URL is a local file or a URL
if [ -f "$IMAGE_URL" ]; then
    # IMAGE_URL is a local file path
    ORIGINAL_IMAGE_PATH="$IMAGE_URL"
    IMAGE_NAME=$(basename "$ORIGINAL_IMAGE_PATH")
    IMAGE_PATH="./$IMAGE_NAME"
    USE_LOCAL_IMAGE=1
elif [[ "$IMAGE_URL" =~ ^(https?|ftp):// ]]; then
    # IMAGE_URL is a URL
    IMAGE_NAME=$(basename "$IMAGE_URL")
    IMAGE_PATH="./$IMAGE_NAME"
    USE_LOCAL_IMAGE=0
else
    # Check if the file exists at the given path
    if [ -f "$IMAGE_URL" ]; then
        ORIGINAL_IMAGE_PATH="$IMAGE_URL"
        IMAGE_NAME=$(basename "$ORIGINAL_IMAGE_PATH")
        IMAGE_PATH="./$IMAGE_NAME"
        USE_LOCAL_IMAGE=1
    else
        echo "Error: The provided --image argument is neither a valid URL nor a local file."
        exit 1
    fi
fi

# Validate inputs
if [ -z "$PASSWORD" ] && [ -z "$SSHKEYS" ]; then
    echo "Error: cloud-init password or ssh keys must be set."
    exit 1
fi

[ -z "$NAME" ] && NAME=$(basename "$IMAGE_NAME" .img)

# Check for required commands
check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: $1 is not installed."
        exit 1
    fi
}

REQUIRED_CMDS=("wget" "curl" "qm" "qemu-img")

for cmd in "${REQUIRED_CMDS[@]}"; do
    check_command "$cmd"
done

# If a customization script is provided, ensure it is executable
if [ -n "$SCRIPT" ]; then
    if [ ! -f "$SCRIPT" ]; then
        echo "Error: Customization script '$SCRIPT' not found."
        exit 1
    fi
    if [ ! -x "$SCRIPT" ]; then
        echo "Error: Customization script '$SCRIPT' is not executable."
        exit 1
    fi
fi

# Handle the image file
if [ "$USE_LOCAL_IMAGE" -eq 1 ]; then
    echo "Using local image file: $ORIGINAL_IMAGE_PATH"
    if [ ! -r "$ORIGINAL_IMAGE_PATH" ]; then
        echo "Error: The image file '$ORIGINAL_IMAGE_PATH' is not readable."
        exit 1
    fi
    # Always make a copy of the image to avoid modifying the original
    echo "Creating a working copy of the image..."
    cp -f "$ORIGINAL_IMAGE_PATH" "$IMAGE_PATH"
else
    # Conditionally remove and re-download the image
    if [ "$FORCE" -eq 1 ] || [ ! -f "$IMAGE_PATH" ]; then
        echo "Downloading Ubuntu Cloud Image..."
        rm -f "$IMAGE_PATH"
        if ! wget --inet4-only "$IMAGE_URL" -O "$IMAGE_PATH"; then
            echo "Error: Failed to download the image."
            exit 1
        fi
    else
        echo "Image already exists locally: $IMAGE_PATH"
    fi
fi

# Destroy existing VM template if it exists
if qm status "$VMID" &>/dev/null; then
    if [ "$FORCE" -eq 1 ]; then
        echo "Destroying existing VM template..."
        qm destroy "$VMID" --destroy-unreferenced-disks 1 --purge 1
    else
        read -p "Template $VMID already exists, do you want to replace it? y/[n] " _repl
        if [ "$_repl" = "y" ]; then
            echo "Destroying existing VM template..."
            qm destroy "$VMID" --destroy-unreferenced-disks 1 --purge 1
        else
            read -p "Enter a new template ID: " VMID
        fi
    fi
fi

# Customize the image if a script is provided
if [ -n "$SCRIPT" ]; then
    echo "Running customization script: $SCRIPT"
    CUSTOMIZE_CMD=(bash "$SCRIPT" --image "$IMAGE_PATH")
    # Pass the configuration file if provided
    if [ -n "$SCRIPT_CONFIG" ]; then
        CUSTOMIZE_CMD+=(--config "$SCRIPT_CONFIG")
    fi
    if ! "${CUSTOMIZE_CMD[@]}"; then
        echo "Error: Customization script failed."
        exit 1
    fi
else
    echo "No customization script provided. Skipping image modification."
fi

# Create the VM template
echo "Creating VM template..."
qm create "$VMID" --name "$NAME" --machine q35 --ostype l26 --cpu host \
    --cores 2 --memory 1024 --balloon 8192 --onboot 1 --agent enabled=1 \
    --net0 virtio,bridge=vmbr0,firewall=1 \
    --bios ovmf --efidisk0 "$STORAGE:0,efitype=4m" \
    --serial0 socket --vga serial0 --scsihw virtio-scsi-single

# Import the image to VM
echo "Importing image into the VM..."
if ! qm importdisk "$VMID" "$IMAGE_PATH" "$STORAGE"; then
    echo "Error: Failed to import disk."
    exit 1
fi

# Get the unused disk entry from the VM configuration
UNUSED_DISK_CONF=$(qm config "$VMID" | grep '^unused' | head -n1)

if [ -z "$UNUSED_DISK_CONF" ]; then
    echo "Error: No unused disk found after import."
    exit 1
fi

echo "Unused disk entry: $UNUSED_DISK_CONF"

# Extract the unused disk key and value
UNUSED_DISK_KEY=$(echo "$UNUSED_DISK_CONF" | cut -d':' -f1)
UNUSED_DISK_VALUE=$(echo "$UNUSED_DISK_CONF" | cut -d' ' -f2)

if [ -z "$UNUSED_DISK_KEY" ] || [ -z "$UNUSED_DISK_VALUE" ]; then
    echo "Error: Failed to parse unused disk entry."
    exit 1
fi

echo "Unused disk key: $UNUSED_DISK_KEY"
echo "Unused disk value: $UNUSED_DISK_VALUE"

# Attach the imported disk to the VM
echo "Adding disk to VM template..."
qm set "$VMID" --scsi0 "$UNUSED_DISK_VALUE,discard=on,ssd=1,iothread=1"

# Ensure the 'unused' entry no longer exists
if qm config "$VMID" | grep -q "^$UNUSED_DISK_KEY:"; then
    echo "Deleting leftover unused disk entry: $UNUSED_DISK_KEY"
    qm set "$VMID" -delete "$UNUSED_DISK_KEY"
fi

# Set the boot disk
echo "Setting boot disk..."
qm set "$VMID" --boot c --bootdisk scsi0

# Add cloud-init drive
echo "Adding cloud-init drive..."
qm set "$VMID" --scsi1 "$STORAGE:cloudinit"

# Configure network to use DHCP on net0
echo "Configuring network to use DHCP on net0..."
qm set "$VMID" --ipconfig0 ip=dhcp

# Set user/password
echo "Setting cloud-init user and password..."
qm set "$VMID" --ciuser "$USERNAME"

if [ -n "$PASSWORD" ]; then
    qm set "$VMID" --cipassword "$PASSWORD"
fi

if [ -n "$SSHKEYS" ]; then
    qm set "$VMID" --sshkeys "$SSHKEYS"
fi

# Convert VM to template
echo "Converting VM to template..."
if ! qm template "$VMID"; then
    echo "Error: Failed to convert VM to template."
    exit 1
fi

echo "VM template conversion completed successfully."

# Remove unneeded tools
if [ "$CLEAN" -eq 1 ]; then
    read -p "Are you sure you want to remove libguestfs-tools? y/[n] " _confirm
    if [ "$_confirm" = "y" ]; then
        apt-get remove -y libguestfs-tools
        apt-get autoremove -y && apt-get clean
    fi
fi

echo "Template creation script completed."
