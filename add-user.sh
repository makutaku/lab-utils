#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Function to display usage information
usage() {
  echo "Usage: $0 <username> <group1,group2,...> [--dry-run]"
  exit 1
}

# Check if at least two arguments are provided (username and at least one group)
if [[ $# -lt 2 ]]; then
  usage
fi

# Assign arguments to variables
USERNAME="$1"
GROUP_LIST="$2"
DRY_RUN=false

# Check if the --dry-run option is provided
if [[ "$3" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "Dry run mode enabled. No changes will be made."
fi

# Determine if sudo is necessary
if [[ $EUID -ne 0 ]]; then
  if command -v sudo &>/dev/null; then
    SUDO_CMD="sudo"
  else
    echo "Error: sudo is not installed and script is not running as root."
    exit 1
  fi
else
  SUDO_CMD=""
fi

# Function to run a command, or echo it in dry-run mode
run_command() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "[Dry run] $*"
  else
    eval "$@"
  fi
}

# Check if the user already exists
if id "$USERNAME" &>/dev/null; then
  echo "User $USERNAME already exists."
else
  # Create the user with a home directory and bash as the shell
  echo "Adding user \`$USERNAME\` ..."
  run_command "$SUDO_CMD adduser --home \"/home/$USERNAME\" --shell /bin/bash --gecos \"\" --disabled-password \"$USERNAME\""
  
  if [[ "$DRY_RUN" == false ]]; then
    echo "User $USERNAME has been created with a home directory and bash shell."
    
    # Optionally, set a default password (e.g., 'password123')
    # WARNING: Setting default passwords can be a security risk. Consider prompting for a password instead.
    # Uncomment the lines below to set a default password.
    # echo "$USERNAME:password123" | run_command "$SUDO_CMD chpasswd"
    
    echo "User $USERNAME has been created without a password. Please set a password using the \`passwd\` command."
  else
    echo "User $USERNAME would be created with a home directory and bash shell."
  fi
fi

# Add the user to the provided groups
IFS=',' read -r -a GROUP_ARRAY <<< "$GROUP_LIST"

for group in "${GROUP_ARRAY[@]}"; do
  echo "Attempting to add user $USERNAME to group $group."
  if getent group "$group" >/dev/null; then
    # Group exists, proceed to add the user
    run_command "$SUDO_CMD usermod -aG \"$group\" \"$USERNAME\""
    if [[ "$DRY_RUN" == false ]]; then
      echo "User $USERNAME has been added to group $group."
    else
      echo "User $USERNAME would be added to group $group."
    fi
  else
    # Group does not exist, output message and do not attempt to add
    echo "Group '$group' does not exist. Skipping..."
  fi
done

# Display the user details if not in dry-run mode
if [[ "$DRY_RUN" == false ]]; then
  if id "$USERNAME" &>/dev/null; then
    echo "User $USERNAME is in the following groups: $(groups "$USERNAME")"
  else
    echo "User $USERNAME was not created successfully."
  fi
else
  echo "[Dry run] Displaying groups would happen after user creation and modification."
fi
