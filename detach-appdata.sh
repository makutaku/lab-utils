#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# -----------------------------
# Configuration
# -----------------------------

# Array of directories to process
DIRECTORIES=(
    "appdata"
    "logs"
    # Add more directories here, e.g., "cache", "data"
)

# Array of files to process
FILES=(
    ".env"
    # Add more files here, e.g., "config.yaml", "settings.json"
)

# -----------------------------
# Function Definitions
# -----------------------------

# Function to display usage information
usage() {
    echo "Usage:"
    echo "  $0 <src> <dst> [--dry-run]"
    echo ""
    echo "Parameters:"
    echo "  <src>      - Source directory (e.g., /opt/repo)"
    echo "  <dst>      - Destination directory (e.g., /var/repo)"
    echo "  --dry-run  - (Optional) Perform a trial run with no changes made"
    echo ""
    echo "Examples:"
    echo "  $0 /opt/labstacks/testing /var/labstacks/testing"
    echo "  $0 /opt/labstacks/testing /var/labstacks/testing --dry-run"
    exit 1
}

# Function to check if a directory exists
check_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo "Error: Directory '$dir' does not exist or is not a directory."
        exit 1
    fi
}

# Function to move a directory and create a symbolic link
move_directory_and_symlink() {
    local dir_path="$1"

    # Check if dir_path is already a symlink
    if [ -L "$dir_path" ]; then
        local existing_target
        existing_target=$(readlink "$dir_path")
        expected_target="$DST_DIR/${dir_path#$SRC_DIR/}"
        if [ "$existing_target" == "$expected_target" ]; then
            echo "Info: Directory '$dir_path' is already a symlink to '$existing_target'. Skipping."
            return
        else
            echo "Warning: Directory '$dir_path' is a symlink to '$existing_target', expected '$expected_target'. Skipping."
            return
        fi
    fi

    # Determine the relative path from SRC_DIR
    rel_path="${dir_path#$SRC_DIR/}"

    # Determine the corresponding path in DST_DIR
    target_path="$DST_DIR/$rel_path"

    # Check if the target path is already a directory
    if [ -d "$target_path" ]; then
        echo "Info: Target directory '$target_path' already exists. Skipping."
        return
    fi

    # Create the target directory's parent if it doesn't exist
    target_dir=$(dirname "$target_path")
    if [ "$DRY_RUN" = true ]; then
        echo "Would create directory '$target_dir' if it doesn't exist."
    else
        mkdir -p "$target_dir"
    fi

    # Move the directory to DST_DIR
    if [ "$DRY_RUN" = true ]; then
        echo "Would move directory '$dir_path' to '$target_path'."
    else
        echo "Moving directory '$dir_path' to '$target_path'..."
        mv "$dir_path" "$target_path"
    fi

    # Create a symbolic link in SRC_DIR pointing to DST_DIR
    if [ "$DRY_RUN" = true ]; then
        echo "Would create symbolic link '$dir_path' -> '$target_path'."
    else
        echo "Creating symbolic link '$dir_path' -> '$target_path'..."
        ln -s "$target_path" "$dir_path"
    fi
}

# Function to move a file and create a symbolic link
move_file_and_symlink() {
    local file_path="$1"

    # Check if file_path is already a symlink
    if [ -L "$file_path" ]; then
        local existing_target
        existing_target=$(readlink "$file_path")
        expected_target="$DST_DIR/${file_path#$SRC_DIR/}"
        if [ "$existing_target" == "$expected_target" ]; then
            echo "Info: File '$file_path' is already a symlink to '$existing_target'. Skipping."
            return
        else
            echo "Warning: File '$file_path' is a symlink to '$existing_target', expected '$expected_target'. Skipping."
            return
        fi
    fi

    # Determine the relative path from SRC_DIR
    rel_path="${file_path#$SRC_DIR/}"

    # Determine the corresponding path in DST_DIR
    target_path="$DST_DIR/$rel_path"

    # Check if the target file already exists
    if [ -e "$target_path" ]; then
        echo "Info: Target file '$target_path' already exists. Skipping."
        return
    fi

    # Create the target directory's parent if it doesn't exist
    target_dir=$(dirname "$target_path")
    if [ "$DRY_RUN" = true ]; then
        echo "Would create directory '$target_dir' if it doesn't exist."
    else
        mkdir -p "$target_dir"
    fi

    # Move the file to DST_DIR
    if [ "$DRY_RUN" = true ]; then
        echo "Would move file '$file_path' to '$target_path'."
    else
        echo "Moving file '$file_path' to '$target_path'..."
        mv "$file_path" "$target_path"
    fi

    # Create a symbolic link in SRC_DIR pointing to DST_DIR
    if [ "$DRY_RUN" = true ]; then
        echo "Would create symbolic link '$file_path' -> '$target_path'."
    else
        echo "Creating symbolic link '$file_path' -> '$target_path'..."
        ln -s "$target_path" "$file_path"
    fi
}

# Function to process directories
process_directories() {
    for dir in "${DIRECTORIES[@]}"; do
        echo "Processing directory: $dir"
        # Find all directories named "$dir" in SRC_DIR excluding hidden directories
        find "$SRC_DIR" \( -type d -name ".*" -prune \) -o -type d -name "$dir" -print0 | while IFS= read -r -d '' found_dir; do
            move_directory_and_symlink "$found_dir"
        done
    done
}

# Function to process files
process_files() {
    for file in "${FILES[@]}"; do
        echo "Processing file: $file"
        # Find all files named "$file" in SRC_DIR excluding hidden directories
        find "$SRC_DIR" \( -type d -name ".*" -prune \) -o -type f -name "$file" -print0 | while IFS= read -r -d '' found_file; do
            move_file_and_symlink "$found_file"
        done
    done
}

# -----------------------------
# Main Script Execution
# -----------------------------

# Initialize DRY_RUN as false
DRY_RUN=false

# Arrays to hold positional arguments
POSITIONAL_ARGS=()

# Parse all arguments
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -*|--*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            POSITIONAL_ARGS+=("$1") # Collect positional arguments
            shift
            ;;
    esac
done

# Check if exactly two positional arguments are provided
if [ "${#POSITIONAL_ARGS[@]}" -ne 2 ]; then
    echo "Error: Invalid number of arguments."
    usage
fi

# Assign positional arguments to variables
SRC_DIR="${POSITIONAL_ARGS[0]}"
DST_DIR="${POSITIONAL_ARGS[1]}"

# Validate source directory
check_directory "$SRC_DIR"

# Create DST_DIR if it doesn't exist
if [ "$DRY_RUN" = true ]; then
    echo "Would create destination directory '$DST_DIR' if it doesn't exist."
else
    mkdir -p "$DST_DIR"
fi

# Export variables and functions for subshells
export SRC_DIR DST_DIR DRY_RUN
export -f move_directory_and_symlink
export -f move_file_and_symlink

echo "Starting processing..."
echo "Source Directory: $SRC_DIR"
echo "Destination Directory: $DST_DIR"
echo "Dry Run: $DRY_RUN"
echo "----------------------------------------"

# Process directories
process_directories

# Process files
process_files

echo "All operations completed successfully."
