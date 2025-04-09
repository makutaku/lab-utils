#!/bin/bash

# Check if a list of usernames was provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <username1,username2,...> [group_name] [group_gid]"
    exit 1
fi

# Assign arguments to variables with default values
user_list="$1"
group_name="${2:-lxc_shares}"
group_gid="${3:-10000}"

# Check if the group already exists, if not, create it
if ! getent group "$group_name" > /dev/null 2>&1; then
    echo "Group $group_name does not exist. Creating group with GID $group_gid..."
    groupadd -g "$group_gid" "$group_name"
    echo "Group $group_name created with GID $group_gid."
else
    echo "Group $group_name already exists."
fi

# Iterate over the comma-separated list of users
IFS=',' read -ra users <<< "$user_list"
for user_name in "${users[@]}"; do
    # Check if the user already belongs to the group
    if id -nG "$user_name" | grep -qw "$group_name"; then
        echo "User $user_name is already a member of group $group_name."
    else
        # Add the user to the group
        usermod -aG "$group_name" "$user_name"
        echo "User $user_name added to group $group_name."
    fi
done
