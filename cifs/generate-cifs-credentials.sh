#!/bin/bash

# Script to generate a CIFS (SMB) credentials file with secure permissions.

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display usage information
usage() {
    cat <<EOF
Usage: $0 --username <username> --password <password> [--file <credentials_file>] [--help]

Arguments:
  --username, -u      The username for SMB/CIFS authentication.
  --password, -p      The password for SMB/CIFS authentication.
  --file, -f          (Optional) The path to the credentials file.
                      Defaults to /root/.harvester-smb-credentials
  --help, -h          Display this help and exit.

Example:
  sudo ./generate_cifs_credentials.sh --username alice --password 's3cr3tP@ss'
  sudo ./generate_cifs_credentials.sh -u alice -p 's3cr3tP@ss' -f /root/.custom-credentials
EOF
    exit 1
}

# Function to display informational messages
echo_info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

# Function to display success messages
echo_success() {
    echo -e "\e[32m[SUCCESS]\e[0m $1"
}

# Function to display error messages
echo_error() {
    echo -e "\e[31m[ERROR]\e[0m $1" >&2
}

# Function to check if a string is non-empty
is_non_empty() {
    [[ -n "$1" ]]
}

# Parse named arguments using getopt
PARSED_ARGS=$(getopt -o u:p:f:h --long username:,password:,file:,help -n "$0" -- "$@")
if [[ $? -ne 0 ]]; then
    echo_error "Failed to parse arguments."
    usage
fi

eval set -- "$PARSED_ARGS"

# Initialize variables
USERNAME=""
PASSWORD=""
CREDENTIALS_FILE="/root/.harvester-smb-credentials"

# Extract options and their arguments into variables
while true; do
    case "$1" in
        --username|-u)
            USERNAME="$2"
            shift 2
            ;;
        --password|-p)
            PASSWORD="$2"
            shift 2
            ;;
        --file|-f)
            CREDENTIALS_FILE="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        --)
            shift
            break
            ;;
        *)
            echo_error "Unexpected option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
    echo_error "Missing required arguments: --username and/or --password."
    usage
fi

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo_error "This script must be run as root. Use sudo."
    exit 1
fi

# Check if the credentials file already exists
if [[ -f "$CREDENTIALS_FILE" ]]; then
    echo_info "Credentials file '$CREDENTIALS_FILE' already exists."
    read -p "Do you want to overwrite it? (y/N): " CONFIRM
    case "$CONFIRM" in
        [yY][eE][sS]|[yY])
            echo_info "Overwriting the existing credentials file."
            ;;
        *)
            echo_info "Aborting. The credentials file was not modified."
            exit 0
            ;;
    esac
fi

# Create the credentials file with the provided username and password
echo_info "Creating credentials file at '$CREDENTIALS_FILE'..."
{
    echo "username=$USERNAME"
    echo "password=$PASSWORD"
} > "$CREDENTIALS_FILE"

# Set the permissions to 600 to restrict access
chmod 600 "$CREDENTIALS_FILE"
echo_success "Credentials file '$CREDENTIALS_FILE' created with secure permissions."

exit 0
