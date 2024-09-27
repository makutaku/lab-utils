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

# URL to the env-aliases.sh script
ENV_ALIASES_URL="https://raw.githubusercontent.com/makutaku/lab-utils/master/env-aliases.sh"

# Clone the lab-utils repository if it doesn't exist
if [ -d "$LAB_UTILS_DIR" ]; then
    print_message "Updating existing lab-utils repository..."
    sudo -u "$USERNAME" git -C "$LAB_UTILS_DIR" pull
else
    print_message "Cloning lab-utils repository into $LAB_UTILS_DIR..."
    sudo -u "$USERNAME" git clone "$REPO_URL" "$LAB_UTILS_DIR"
fi

# Ensure env-aliases.sh exists
if [ ! -f "$LAB_UTILS_DIR/env-aliases.sh" ]; then
    print_message "Downloading env-aliases.sh..."
    sudo -u "$USERNAME" curl -sL "$ENV_ALIASES_URL" -o "$LAB_UTILS_DIR/env-aliases.sh"
fi

# Backup .bashrc before modifying
BACKUP_BASHRC="$USER_HOME/.bashrc.backup.$(date +%F_%T)"
print_message "Backing up existing .bashrc to $BACKUP_BASHRC"
cp "$BASHRC" "$BACKUP_BASHRC"

# Check if .bashrc already sources env-aliases.sh
SOURCE_LINE="source ~/lab-utils/env-aliases.sh"
if grep -Fxq "$SOURCE_LINE" "$BASHRC"; then
    print_message ".bashrc already sources env-aliases.sh. Skipping append."
else
    print_message "Appending source line to .bashrc..."
    echo "" >> "$BASHRC"
    echo "# Source environment variables and aliases from lab-utils" >> "$BASHRC"
    echo "$SOURCE_LINE" >> "$BASHRC"
fi

# Reload .bashrc for the current user
print_message "Reloading .bashrc..."
# Using su to run source in the user's shell
# Note: Sourcing .bashrc in a subshell won't affect the current shell
# Therefore, inform the user to source it manually
echo "To apply changes immediately, please run:"
echo "    source ~/.bashrc"

print_message "Environment setup complete."
