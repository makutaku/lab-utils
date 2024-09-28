#!/bin/bash

# -----------------------------------------------------------------------------
# Script: create_volume_symlinks.sh
# Description: Creates symbolic links for all Docker volumes used by a specified Docker Compose project.
# Usage: ./create_volume_symlinks.sh [<project_name>] [<target_directory>]
# If <project_name> is not provided, defaults to the current directory name.
# If <target_directory> is not provided, defaults to "./volumes"
# -----------------------------------------------------------------------------

# Configuration: Set the Docker Compose project label key
PROJECT_LABEL_KEY="com.docker.compose.project"

# Function to display usage
usage() {
    echo "Usage: $0 [<project_name>] [<target_directory>]"
    echo "  <project_name>      : Name of the Docker Compose project (optional)"
    echo "                        Defaults to the name of the current directory."
    echo "  <target_directory>  : Directory where symbolic links will be created (optional)"
    echo "                        Defaults to './volumes'"
    exit 1
}

# Function to get the current directory name
get_current_dir_name() {
    basename "$PWD"
}

# Parse arguments
PROJECT_NAME=""
TARGET_DIR="./volumes"

if [ $# -gt 2 ]; then
    usage
fi

if [ $# -ge 1 ]; then
    PROJECT_NAME="$1"
fi

if [ $# -ge 2 ]; then
    TARGET_DIR="$2"
fi

# If project name is not provided, default to the current directory name
if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME=$(get_current_dir_name)
    echo "No project name provided. Using current directory name as project name: '$PROJECT_NAME'"
fi

# Create target directory if it doesn't exist
if [ ! -d "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create target directory '$TARGET_DIR'. Check your permissions."
        exit 1
    fi
    echo "Created target directory '$TARGET_DIR'."
fi

# Retrieve all volumes with the specified project label
VOLUMES=$(docker volume ls --filter "label=${PROJECT_LABEL_KEY}=${PROJECT_NAME}" --format '{{.Name}}')

# Check if any volumes are found
if [ -z "$VOLUMES" ]; then
    echo "No Docker volumes found for project '$PROJECT_NAME'."
    exit 0
fi

declare -A VOLUME_MOUNTPOINTS

# Iterate over each volume to get its mountpoint
for VOLUME in $VOLUMES; do
    # Get Mountpoint; handle potential errors if volume doesn't exist
    MOUNTPOINT=$(docker volume inspect "$VOLUME" --format '{{ .Mountpoint }}' 2>/dev/null)
    if [ -n "$MOUNTPOINT" ]; then
        VOLUME_MOUNTPOINTS["$VOLUME"]="$MOUNTPOINT"
    else
        VOLUME_MOUNTPOINTS["$VOLUME"]="N/A (Volume may not exist)"
    fi
done

# Check if any valid volumes were found
VALID_VOLUMES=0
for VOLUME in "${!VOLUME_MOUNTPOINTS[@]}"; do
    if [ "${VOLUME_MOUNTPOINTS[$VOLUME]}" != "N/A (Volume may not exist)" ]; then
        VALID_VOLUMES=$((VALID_VOLUMES + 1))
    fi
done

if [ "$VALID_VOLUMES" -eq 0 ]; then
    echo "No valid Docker volumes found for project '$PROJECT_NAME'."
    exit 0
fi

# Create symbolic links
echo "Creating symbolic links in '$TARGET_DIR'..."
for VOLUME in "${!VOLUME_MOUNTPOINTS[@]}"; do
    MOUNTPOINT="${VOLUME_MOUNTPOINTS[$VOLUME]}"
    
    if [ "$MOUNTPOINT" == "N/A (Volume may not exist)" ]; then
        echo "Skipping volume '$VOLUME': Mountpoint not found."
        continue
    fi

    # Define the symlink path
    SYMLINK_PATH="$TARGET_DIR/$VOLUME"

    # Check if symlink already exists
    if [ -L "$SYMLINK_PATH" ]; then
        echo "Symlink for volume '$VOLUME' already exists. Skipping."
        continue
    elif [ -e "$SYMLINK_PATH" ]; then
        echo "Warning: '$SYMLINK_PATH' exists and is not a symlink. Skipping."
        continue
    fi

    # Create the symbolic link
    ln -s "$MOUNTPOINT" "$SYMLINK_PATH"
    if [ $? -eq 0 ]; then
        echo "Created symlink: '$SYMLINK_PATH' -> '$MOUNTPOINT'"
    else
        echo "Error: Failed to create symlink for volume '$VOLUME'."
    fi
done

echo "Symbolic link creation completed."

# Optionally, list the created symbolic links
echo
echo "List of symbolic links in '$TARGET_DIR':"
ls -l "$TARGET_DIR"
