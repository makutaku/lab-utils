#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a directory exists
directory_exists() {
    [ -d "$1" ]
}

# List of required commands
REQUIRED_CMDS=("websockify" "ss")

# Array to hold missing commands
MISSING_CMDS=()

# Check for each required command
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command_exists "$cmd"; then
        MISSING_CMDS+=("$cmd")
    fi
done

# Check for noVNC installation by verifying the directory
NOVNC_DIR="/usr/share/novnc"
if ! directory_exists "$NOVNC_DIR"; then
    MISSING_CMDS+=("novnc (directory $NOVNC_DIR not found)")
fi

# If there are missing dependencies, display instructions
if [ ${#MISSING_CMDS[@]} -ne 0 ]; then
    echo "The following required dependencies are missing:"
    for dep in "${MISSING_CMDS[@]}"; do
        echo " - $dep"
    done
    echo ""
    echo "Please install them by running the following commands:"
    echo ""
    # Separate commands for packages and directories
    PACKAGES_TO_INSTALL=()
    for dep in "${MISSING_CMDS[@]}"; do
        case "$dep" in
            websockify|ss)
                PACKAGES_TO_INSTALL+=("$dep")
                ;;
            novnc*)
                PACKAGES_TO_INSTALL+=("novnc")
                ;;
        esac
    done
    if [ ${#PACKAGES_TO_INSTALL[@]} -ne 0 ]; then
        echo "sudo apt-get update"
        echo "sudo apt-get install ${PACKAGES_TO_INSTALL[*]}"
    fi
    exit 1
fi

echo "All required dependencies are installed."

# Accept the websockify port as an optional input parameter (default to 6080)
WEBSOCKIFY_PORT=${1:-6080}
echo "Using websockify port: $WEBSOCKIFY_PORT"

# Find the VNC port used by qemu-system-x86
VNC_PORT=$(ss -tlnp | grep 'qemu-system-x86' | grep -oP '127\.0\.0\.1:\K[0-9]+')

if [ -z "$VNC_PORT" ]; then
    echo "VNC port not found. Is QEMU running?"
    exit 1
else
    echo "Found VNC port: $VNC_PORT"
fi

# Start websockify to bridge the VNC port to the web
echo "Starting websockify on port $WEBSOCKIFY_PORT..."
websockify --web="$NOVNC_DIR" "$WEBSOCKIFY_PORT" "localhost:$VNC_PORT"

