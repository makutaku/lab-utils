#!/bin/bash

# process_img.sh
# Script to process IMG files by copying to a temporary working directory,
# validating hashes, ensuring idempotency, converting to QCOW2 format,
# managing hashes for reliable processing, and cleaning up.

set -euo pipefail

# ----------------------------
# Constants
# ----------------------------
PREFIX="ak_"

# ----------------------------
# Function Definitions
# ----------------------------

# Function to display error messages and exit
error_exit() {
  echo "Error: $1" >&2
  exit 1
}

# Function to display usage information
usage() {
  echo "Usage: $0 [OPTIONS] <path_to_img_file>" >&2
  echo
  echo "Options:" >&2
  echo "  --temp-dir <DIRECTORY>   Specify the temporary working directory for processing the IMG file." >&2
  echo "  --output-dir <DIRECTORY> Specify the directory to place the final QCOW2 file and its hash." >&2
  echo "  --overwrite              Overwrite existing QCOW2 files and hashes in the output directory." >&2
  echo "  --script <SCRIPT>        Specify the customization script to run. Defaults to ./customize_img.sh." >&2
  echo "  --help                   Display this help message and exit." >&2
  echo
  echo "If --temp-dir is not specified, a temporary directory is used." >&2
  echo "If --output-dir is not specified, the default './output' directory is used." >&2
  echo "If --script is not specified, './customize_img.sh' is used." >&2
  echo
  echo "Examples:" >&2
  echo "  $0 --temp-dir ./tmp --output-dir ./output /path/to/image.img" >&2
  echo "  $0 --output-dir ./output --overwrite /path/to/image.img" >&2
  echo "  $0 /path/to/image.img" >&2
  echo "  $0 --temp-dir ./tmp --script /path/to/customize_img_noop.sh /path/to/image.img" >&2
  exit 1
}

# Function to parse command-line arguments
parse_arguments() {
  # Initialize variables
  TEMP_DIR=""
  OUTPUT_DIR="./output"
  OVERWRITE=false
  IMG_FILE=""
  SCRIPT="./customize_img.sh"

  # Check if no arguments were provided
  if [[ $# -lt 1 ]]; then
    echo "Error: No arguments provided." >&2
    usage
  fi

  # Parse named arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --temp-dir)
        if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
          TEMP_DIR="$2"
          shift 2
        else
          error_exit "Argument for $1 is missing."
        fi
        ;;
      --output-dir)
        if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
          OUTPUT_DIR="$2"
          shift 2
        else
          error_exit "Argument for $1 is missing."
        fi
        ;;
      --overwrite)
        OVERWRITE=true
        shift
        ;;
      --script)
        if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
          SCRIPT="$2"
          shift 2
        else
          error_exit "Argument for $1 is missing."
        fi
        ;;
      --help)
        usage
        ;;
      -*)
        error_exit "Unknown option: $1"
        ;;
      *)
        # Assume the first non-option argument is the IMG file path
        if [[ -z "$IMG_FILE" ]]; then
          IMG_FILE="$1"
          shift
        else
          error_exit "Multiple IMG file paths provided. Only one is allowed."
        fi
        ;;
    esac
  done

  # Check if IMG_FILE is set
  if [[ -z "$IMG_FILE" ]]; then
    error_exit "Path to IMG file is not provided."
  fi

  # Check if customization script exists and is executable
  if [[ ! -x "$SCRIPT" ]]; then
    error_exit "Customization script '$SCRIPT' does not exist or is not executable."
  fi

  # Export variables for use in other functions and external scripts
  export TEMP_DIR
  export OUTPUT_DIR
  export OVERWRITE
  export IMG_FILE
  export SCRIPT
}

