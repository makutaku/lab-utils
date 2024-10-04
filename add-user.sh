#!/bin/bash

# Check if at least two arguments are provided (username and at least one group)
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <username> <group1,group2,...>"
  exit 1
fi

# Assign arguments to variables
USERNAME=$1
GROUPS=$2

# Check if the user already exists
if id "$USERNAME" &>/dev/null; then
  echo "User $USERNAME already exists."
else
  # Create the user with a home directory and bash as the shell
  sudo adduser --home "/home/$USERNAME" --shell /bin/bash "$USERNAME"
  echo "User $USERNAME created with a home directory and bash shell."
fi

# Add the user to the provided groups
IFS=',' read -ra GROUP_ARRAY <<< "$GROUPS"
for group in "${GROUP_ARRAY[@]}"; do
  if getent group "$group" >/dev/null; then
    sudo usermod -aG "$group" "$USERNAME"
    echo "User $USERNAME added to group $group."
  else
    echo "Group $group does not exist."
  fi
done

# Display the user details
echo "User $USERNAME is in the following groups: $(groups $USERNAME)"
