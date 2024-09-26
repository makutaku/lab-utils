#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display usage information
usage() {
    echo "Usage:"
    echo "  $0 <src> <opt> <var>"
    echo "    - Copies content from <src> to <opt>, then detaches data."
    echo "  $0 <opt> <var>"
    echo "    - Assumes content is already copied to <opt>, then detaches data."
    echo ""
    echo "Examples:"
    echo "  $0 /svr/repo /opt/repo /var/repo"
    echo "  $0 /opt/repo /var/repo"
    exit 1
}

# Check if the number of arguments is either 2 or 3
if [ "$#" -ne 2 ] && [ "$#" -ne 3 ]; then
    echo "Error: Invalid number of arguments."
    usage
fi

# Assign input arguments based on the number of arguments provided
if [ "$#" -eq 3 ]; then
    SRC_DIR="$1"
    OPT_DIR="$2"
    VAR_DIR="$3"

    # Check if source directory exists and is a directory
    if [ ! -d "$SRC_DIR" ]; then
        echo "Error: Source directory '$SRC_DIR' does not exist or is not a directory."
        exit 1
    fi

    echo "Copying contents from '$SRC_DIR' to '$OPT_DIR'..."
    # Create the <opt> directory if it doesn't exist
    mkdir -p "$OPT_DIR"

    # Copy all contents from SRC_DIR to OPT_DIR recursively, preserving permissions, ownership, and timestamps
    cp -a "$SRC_DIR"/. "$OPT_DIR"/

    echo "Copy completed."
else
    # When only two arguments are provided
    OPT_DIR="$1"
    VAR_DIR="$2"

    # Check if <opt> directory exists and is a directory
    if [ ! -d "$OPT_DIR" ]; then
        echo "Error: <opt> directory '$OPT_DIR' does not exist or is not a directory."
        exit 1
    fi
fi

# Create <var> directory if it doesn't exist
mkdir -p "$VAR_DIR"

# Function to move a directory and create a symbolic link
move_directory_and_symlink() {
    local dir_path="$1"

    # Determine the relative path from OPT_DIR
    rel_path="${dir_path#$OPT_DIR/}"

    # Determine the corresponding path in VAR_DIR
    target_path="$VAR_DIR/$rel_path"

    # Create the target directory if it doesn't exist
    target_dir=$(dirname "$target_path")
    mkdir -p "$target_dir"

    # Check if the target path already exists
    if [ -e "$target_path" ] || [ -L "$target_path" ]; then
        echo "Warning: Target directory '$target_path' already exists. Skipping."
        return
    fi

    # Move the directory to VAR_DIR
    echo "Moving directory '$dir_path' to '$target_path'..."
    mv "$dir_path" "$target_path"

    # Create a symbolic link in OPT_DIR pointing to VAR_DIR
    echo "Creating symbolic link '$dir_path' -> '$target_path'..."
    ln -s "$target_path" "$dir_path"
}

# Function to move a file and create a symbolic link
move_file_and_symlink() {
    local file_path="$1"

    # Determine the relative path from OPT_DIR
    rel_path="${file_path#$OPT_DIR/}"

    # Determine the corresponding path in VAR_DIR
    target_path="$VAR_DIR/$rel_path"

    # Create the target directory if it doesn't exist
    target_dir=$(dirname "$target_path")
    mkdir -p "$target_dir"

    # Check if the target path already exists
    if [ -e "$target_path" ] || [ -L "$target_path" ]; then
        echo "Warning: Target file '$target_path' already exists. Skipping."
        return
    fi

    # Move the file to VAR_DIR
    echo "Moving file '$file_path' to '$target_path'..."
    mv "$file_path" "$target_path"

    # Create a symbolic link in OPT_DIR pointing to VAR_DIR
    echo "Creating symbolic link '$file_path' -> '$target_path'..."
    ln -s "$target_path" "$file_path"
}

# Export functions and variables for use in subshells
export -f move_directory_and_symlink
export -f move_file_and_symlink
export OPT_DIR VAR_DIR

echo "Processing appdata directories..."
# Find all 'appdata' directories in OPT_DIR and process them
find "$OPT_DIR" -type d -name "appdata" -print0 | while IFS= read -r -d '' dir; do
    move_directory_and_symlink "$dir"
done

echo "Processing .env files..."
# Find all '.env' files (exactly named) in OPT_DIR and process them
find "$OPT_DIR" -type f -name ".env" -print0 | while IFS= read -r -d '' file; do
    move_file_and_symlink "$file"
done

echo "All operations completed successfully."