# Function to extract the hash from a hash file
get_hash_from_file() {
  local hash_file="$1"
  
  if [[ ! -f "$hash_file" ]]; then
    error_exit "Hash file '$hash_file' does not exist."
  fi

  # Extract only the first field (hash), ignoring any additional tokens
  local hash
  hash=$(awk '{print $1}' "$hash_file")

  # Validate that the extracted hash is a valid SHA256 hash (64 hex characters)
  if [[ ! "$hash" =~ ^[a-fA-F0-9]{64}$ ]]; then
    error_exit "Invalid hash format in '$hash_file'. Expected a 64-character hexadecimal SHA256 hash."
  fi

  echo "$hash"
}

# Function to validate the source IMG
validate_source_img() {
  SOURCE_HASH_FILE="${IMG_FILE}.sha256"

  if [[ -f "$SOURCE_HASH_FILE" ]]; then
    STORED_SOURCE_HASH="$(get_hash_from_file "$SOURCE_HASH_FILE")"
    COMPUTED_SOURCE_HASH="$(sha256sum "$IMG_FILE" | awk '{print $1}')"

    if [[ "$COMPUTED_SOURCE_HASH" != "$STORED_SOURCE_HASH" ]]; then
      error_exit "Source IMG hash mismatch. Expected: $STORED_SOURCE_HASH, Found: $COMPUTED_SOURCE_HASH."
    fi
  else
    echo "Warning: No hash file found for source IMG ('$SOURCE_HASH_FILE'). Proceeding without hash validation." >&2
    COMPUTED_SOURCE_HASH="$(sha256sum "$IMG_FILE" | awk '{print $1}')"
  fi
}

# Function to ensure idempotency
ensure_idempotency() {
  FINAL_QCOW2_FILE="${PREFIX}$(basename "${IMG_FILE%.img}.img")"
  FINAL_QCOW2_PATH="$OUTPUT_DIR/$FINAL_QCOW2_FILE"
  FINAL_QCOW2_HASH_FILE="${FINAL_QCOW2_PATH}.sha256"
  FINAL_SOURCE_HASH_FILE="$OUTPUT_DIR/${PREFIX}$(basename "${IMG_FILE%.img}").orig.img.sha256"

  if [[ -f "$FINAL_SOURCE_HASH_FILE" ]]; then
    STORED_OUTPUT_SOURCE_HASH="$(get_hash_from_file "$FINAL_SOURCE_HASH_FILE")"

    if [[ "$COMPUTED_SOURCE_HASH" == "$STORED_OUTPUT_SOURCE_HASH" ]]; then
      if [[ -f "$FINAL_QCOW2_PATH" && -f "$FINAL_QCOW2_HASH_FILE" ]]; then
        STORED_FINAL_HASH="$(get_hash_from_file "$FINAL_QCOW2_HASH_FILE")"
        COMPUTED_FINAL_HASH="$(sha256sum "$FINAL_QCOW2_PATH" | awk '{print $1}')"

        if [[ "$STORED_FINAL_HASH" == "$COMPUTED_FINAL_HASH" ]]; then
          echo "$FINAL_QCOW2_PATH"
          return 0  # Idempotency confirmed
        else
          echo "Warning: Final QCOW2 hash mismatch. Reprocessing..." >&2
        fi
      else
        echo "Warning: Final QCOW2 file or its hash does not exist. Reprocessing..." >&2
      fi
    else
      echo "Warning: Output directory hash does not match source IMG hash. Reprocessing..." >&2
    fi
  else
    echo "No existing hash file in output directory. Proceeding with processing." >&2
  fi

  return 1  # Need to process
}

