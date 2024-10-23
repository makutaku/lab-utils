#!/bin/bash

set -e

# Function to display usage information
usage() {
  echo "Usage: $0 --url <URL> [OPTIONS]" >&2
  echo
  echo "Required argument:" >&2
  echo "  --url <URL>            The URL of the file to download." >&2
  echo
  echo "Optional arguments:" >&2
  echo "  --hash <HASH>          The expected hash value of the file." >&2
  echo "  --filename <FILENAME>  The name to save the downloaded file as." >&2
  echo "  --dst <DIRECTORY>      The directory to download the file into." >&2
  echo "  --destination <DIR>    Same as --dst; specify the destination directory." >&2
  echo "  --overwrite            Overwrite the file if it already exists." >&2
  echo "  --dry_run              Show what would be done without making any changes." >&2
  echo "  --help                 Display this help message and exit." >&2
  echo
  echo "If neither --dst nor --destination is specified, the current directory is used." >&2
  echo
  echo "Example:" >&2
  echo "  $0 --url https://example.com/file.iso --dst /tmp --overwrite" >&2
  exit 1
}

# Function to detect hash type based on hash length
detect_hash_type() {
  local hash="$1"
  local length="${#hash}"

  case "$length" in
    64)
      echo "sha256";;
    40)
      echo "sha1";;
    32)
      echo "md5";;
    *)
      echo "Unknown hash type for hash length $length" >&2
      exit 1;;
  esac
}

# Function to compute hash
compute_hash() {
  local file="$1"
  local hash_type="$2"

  case "$hash_type" in
    sha256)
      sha256sum "$file" | awk '{print $1}';;
    sha1)
      sha1sum "$file" | awk '{print $1}';;
    md5)
      md5sum "$file" | awk '{print $1}';;
    *)
      echo "Unsupported hash type: $hash_type" >&2
      exit 1;;
  esac
}

# Parse options
OPTS=$(getopt -o '' -l 'url:,hash:,filename:,dst:,destination:,overwrite,dry_run,help' -- "$@")
if [ $? != 0 ]; then
  echo "Error: Invalid arguments." >&2
  usage
fi

eval set -- "$OPTS"

# Initialize variables
URL=""
HASH=""
FILENAME=""
DST=""
OVERWRITE=0
DRY_RUN=0

while true; do
  case "$1" in
    --url )
      URL="$2"; shift 2;;
    --hash )
      HASH="$2"; shift 2;;
    --filename )
      FILENAME="$2"; shift 2;;
    --dst | --destination )
      DST="$2"; shift 2;;
    --overwrite )
      OVERWRITE=1; shift;;
    --dry_run )
      DRY_RUN=1; shift;;
    --help )
      usage;;
    -- )
      shift; break;;
    * )
      echo "Error: Invalid argument '$1'" >&2
      usage;;
  esac
done

# Check if URL is provided
if [ -z "$URL" ]; then
  echo "Error: --url argument is required." >&2
  usage
fi

# Set default directory to current directory if not specified
if [ -z "$DST" ]; then
  DST="."
fi

# Determine the filename
if [ -z "$FILENAME" ]; then
  # Extract filename from URL
  FILENAME="${URL##*/}"
  # If URL ends with '/', set default filename
  if [ -z "$FILENAME" ]; then
    FILENAME="downloaded_file"
  fi
fi

# Full path to the output file
FILEPATH="$DST/$FILENAME"

# Initialize DOWNLOAD and VALIDATED variables
DOWNLOAD=0
VALIDATED=0

# If HASH is not provided, try to get it from the same site
if [ -z "$HASH" ]; then
  # Try to get the hash from SHA256SUMS
  BASEURL="${URL%/*}/"
  SHA256SUMS_URL="${BASEURL}SHA256SUMS"
  TMP_SHA256SUMS_FILE=$(mktemp)

  echo "No hash provided. Trying to download SHA256SUMS from $SHA256SUMS_URL" >&2
  if curl -sSL "$SHA256SUMS_URL" -o "$TMP_SHA256SUMS_FILE"; then
    # Search for our file in SHA256SUMS
    HASH=$(grep "$(basename "$FILENAME")" "$TMP_SHA256SUMS_FILE" | awk '{print $1}')
    if [ -z "$HASH" ]; then
      echo "Error: Could not find hash for $(basename "$FILENAME") in SHA256SUMS" >&2
      rm -f "$TMP_SHA256SUMS_FILE"
      exit 1
    fi
    HASH_TYPE="sha256"
    rm -f "$TMP_SHA256SUMS_FILE"
  else
    echo "Error: Could not download SHA256SUMS from $SHA256SUMS_URL" >&2
    rm -f "$TMP_SHA256SUMS_FILE"
    exit 1
  fi
else
  # Detect hash type
  HASH_TYPE=$(detect_hash_type "$HASH")
fi

# Check if file exists
if [ -f "$FILEPATH" ]; then
  echo "File $FILEPATH already exists." >&2
  # Compute hash and compare
  FILE_HASH=$(compute_hash "$FILEPATH" "$HASH_TYPE")
  if [ "$FILE_HASH" == "$HASH" ]; then
    echo "Existing file matches the hash. Skipping download and validation." >&2
    VALIDATED=1
  else
    echo "Existing file does not match the hash." >&2
    if [ "$OVERWRITE" -eq 1 ]; then
      echo "Overwriting the file." >&2
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "Dry run: Would delete existing file $FILEPATH" >&2
      else
        rm -f "$FILEPATH"
      fi
      DOWNLOAD=1
    else
      echo "Use --overwrite to overwrite the existing file." >&2
      exit 1
    fi
  fi
else
  DOWNLOAD=1
fi

# Download the file if necessary
if [ "$DOWNLOAD" -eq 1 ]; then
  echo "Downloading file from $URL to $FILEPATH" >&2
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry run: Would download $URL to $FILEPATH" >&2
  else
    mkdir -p "$DST"
    if ! curl -L "$URL" -o "$FILEPATH"; then
      echo "Error: Download failed." >&2
      exit 1
    fi
  fi
fi

# Validate the file if not already validated
if [ "$VALIDATED" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
  echo "Validating the file..." >&2
  FILE_HASH=$(compute_hash "$FILEPATH" "$HASH_TYPE")
  if [ "$FILE_HASH" == "$HASH" ]; then
    echo "File hash matches." >&2
  else
    echo "Error: File hash does not match." >&2
    exit 1
  fi
elif [ "$VALIDATED" -eq 0 ] && [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run: Would validate the file $FILEPATH" >&2
fi

# Save the hash to a file
HASH_FILE="$FILEPATH.$HASH_TYPE"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run: Would save hash to $HASH_FILE" >&2
else
  echo "$HASH  $(basename "$FILEPATH")" > "$HASH_FILE"
  echo "Saved hash to $HASH_FILE" >&2
fi

# Output the full path to stdout for piping
echo "$FILEPATH"

echo "Done." >&2
