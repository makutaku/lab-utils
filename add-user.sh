#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Check if at least two arguments are provided (username and at least one group)
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <username> <group1,group2,...> [--dry-run]"
  exit 1
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
  run_command "sudo adduser --home \"/home/$USERNAME\" --shell /bin/bash \"$USERNAME\""
  echo "User $USERNAME would be created with a home directory and bash shell."
fi

# Add the user to the provided groups
IFS=',' read -r -a GROUP_ARRAY <<< "$GROUP_LIST"

for group in "${GROUP_ARRAY[@]}"; do
  echo "Attempting to add user $USERNAME to group $group."
  if getent group "$group" >/dev/null; then
    # Group exists, proceed to add the user
    run_command "sudo usermod -aG \"$group\" \"$USERNAME\""
    echo "User $USERNAME would be added to group $group."
  else
    # Group does not exist, output message and do not attempt to add
    echo "Group $group does not exist. Skipping..."
  fi
done

# Display the user details if not in dry-run mode
if [[ "$DRY_RUN" == false ]]; then
  echo "User $USERNAME is in the following groups: $(groups "$USERNAME")"
else
  echo "[Dry run] Displaying groups would happen after user creation and modification."
fi