# Function to prepare the output destination
prepare_destination() {
  # Ensure the output directory exists
  if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "Output directory '$OUTPUT_DIR' does not exist. Creating it..." >&2
    mkdir -p "$OUTPUT_DIR" || error_exit "Failed to create output directory '$OUTPUT_DIR'."
  fi

  if [[ -f "$OUTPUT_DIR/$FINAL_QCOW2_FILE" ]]; then
    if [[ "$OVERWRITE" == true ]]; then
      echo "Warning: Overwriting existing QCOW2 file '$FINAL_QCOW2_PATH'." >&2
      # Move using pv: Copy with progress, then delete source
      echo "Moving QCOW2 file with progress..." >&2
      pv "$OUTPUT_DIR/$FINAL_QCOW2_FILE" > "$OUTPUT_DIR/${FINAL_QCOW2_FILE}.tmp" || error_exit "Failed to copy QCOW2 file."
      mv "$OUTPUT_DIR/${FINAL_QCOW2_FILE}.tmp" "$FINAL_QCOW2_PATH" || error_exit "Failed to rename temporary QCOW2 file."
      rm -f "$OUTPUT_DIR/$FINAL_QCOW2_FILE" || error_exit "Failed to remove existing QCOW2 file '$FINAL_QCOW2_PATH'."

      if [[ -f "$FINAL_QCOW2_HASH_FILE" ]]; then
        echo "Removing existing QCOW2 hash file '$FINAL_QCOW2_HASH_FILE'." >&2
        rm -f "$FINAL_QCOW2_HASH_FILE" || error_exit "Failed to remove existing QCOW2 hash file '$FINAL_QCOW2_HASH_FILE'."
      fi
    else
      error_exit "Final QCOW2 file '$FINAL_QCOW2_PATH' already exists. Use --overwrite to replace it."
    fi
  fi

  # Clean up any dangling hash files in output directory
  if [[ -f "$FINAL_SOURCE_HASH_FILE" ]]; then
    echo "Removing existing source hash file '$FINAL_SOURCE_HASH_FILE' from output directory." >&2
    rm -f "$FINAL_SOURCE_HASH_FILE" || error_exit "Failed to remove '$FINAL_SOURCE_HASH_FILE'."
  fi

  if [[ -f "$FINAL_QCOW2_HASH_FILE" ]]; then
    echo "Removing existing QCOW2 hash file '$FINAL_QCOW2_HASH_FILE' from output directory." >&2
    rm -f "$FINAL_QCOW2_HASH_FILE" || error_exit "Failed to remove '$FINAL_QCOW2_HASH_FILE'."
  fi
}

# Function to prepare the working directory
prepare_working_directory() {
  # Set up the temporary working directory
  if [[ -n "$TEMP_DIR" ]]; then
    # If temporary directory is specified, ensure it exists or create it
    if [[ ! -d "$TEMP_DIR" ]]; then
      echo "Temporary working directory '$TEMP_DIR' does not exist. Creating it..." >&2
      mkdir -p "$TEMP_DIR" || error_exit "Failed to create temporary working directory '$TEMP_DIR'."
    fi
  else
    # Create a temporary working directory
    TEMP_DIR=$(mktemp -d -t process_img_temp_XXXXXX)
    echo "No temporary working directory specified. Using temporary directory '$TEMP_DIR'." >&2
  fi

  # Prefixed working IMG file with renamed extension to .orig.img
  WORKING_IMG_FILE="$TEMP_DIR/${PREFIX}$(basename "${IMG_FILE%.img}.orig.img")"

  if [[ -f "$WORKING_IMG_FILE" ]]; then
    WORKING_IMG_HASH="$(sha256sum "$WORKING_IMG_FILE" | awk '{print $1}')"

    if [[ "$WORKING_IMG_HASH" == "$COMPUTED_SOURCE_HASH" ]]; then
      echo "Working IMG file already exists and matches the source hash. Skipping copy." >&2
      return 0  # Correct IMG already in working directory
    else
      echo "Warning: Existing IMG file in working directory does not match source hash. Deleting it..." >&2
      rm -f "$WORKING_IMG_FILE" || error_exit "Failed to remove mismatched IMG file '$WORKING_IMG_FILE'."
    fi
  fi

  # Copy the IMG file to the working directory with prefix and renamed extension using pv
  echo "Copying IMG file to working directory with prefix and renamed extension..." >&2
  pv "$IMG_FILE" > "$WORKING_IMG_FILE" || error_exit "Failed to copy '$IMG_FILE' to '$WORKING_IMG_FILE'."

  # Validate the copied IMG file
  COPIED_IMG_HASH="$(sha256sum "$WORKING_IMG_FILE" | awk '{print $1}')"
  if [[ "$COPIED_IMG_HASH" != "$COMPUTED_SOURCE_HASH" ]]; then
    error_exit "Hash mismatch after copying IMG file. Expected: $COMPUTED_SOURCE_HASH, Found: $COPIED_IMG_HASH."
  fi
  echo "Copied IMG file validated successfully." >&2
}

