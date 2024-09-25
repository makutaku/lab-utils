#!/bin/bash

# Exit immediately if a command exits with a non-zero status,
# Treat unset variables as an error, and
# Fail on any command in a pipeline that fails
set -euo pipefail

# Function to log messages with timestamp
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Function to display usage
usage() {
  echo "Usage: $0 [-o owner] [-r repo] [-b branch] [-s script_path]"
  echo "  -o OWNER       GitHub repository owner (default: makutaku)"
  echo "  -r REPO        GitHub repository name (default: labstacks)"
  echo "  -b BRANCH      GitHub branch name (default: master)"
  echo "  -s SCRIPT_PATH Path to the script within the repository (default: scripts/deploy.sh)"
  echo "  -h             Show this help message"
  exit 1
}

# Function to clean up temporary files
cleanup() {
  if [[ -n "${TEMP_SCRIPT:-}" && -f "$TEMP_SCRIPT" ]]; then
    rm -f "$TEMP_SCRIPT"
    log "Cleaned up temporary script."
  fi
}
trap cleanup EXIT

# Parse options
while getopts ":o:r:b:s:h" opt; do
  case ${opt} in
    o )
      OWNER=$OPTARG
      ;;
    r )
      REPO=$OPTARG
      ;;
    b )
      BRANCH=$OPTARG
      ;;
    s )
      SCRIPT_PATH=$OPTARG
      ;;
    h )
      usage
      ;;
    \? )
      echo "Invalid Option: -$OPTARG" 1>&2
      usage
      ;;
    : )
      echo "Invalid Option: -$OPTARG requires an argument" 1>&2
      usage
      ;;
  esac
done
shift $((OPTIND -1))

# Set default values if not set
OWNER="${OWNER:-makutaku}"
REPO="${REPO:-labstacks}"
BRANCH="${BRANCH:-master}"
SCRIPT_PATH="${SCRIPT_PATH:-scripts/deploy.sh}"

# Ensure GITHUB_PAT is set
if [[ -z "${GITHUB_PAT:-}" ]]; then
  log "Error: GITHUB_PAT environment variable is not set."
  exit 1
fi

# API URL to fetch the raw script
API_URL="https://api.github.com/repos/$OWNER/$REPO/contents/$SCRIPT_PATH?ref=$BRANCH"

# Create a temporary file for the script
TEMP_SCRIPT=$(mktemp /tmp/deploy.sh.XXXXXX)

# Download the script with retries
log "Downloading script from $API_URL..."
HTTP_RESPONSE=$(curl --retry 3 --retry-delay 5 -s -w "HTTPSTATUS:%{http_code}" -H "Authorization: token $GITHUB_PAT" \
     -H "Accept: application/vnd.github.v3.raw" \
     "$API_URL")

# Extract the body and status
HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed -e 's/HTTPSTATUS\:.*//g')
HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

# Check if the request was successful
if [[ "$HTTP_STATUS" -ne 200 ]]; then
  log "Error: Failed to download the script. HTTP status: $HTTP_STATUS"
  exit 1
fi

# Save the script to the temporary file
echo "$HTTP_BODY" > "$TEMP_SCRIPT"

# Make the script executable
chmod +x "$TEMP_SCRIPT"
log "Script downloaded and made executable."

# Execute the script
log "Executing the script..."
"$TEMP_SCRIPT"

log "Script executed successfully."
