#!/bin/bash
# Move Back and Restore Original Structure
  
# Exit immediately if a command exits with a non-zero status.
set -e

# -----------------------------
# Configuration
# -----------------------------

# Array of directories to process
DIRECTORIES=(
    "secrets"
    "appdata"
    "volumes"
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
    echo "  $0 <dst> <src> [--dry-run]"
    echo ""
    echo "Parameters:"
    echo "  <dst>      - Destination directory where symlinks currently exist (e.g., /var/repo)"
    echo "  <src>      - Source directory where actual data resides (e.g., /opt/repo)"
    echo "  --dry-run  - (Optional) Perform a trial run with no changes made"
    echo ""
    echo "Examples:"
    echo "  $0 /var/labstacks/testing /opt/labstacks/testing"
    echo "  $0 /var/labstacks/testing /opt/labstacks/testing --dry-run"
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

# Function to check if a file exists
check_file() {
    local file="$1"
    if [ ! -e "$file" ]; then
        echo "Error: File '$file' does not exist."
        exit 1
    fi
}

# Function to remove a symbolic link and move the directory back
restore_directory() {
    local symlink_path="$1"

    # Check if symlink_path is a symlink
    if [ ! -L "$symlink_path" ]; then
        echo "Warning: '$symlink_path' is not a symbolic link. Skipping."
        return
    fi

    local target_path
    target_path=$(readlink "$symlink_path")

    # Ensure the target path is within SRC_DIR
    if [[ "$target_path" != "$SRC_DIR"* ]]; then
        echo "Warning: Symlink '$symlink_path' does not point to '$SRC_DIR'. Skipping."
        return
    fi

    # Determine the relative path from DST_DIR
    rel_path="${symlink_path#$DST_DIR/}"

    # Determine the corresponding path in SRC_DIR
    original_path="$SRC_DIR/$rel_path"

    # Check if the original path already exists
    if [ -e "$original_path" ]; then
        echo "Info: Original path '$original_path' already exists. Skipping."
        return
    fi

    # Remove the symbolic link
    if [ "$DRY_RUN" = true ]; then
        echo "Would remove symbolic link '$symlink_path'."
    else
        echo "Removing symbolic link '$symlink_path'..."
        rm "$symlink_path"
    fi

    # Move the directory from DST_DIR back to SRC_DIR
    if [ "$DRY_RUN" = true ]; then
        echo "Would move directory '$target_path' to '$original_path'."
    else
        echo "Moving directory '$target_path' to '$original_path'..."
        mv "$target_path" "$original_path"
    fi
}

# Function to remove a symbolic link and move the file back
restore_file() {
    local symlink_path="$1"

    # Check if symlink_path is a symlink
    if [ ! -L "$symlink_path" ]; then
        echo "Warning: '$symlink_path' is not a symbolic link. Skipping."
        return
    fi

    local target_path
    target_path=$(readlink "$symlink_path")

    # Ensure the target path is within SRC_DIR
    if [[ "$target_path" != "$SRC_DIR"* ]]; then
        echo "Warning: Symlink '$symlink_path' does not point to '$SRC_DIR'. Skipping."
        return
    fi

    # Determine the relative path from DST_DIR
    rel_path="${symlink_path#$DST_DIR/}"

    # Determine the corresponding path in SRC_DIR
    original_path="$SRC_DIR/$rel_path"

    # Check if the original file already exists
    if [ -e "$original_path" ]; then
        echo "Info: Original file '$original_path' already exists. Skipping."
        return
    fi

    # Remove the symbolic link
    if [ "$DRY_RUN" = true ]; then
        echo "Would remove symbolic link '$symlink_path'."
    else
        echo "Removing symbolic link '$symlink_path'..."
        rm "$symlink_path"
    fi

    # Move the file from DST_DIR back to SRC_DIR
    if [ "$DRY_RUN" = true ]; then
        echo "Would move file '$target_path' to '$original_path'."
    else
        echo "Moving file '$target_path' to '$original_path'..."
        mv "$target_path" "$original_path"
    fi
}

# Function to restore directories
restore_directories() {
    for dir in "${DIRECTORIES[@]}"; do
        echo "Restoring directory: $dir"
        # Find all symbolic links named "$dir" in DST_DIR excluding hidden directories
        find "$DST_DIR" \( -type d -name ".*" -prune \) -o -type l -name "$dir" -print0 | while IFS= read -r -d '' found_symlink; do
            restore_directory "$found_symlink"
        done
    done
}

# Function to restore files
restore_files() {
    for file in "${FILES[@]}"; do
        echo "Restoring file: $file"
        # Find all symbolic links named "$file" in DST_DIR excluding hidden directories
        find "$DST_DIR" \( -type d -name ".*" -prune \) -o -type l -name "$file" -print0 | while IFS= read -r -d '' found_symlink; do
            restore_file "$found_symlink"
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

# Assign positional arguments to variables (Note the order reversal)
DST_DIR="${POSITIONAL_ARGS[0]}"
SRC_DIR="${POSITIONAL_ARGS[1]}"

# Validate source and destination directories
check_directory "$SRC_DIR"
check_directory "$DST_DIR"

echo "Starting restoration..."
echo "Destination Directory (with symlinks): $DST_DIR"
echo "Source Directory (actual data): $SRC_DIR"
echo "Dry Run: $DRY_RUN"
echo "----------------------------------------"

# Restore directories
restore_directories

# Restore files
restore_files

echo "All restoration operations completed successfully."