# Function to transform IMG to QCOW2
transform_to_qcow2() {
  # Name the QCOW2 file with the prefix
  PREF_QCOW2_WORKING_FILE="$TEMP_DIR/${PREFIX}$(basename "${IMG_FILE%.img}.img")"

  # Convert IMG to QCOW2 format with prefixed name and show progress
  echo "Converting IMG to QCOW2 format..." >&2
  qemu-img convert -p -f raw -O qcow2 "$WORKING_IMG_FILE" "$PREF_QCOW2_WORKING_FILE" || error_exit "Failed to convert IMG to QCOW2 format."

  echo "Conversion to QCOW2 format completed successfully." >&2

  # Compute hash of QCOW2 file
  QCOW2_HASH="$(sha256sum "$PREF_QCOW2_WORKING_FILE" | awk '{print $1}')"
  QCOW2_HASH_FILE="$TEMP_DIR/$(basename "$PREF_QCOW2_WORKING_FILE").sha256"

  echo "Saving QCOW2 hash to '$QCOW2_HASH_FILE'..." >&2
  echo "$QCOW2_HASH" > "$QCOW2_HASH_FILE" || error_exit "Failed to write QCOW2 hash to '$QCOW2_HASH_FILE'."

  # Write original IMG hash to a file in working directory, following IMG file name with prefix and .orig.img.sha256
  ORIGINAL_HASH_FILE="$TEMP_DIR/$(basename "$WORKING_IMG_FILE").sha256"
  echo "Saving original IMG hash to '$ORIGINAL_HASH_FILE'..." >&2
  echo "$COMPUTED_SOURCE_HASH" > "$ORIGINAL_HASH_FILE" || error_exit "Failed to write original IMG hash to '$ORIGINAL_HASH_FILE'."

  echo "Transformation to QCOW2 completed successfully." >&2
}

# Function to publish the final QCOW2 and hash files to the output directory
publish_result() {
  FINAL_QCOW2_PATH="$OUTPUT_DIR/$(basename "$PREF_QCOW2_WORKING_FILE")"
  FINAL_QCOW2_HASH_FILE="$OUTPUT_DIR/$(basename "$QCOW2_HASH_FILE")"
  FINAL_SOURCE_HASH_FILE="$OUTPUT_DIR/${PREFIX}$(basename "${IMG_FILE%.img}").orig.img.sha256"

  # Move QCOW2 file using pv: Copy with progress, then delete source
  echo "Moving QCOW2 file to output directory..." >&2
  pv "$PREF_QCOW2_WORKING_FILE" > "$FINAL_QCOW2_PATH" || error_exit "Failed to copy QCOW2 file to output directory."
  rm -f "$PREF_QCOW2_WORKING_FILE" || error_exit "Failed to remove source QCOW2 file '$PREF_QCOW2_WORKING_FILE'."

  # Move QCOW2 hash file using standard mv (no progress)
  echo "Moving QCOW2 hash file to output directory..." >&2
  mv "$QCOW2_HASH_FILE" "$FINAL_QCOW2_HASH_FILE" || error_exit "Failed to move QCOW2 hash file to output directory."

  # Move original hash file using standard mv (no progress)
  echo "Moving original IMG hash file to output directory..." >&2
  mv "$ORIGINAL_HASH_FILE" "$FINAL_SOURCE_HASH_FILE" || error_exit "Failed to move original IMG hash file to output directory."

  # Final Validation of QCOW2 file
  echo "Validating the final QCOW2 file against its hash..." >&2
  COMPUTED_FINAL_HASH="$(sha256sum "$FINAL_QCOW2_PATH" | awk '{print $1}')"
  STORED_FINAL_HASH="$(get_hash_from_file "$FINAL_QCOW2_HASH_FILE")"

  if [[ "$COMPUTED_FINAL_HASH" != "$STORED_FINAL_HASH" ]]; then
    error_exit "Final QCOW2 hash mismatch. Expected: $STORED_FINAL_HASH, Found: $COMPUTED_FINAL_HASH."
  fi

  echo "Final QCOW2 file validated successfully." >&2
}

