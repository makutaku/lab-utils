#!/bin/bash

# process_directory.sh
# Usage: ./process_directory.sh [--match OPTION] [--verbose] target_directory command [args...]
#
# This script processes each regular file in the target_directory by executing
# the specified command with the file as an argument, based on the --match condition.
#
# Match Options:
#   --match valid-hash    : Only process files with a corresponding hash file and matching hash.
#   --match invalid-hash  : Only process files with a corresponding hash file but mismatching hash.
#   --match missing-hash  : Only process files without a corresponding hash file.
#   --match all           : Process all files (default).
#
# Options:
#   --verbose             : Enable verbose output, displaying hash details.
#
# The script always skips hidden files and files with hash extensions (*.sha256).
#
# Example:
#   ./process_directory.sh --match valid-hash --verbose /path/to/dir ./process_file.sh --option value

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display usage information
usage() {
    echo "Usage: $0 [--match OPTION] [--verbose] target_directory command [args...]"
    echo
    echo "Options:"
    echo "  --match OPTION   Filter files based on hash status."
    echo "                   Options:"
    echo "                     valid-hash    : Only process files with a matching hash."
    echo "                     invalid-hash  : Only process files with a mismatching hash."
    echo "                     missing-hash  : Only process files without a hash file."
    echo "                     all           : Process all files (default)."
    echo "  --verbose        Enable verbose output, displaying hash details."
    echo
    echo "Arguments:"
    echo "  target_directory   The directory containing files to process."
    echo "  command [args...]  The command to execute for each file, followed by its arguments."
    echo
    echo "Example:"
    echo "  $0 --match valid-hash --verbose /path/to/dir ./process_file.sh --option value"
    exit 1
}

# Default options
MATCH_OPTION="all"
VERBOSE=false

# Function to print error messages
error() {
    echo "Error: $1"
    usage
}

# Parse arguments
# Initialize an array to hold the positional arguments after options
POSITIONAL=()

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --match)
            if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
                MATCH_OPTION="$2"
                shift 2
            else
                error "Missing value for --match option."
            fi
            ;;
        --match=*)
            MATCH_OPTION="${1#*=}"
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        --*)
            error "Unknown option: $1"
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

# Restore positional parameters
set -- "${POSITIONAL[@]}"

# Check if at least two arguments are provided: target_directory and command
if [ "$#" -lt 2 ]; then
    echo "Error: Insufficient arguments."
    usage
fi

# Assign the first positional argument to TARGET_DIR and shift it out
TARGET_DIR="$1"
shift

# Assign the remaining arguments to COMMAND array
COMMAND=("$@")

# Validate MATCH_OPTION
case "$MATCH_OPTION" in
    valid-hash|invalid-hash|missing-hash|all)
        ;;
    *)
        echo "Error: Invalid value for --match option: '$MATCH_OPTION'"
        usage
        ;;
esac

# Check if TARGET_DIR exists and is a directory
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: '$TARGET_DIR' is not a directory or does not exist."
    exit 1
fi

# Function to compute SHA256 hash of a file
compute_hash() {
    local file="$1"
    sha256sum "$file" | awk '{print $1}'
}

# Function to read expected hash from hash file (extract only the hash)
read_expected_hash() {
    local hash_file="$1"
    if [ -f "$hash_file" ]; then
        # Extract only the first field (the hash)
        expected_hash=$(awk '{print $1}' "$hash_file")
        echo "$expected_hash"
    else
        echo ""
    fi
}

# Log the start of processing
echo "Starting processing directory: '$TARGET_DIR' with match condition: '$MATCH_OPTION'"

# Process files based on MATCH_OPTION
find "$TARGET_DIR" -maxdepth 1 -type f ! -name '.*' ! -name '*.sha256' | while IFS= read -r file; do
    # Determine corresponding hash file (e.g., file.txt.sha256)
    hash_file="${file}.sha256"

    if [ "$MATCH_OPTION" == "missing-hash" ]; then
        # For missing-hash, process files without a hash file
        if [ ! -f "$hash_file" ]; then
            # Process the file
            if $VERBOSE; then
                echo "Processing file: '$file'"
                echo "  Hash file     : '$hash_file' (missing)"
                echo "  Hash matches  : N/A"
            fi

            # Execute the command with the file as the last argument
            "${COMMAND[@]}" "$file"

            # Check if the command succeeded
            if [ $? -ne 0 ]; then
                echo "Warning: Command failed for file '$file'. Continuing with next file."
            fi
        else
            # Skip the file
            if $VERBOSE; then
                echo "Skipping file: '$file'"
                echo "  Hash file     : '$hash_file' (exists)"
                echo "  Match condition: 'missing-hash'"
            fi
        fi
    else
        # For other match options, proceed with hash computations
        if [ -f "$hash_file" ]; then
            expected_hash=$(read_expected_hash "$hash_file")
            if [ -n "$expected_hash" ]; then
                current_hash=$(compute_hash "$file")
                hash_matches=false
                if [ "$current_hash" == "$expected_hash" ]; then
                    hash_matches=true
                fi
            fi
        fi

        # Determine if the file should be processed based on MATCH_OPTION
        should_process=false

        case "$MATCH_OPTION" in
            valid-hash)
                if [ -f "$hash_file" ] && [ "$hash_matches" = true ]; then
                    should_process=true
                fi
                ;;
            invalid-hash)
                if [ -f "$hash_file" ] && [ "$hash_matches" = false ]; then
                    should_process=true
                fi
                ;;
            all)
                should_process=true
                ;;
        esac

        if $should_process; then
            if $VERBOSE; then
                echo "Processing file: '$file'"
                echo "  Hash file     : '$hash_file'"
                if [ -f "$hash_file" ]; then
                    echo "  Expected hash : '$expected_hash'"
                    echo "  Actual hash   : '$current_hash'"
                else
                    echo "  Expected hash : N/A (missing hash file)"
                    echo "  Actual hash   : N/A (missing hash file)"
                fi
                echo "  Hash matches   : $hash_matches"
            fi

            # Execute the command with the file as the last argument
            "${COMMAND[@]}" "$file"

            # Check if the command succeeded
            if [ $? -ne 0 ]; then
                echo "Warning: Command failed for file '$file'. Continuing with next file."
            fi
        else
            if $VERBOSE; then
                echo "Skipping file: '$file'"
                if [ -f "$hash_file" ]; then
                    echo "  Hash file     : '$hash_file'"
                    echo "  Expected hash : '$expected_hash'"
                    echo "  Actual hash   : '$current_hash'"
                else
                    echo "  Hash file     : N/A (missing hash file)"
                fi
                echo "  Match condition: '$MATCH_OPTION'"
                echo "  Hash matches   : $hash_matches"
            fi
        fi
    fi
done

# Log the end of processing
echo "Processing complete."
