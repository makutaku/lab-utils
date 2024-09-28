#!/bin/bash

# ===== init-user-env.sh =====
# This script sets up the user environment by cloning the lab-utils repository,
# appending environment variables and aliases to .bashrc, and reloading .bashrc.

# Exit immediately if a command exits with a non-zero status
set -e

# Function to print messages
print_message() {
    echo "========================================"
    echo "$1"
    echo "========================================"
}

# Detect the non-root user who invoked sudo
if [ "$SUDO_USER" ]; then
    USERNAME="$SUDO_USER"
    USER_HOME=$(eval echo "~$USERNAME")
else
    # If not run with sudo, assume current user
    USERNAME=$(whoami)
    USER_HOME="$HOME"
fi

# Path to the user's .bashrc
BASHRC="$USER_HOME/.bashrc"

# Path to the lab-utils repository
LAB_UTILS_DIR="$USER_HOME/lab-utils"

# Git repository URL
REPO_URL="https://github.com/makutaku/lab-utils.git"

# Function to clone or update the lab-utils repository
clone_or_update_repo() {
    if [ -d "$LAB_UTILS_DIR/.git" ]; then
        print_message "Updating existing lab-utils repository..."
        sudo -u "$USERNAME" git -C "$LAB_UTILS_DIR" pull
    else
        print_message "Cloning lab-utils repository into $LAB_UTILS_DIR..."
        sudo -u "$USERNAME" git clone "$REPO_URL" "$LAB_UTILS_DIR"
    fi
}

# Function to verify the presence of env-aliases.sh
verify_env_aliases() {
    ENV_ALIASES_FILE="$LAB_UTILS_DIR/env-aliases.sh"
    if [ ! -f "$ENV_ALIASES_FILE" ]; then
        echo "Error: env-aliases.sh not found in $LAB_UTILS_DIR."
        echo "Please ensure the lab-utils repository contains env-aliases.sh."
        exit 1
    fi
}

# Function to backup .bashrc
backup_bashrc() {
    BACKUP_BASHRC="$USER_HOME/.bashrc.backup.$(date +%F_%T)"
    print_message "Backing up existing .bashrc to $BACKUP_BASHRC"
    cp "$BASHRC" "$BACKUP_BASHRC"
}

# Function to append source line to .bashrc
append_source_line() {
    SOURCE_LINE="source ~/lab-utils/env-aliases.sh"
    if grep -Fxq "$SOURCE_LINE" "$BASHRC"; then
        print_message ".bashrc already sources env-aliases.sh. Skipping append."
    else
        print_message "Appending source line to .bashrc..."
        {
            echo ""
            echo "# Source environment variables and aliases from lab-utils"
            echo "$SOURCE_LINE"
        } >> "$BASHRC"
    fi
}

# Function to reload .bashrc
reload_bashrc() {
    print_message "Reloading .bashrc..."
    # Inform the user to manually source .bashrc since this script runs in a subshell
    echo "To apply changes immediately, please run:"
    echo "    source ~/.bashrc"
}

# Main Execution Flow
clone_or_update_repo
verify_env_aliases
backup_bashrc
append_source_line
reload_bashrc

print_message "Environment setup complete."