# Function to clean up the working directory
clean_up_working_directory() {
  echo "Removing working IMG file '$WORKING_IMG_FILE'..." >&2
  rm -f "$WORKING_IMG_FILE" || error_exit "Failed to remove working IMG file '$WORKING_IMG_FILE'."

  # Check if the working directory is empty
  if [[ -z "$(ls -A "$TEMP_DIR")" ]]; then
    echo "Working directory '$TEMP_DIR' is empty. Removing it..." >&2
    rmdir "$TEMP_DIR" || error_exit "Failed to remove working directory '$TEMP_DIR'."
  else
    echo "Working directory '$TEMP_DIR' is not empty. Leaving it intact." >&2
  fi
}

# ----------------------------
# Main Execution Flow
# ----------------------------

main() {
  parse_arguments "$@"

  # Step 1: Validate the Source IMG
  echo "----- Step 1: Validate the Source IMG -----" >&2
  validate_source_img
  if [[ -f "$SOURCE_HASH_FILE" ]]; then
    echo "Source IMG hash validated successfully." >&2
  else
    echo "Warning: Proceeded without hash validation for source IMG." >&2
  fi

  # Step 2: Ensure Idempotency
  echo "----- Step 2: Ensure Idempotency -----" >&2
  if ensure_idempotency; then
    echo "Idempotency check passed. Final QCOW2 file and hash already exist." >&2
    echo "$FINAL_QCOW2_PATH"
    echo "IMG processing completed for: $FINAL_QCOW2_PATH" >&2
    exit 0
  else
    echo "Proceeding with IMG processing..." >&2
  fi

  # Step 3: Prepare Destination
  echo "----- Step 3: Prepare Destination -----" >&2
  prepare_destination

  # Step 4: Prepare Working Directory
  echo "----- Step 4: Prepare Working Directory -----" >&2
  prepare_working_directory
  echo "Working directory prepared successfully." >&2

  # Step 5: Customize IMG File
  echo "----- Step 5: Customize IMG File -----" >&2
  # Invoke the customization script with the working IMG file as an argument
  "$SCRIPT" "$WORKING_IMG_FILE" || error_exit "Customization script '$SCRIPT' failed."
  echo "IMG file customized successfully." >&2

  # Step 6: Transform to QCOW2
  echo "----- Step 6: Transform to QCOW2 -----" >&2
  transform_to_qcow2
  echo "IMG transformed to QCOW2 successfully." >&2

  # Step 7: Publish Result
  echo "----- Step 7: Publish Result -----" >&2
  publish_result

  # Step 8: Clean Up
  echo "----- Step 8: Clean Up -----" >&2
  clean_up_working_directory

  echo "QCOW2 processing and publishing completed successfully." >&2

  # Output the full path of the final QCOW2 file to stdout
  echo "$FINAL_QCOW2_PATH"

  echo "IMG processing completed for: $FINAL_QCOW2_PATH" >&2
}

# Invoke the main function with all script arguments
main "$@"
