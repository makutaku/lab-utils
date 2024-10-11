#!/bin/bash

# process_directory.sh
# Usage: ./process_directory.sh [--match OPTION] [--verbose] target_directory
#
# This script lists each regular file in the target_directory based on the --match condition.
#
# Match Options:
#   --match valid-hash    : Only list files with a corresponding hash file and matching hash.
#   --match invalid-hash  : Only list files with a corresponding hash file but mismatching hash.
#   --match missing-hash  : Only list files without a corresponding hash file.
#   --match all           : List all files (default).
#
# Options:
#   --verbose             : Enable verbose output, displaying hash details.
#
# The script always skips hidden files and files with hash extensions (*.sha256).
#
# Example:
#   ./process_directory.sh --match valid-hash --verbose /path/to/dir | ./another_script.sh

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display usage information
usage() {
    echo "Usage: $0 [--match OPTION] [--verbose] target_directory"
    echo
    echo "Options:"
    echo "  --match OPTION   Filter files based on hash status."
    echo "                   Options:"
    echo "                     valid-hash    : Only list files with a matching hash."
    echo "                     invalid-hash  : Only list files with a mismatching hash."
    echo "                     missing-hash  : Only list files without a hash file."
    echo "                     all           : List all files (default)."
    echo "  --verbose        Enable verbose output, displaying hash details."
    echo
    echo "Arguments:"
    echo "  target_directory   The directory containing files to process."
    echo
    echo "Example:"
    echo "  $0 --match valid-hash --verbose /path/to/dir | ./another_script.sh"
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

# Check if exactly one positional argument is provided: target_directory
if [ "$#" -ne 1 ]; then
    echo "Error: Exactly one argument required (target_directory)."
    usage
fi

# Assign the positional argument to TARGET_DIR
TARGET_DIR="$1"

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
echo "Starting processing directory: '$TARGET_DIR' with match condition: '$MATCH_OPTION'" >&2

# Process files based on MATCH_OPTION
find "$TARGET_DIR" -maxdepth 1 -type f ! -name '.*' ! -name '*.sha256' | while IFS= read -r file; do
    # Determine corresponding hash file (e.g., file.txt.sha256)
    hash_file="${file}.sha256"

    if [ "$MATCH_OPTION" == "missing-hash" ]; then
        # For missing-hash, list files without a hash file
        if [ ! -f "$hash_file" ]; then
            if $VERBOSE; then
                echo "Listing file: '$file'" >&2
                echo "  Hash file     : '$hash_file' (missing)"
                echo "  Hash matches  : N/A"
            fi
            # Output the file path to stdout
            echo "$file"
        else
            if $VERBOSE; then
                echo "Skipping file: '$file'" >&2
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

        # Determine if the file should be listed based on MATCH_OPTION
        should_list=false

        case "$MATCH_OPTION" in
            valid-hash)
                if [ -f "$hash_file" ] && [ "$hash_matches" = true ]; then
                    should_list=true
                fi
                ;;
            invalid-hash)
                if [ -f "$hash_file" ] && [ "$hash_matches" = false ]; then
                    should_list=true
                fi
                ;;
            all)
                should_list=true
                ;;
        esac

        if $should_list; then
            if $VERBOSE; then
                echo "Listing file: '$file'" >&2
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
            # Output the file path to stdout
            echo "$file"
        else
            if $VERBOSE; then
                echo "Skipping file: '$file'" >&2
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
echo "Processing complete." >&2
