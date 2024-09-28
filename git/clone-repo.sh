#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name: git_clone_or_update.sh
# Description: Clones a Git repository via SSH into a target directory.
#              If the repository already exists, it updates the repository.
#              If the target directory is not provided, it creates one
#              with the repository's name in the current directory.
#              Additionally, if the target directory exists but is empty,
#              it clones the repository into it.
# Usage: ./git_clone_or_update.sh <git_ssh_url> [target_directory]
# Example:
#   ./git_clone_or_update.sh git@github.com:user/repo.git /path/to/dir
#   ./git_clone_or_update.sh git@github.com:user/repo.git
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display usage instructions
usage() {
    echo "Usage: $0 <git_ssh_url> [target_directory]"
    echo "Example:"
    echo "  $0 git@github.com:user/repo.git /path/to/dir"
    echo "  $0 git@github.com:user/repo.git"
    exit 1
}

# Function to extract repository name from Git SSH URL
extract_repo_name() {
    local url="$1"
    # Remove trailing .git if present
    url="${url%.git}"
    # Extract the part after the last '/'
    repo_name="${url##*/}"
    echo "$repo_name"
}

# Function to clone the repository
clone_repo() {
    echo "Cloning repository from $GIT_SSH_URL into $TARGET_DIR..."
    git clone "$GIT_SSH_URL" "$TARGET_DIR"
    echo "Repository cloned successfully."
}

# Function to update the repository
update_repo() {
    echo "Updating repository in $TARGET_DIR..."
    cd "$TARGET_DIR"

    # Check if the remote URL matches the provided SSH URL
    CURRENT_REMOTE=$(git config --get remote.origin.url)
    if [ "$CURRENT_REMOTE" != "$GIT_SSH_URL" ]; then
        echo "Error: The existing repository's remote URL ($CURRENT_REMOTE) does not match the provided URL ($GIT_SSH_URL)."
        exit 1
    fi

    # Fetch and merge the latest changes
    git pull
    echo "Repository updated successfully."
}

# Function to check if directory is empty
is_directory_empty() {
    local dir="$1"
    if [ -z "$(ls -A "$dir")" ]; then
        return 0    # True: Directory is empty
    else
        return 1    # False: Directory is not empty
    fi
}

# Main logic

# Check if at least one argument is provided
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Error: Invalid number of arguments."
    usage
fi

# Assign input arguments to variables
GIT_SSH_URL="$1"

if [ "$#" -eq 2 ]; then
    TARGET_DIR="$2"
else
    # Extract repository name and set target directory
    REPO_NAME=$(extract_repo_name "$GIT_SSH_URL")
    if [ -z "$REPO_NAME" ]; then
        echo "Error: Unable to extract repository name from URL."
        exit 1
    fi
    TARGET_DIR="./$REPO_NAME"
fi

# Check if the target directory exists
if [ -d "$TARGET_DIR" ]; then
    if [ -d "$TARGET_DIR/.git" ]; then
        echo "Target directory '$TARGET_DIR' already contains a Git repository."
        update_repo
    elif is_directory_empty "$TARGET_DIR"; then
        echo "Target directory '$TARGET_DIR' exists and is empty. Proceeding to clone."
        clone_repo
    else
        echo "Error: Target directory '$TARGET_DIR' exists, is not empty, and is not a Git repository."
        exit 1
    fi
else
    # Create the target directory's parent directories if they don't exist
    mkdir -p "$(dirname "$TARGET_DIR")"
    clone_repo
fi

