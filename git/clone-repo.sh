#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name: clone-repo.sh
# Description: Clones a Git repository via SSH into a target directory.
#              Supports cloning using either the full Git SSH URL or just the
#              repository name, provided a base SSH URL is defined.
#              If the repository already exists, it updates the repository.
#              If the target directory is not provided, it creates one
#              with the repository's name in the current directory.
#              If the target directory exists and is empty, it clones into it.
# Usage:
#   ./clone-repo.sh <git_ssh_url|repo_name> [target_directory]
# Examples:
#   ./clone-repo.sh git@github.com:makutaku/labstacks.git /opt/labstacks
#   ./clone-repo.sh labstacks /opt/
#   ./clone-repo.sh git@github.com:makutaku/labstacks.git
#   ./clone-repo.sh labstacks
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status
set -e

# Configuration: Define the base SSH URL for repositories
# Modify this variable if your repositories are hosted elsewhere or under a different user/org
GIT_BASE_SSH_URL="git@github.com:makutaku/"

# Function to display usage instructions
usage() {
    echo "Usage: $0 <git_ssh_url|repo_name> [target_directory]"
    echo "Examples:"
    echo "  $0 git@github.com:makutaku/labstacks.git /opt/labstacks"
    echo "  $0 labstacks /opt/"
    echo "  $0 git@github.com:makutaku/labstacks.git"
    echo "  $0 labstacks"
    exit 1
}

# Function to extract repository name from Git SSH URL or use the provided repo name
get_repo_name() {
    local input="$1"
    if [[ "$input" == git@*:*/*.git ]]; then
        # Input is a full SSH URL
        # Remove trailing .git if present
        input="${input%.git}"
        # Extract the part after the last '/'
        repo_name="${input##*/}"
    else
        # Input is assumed to be a repo name
        repo_name="$input"
    fi
    echo "$repo_name"
}

# Function to construct the full Git SSH URL from the repo name
construct_git_ssh_url() {
    local repo="$1"
    echo "${GIT_BASE_SSH_URL}${repo}.git"
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

# Function to check if a directory is empty
is_directory_empty() {
    local dir="$1"
    if [ -z "$(ls -A "$dir")" ]; then
        return 0    # True: Directory is empty
    else
        return 1    # False: Directory is not empty
    fi
}

# Function to determine if the input is a valid SSH URL
is_valid_ssh_url() {
    local url="$1"
    # Simple regex to check if the input starts with git@ and contains a colon and a slash
    if [[ "$url" =~ ^git@[^:]+:[^/]+/.+\.git$ ]]; then
        return 0
    else
        return 1
    fi
}

# Main logic

# Check if help is requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

# Check if at least one argument is provided
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Error: Invalid number of arguments."
    usage
fi

# Determine if the first argument is a full SSH URL or a repo name
if is_valid_ssh_url "$1"; then
    GIT_SSH_URL="$1"
    REPO_NAME=$(get_repo_name "$1")
else
    REPO_NAME=$(get_repo_name "$1")
    GIT_SSH_URL=$(construct_git_ssh_url "$REPO_NAME")
fi

# Assign target directory
if [ "$#" -eq 2 ]; then
    TARGET_DIR="$2"
else
    # If target directory is not provided, default to ./repo_name
    TARGET_DIR="./$REPO_NAME"
fi

# If target directory ends with a slash, treat it as a parent directory
if [[ "$TARGET_DIR" == */ ]]; then
    TARGET_DIR="${TARGET_DIR}${REPO_NAME}"
    echo "Target directory was treated as a parent directory. Updated target to '$TARGET_DIR'."
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

