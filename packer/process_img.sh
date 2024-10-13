#!/bin/bash

set -euo pipefail

# ----------------------------
# Global Flag Variables
# ----------------------------
FORCE=false
DRY_RUN=false
VERBOSE=false

# Log functions
log_info() {
    echo "[INFO] $@" >&2
}

log_error() {
    echo "[ERROR] $@" >&2
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo "[DEBUG] $@" >&2
    fi
}

# Main function
main() {
    parse_arguments "$@"
    check_dependencies

    check_input_file

    if [ "$SKIP_IDEMPOTENCY" = false ]; then
        idempotency_check
    else
        log_info "Skipping idempotency check due to --force flag."
    fi

    copy_input_to_working_dir
    prepare_output_dir
    customize_image
    publish_artifacts
    cleanup

    echo "$OUTPUT_FILE"
}

# Function to parse command-line arguments
parse_arguments() {
    SCRIPT="./customize_img.sh"
    WORKING_DIR=""
    OUTPUT_DIR=""
    PREFIX=""
    OVERWRITE=false
    SKIP_IDEMPOTENCY=false
    INSTALL_DEPENDENCIES=false

    POSITIONAL=()

    while [[ $# -gt 0 ]]
    do
        key="$1"

        case $key in
            --script)
                SCRIPT="$2"
                shift; shift
                ;;
            --working-dir)
                WORKING_DIR="$2"
                shift; shift
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                shift; shift
                ;;
            --prefix)
                PREFIX="$2"
                shift; shift
                ;;
            --overwrite)
                OVERWRITE=true
                shift
                ;;
            --force)
                OVERWRITE=true
                SKIP_IDEMPOTENCY=true
                FORCE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --install-dependencies)
                INSTALL_DEPENDENCIES=true
                shift
                ;;
            --help|-h)
                usage
                ;;
            --)
                shift
                break
                ;;
            -*)
                log_error "Unknown option $1"
                usage
                ;;
            *)
                POSITIONAL+=("$1")
                shift
                ;;
        esac
    done

    # Restore positional parameters
    set -- "${POSITIONAL[@]}"

    if [ "$#" -ne 1 ]; then
        log_error "Incorrect number of arguments."
        usage
    fi

    INPUT_FILE="$1"

    # Validate mandatory arguments
    if [ -z "$OUTPUT_DIR" ]; then
        log_error "Error: --output-dir is required"
        usage
    fi

    # If WORKING_DIR not provided, create a temporary directory
    if [ -z "$WORKING_DIR" ]; then
        WORKING_DIR=$(mktemp -d)
        TEMP_WORKING_DIR=true
        log_debug "Created temporary working directory: $WORKING_DIR"
    else
        TEMP_WORKING_DIR=false
        log_debug "Using specified working directory: $WORKING_DIR"
    fi
}

# Function to display usage information
usage() {
    echo "Usage: $0 [options] input_file" >&2
    echo
    echo "Options:" >&2
    echo "  --script SCRIPT_PATH        Path to customization script (default: ./customize_img.sh)" >&2
    echo "  --working-dir DIR            Working directory (optional, temporary if not set)" >&2
    echo "  --output-dir DIR             Output directory (required)" >&2
    echo "  --prefix PREFIX              Prefix for filenames to prevent collisions (default: empty)" >&2
    echo "  --overwrite                  Overwrite existing output files if they exist" >&2
    echo "  --force                      Force reprocessing by overwriting and skipping idempotency checks" >&2
    echo "  --dry-run                    Simulate actions without modifying the output directory" >&2
    echo "  --verbose                    Enable verbose debug logging" >&2
    echo "  --install-dependencies       Install missing dependencies automatically" >&2
    echo "  -h, --help                   Display this help message" >&2
    echo
    echo "Examples:" >&2
    echo "  $0 --output-dir ./output ./input/image.img" >&2
    echo "  $0 --prefix \"xyz_\" --script ./customize_img.sh --output-dir ./output ./input/image.img" >&2
    echo "  $0 --force --dry-run --verbose --output-dir ./output ./input/image.img" >&2
    exit 1
}

# Function to check dependencies
check_dependencies() {
    DEPENDENCIES=(pv sha256sum)
    MISSING_DEPS=()

    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            MISSING_DEPS+=("$dep")
        fi
    done

    if [ "${#MISSING_DEPS[@]}" -ne 0 ]; then
        log_error "Missing dependencies: ${MISSING_DEPS[*]}"
        if [ "$INSTALL_DEPENDENCIES" = true ]; then
            log_info "Installing missing dependencies..."
            sudo apt-get update
            sudo apt-get install -y "${MISSING_DEPS[@]}"
        else
            log_error "Please install them with:"
            log_error "sudo apt-get install ${MISSING_DEPS[*]}"
            exit 1
        fi
    else
        log_debug "All dependencies are satisfied."
    fi
}

# Function to read hash from a hash file
read_hash_from_file() {
    # Usage: read_hash_from_file filename
    # Reads the hash from the hash file (first field)
    awk '{print $1}' "$1"
}

# Function to generate hash of a file
generate_hash_of_file() {
    # Usage: generate_hash_of_file file hashfile
    sha256sum "$1" > "$2"
}

# Check input file exists
check_input_file() {
    log_info "Checking if input file exists..."
    if [ ! -f "$INPUT_FILE" ]; then
        log_error "Error: Input file '$INPUT_FILE' does not exist"
        exit 1
    fi
    log_debug "Input file '$INPUT_FILE' exists."
}

# Idempotency check
idempotency_check() {
    log_info "Checking for idempotency..."
    INPUT_HASH_FILE="$INPUT_FILE.sha256"
    OUTPUT_FILE="$OUTPUT_DIR/${PREFIX}$(basename "$INPUT_FILE")"
    OUTPUT_PREV_HASH_FILE="$OUTPUT_FILE.prev.sha256"

    if [ -f "$INPUT_HASH_FILE" ] && [ -f "$OUTPUT_PREV_HASH_FILE" ] && [ -f "$OUTPUT_FILE" ]; then
        INPUT_HASH=$(read_hash_from_file "$INPUT_HASH_FILE")
        OUTPUT_PREV_HASH=$(read_hash_from_file "$OUTPUT_PREV_HASH_FILE")

        if [ "$INPUT_HASH" = "$OUTPUT_PREV_HASH" ]; then
            log_info "Idempotency detected: Output file is up-to-date"
            echo "$OUTPUT_FILE"
            exit 0
        else
            log_debug "Hash mismatch: INPUT_HASH ($INPUT_HASH) != OUTPUT_PREV_HASH ($OUTPUT_PREV_HASH)"
        fi
    else
        log_debug "Either input hash file, output previous hash file, or output file does not exist."
    fi
}

# Copy input file to working dir
copy_input_to_working_dir() {
    log_info "Copying input file to working directory..."
    mkdir -p "$WORKING_DIR"

    WORKING_FILE="$WORKING_DIR/${PREFIX}$(basename "$INPUT_FILE")"
    INPUT_HASH_FILE="$INPUT_FILE.sha256"
    WORKING_HASH_FILE="$WORKING_FILE.sha256"

    log_debug "Copying '$INPUT_FILE' to '$WORKING_FILE' with progress indicator."
    pv "$INPUT_FILE" > "$WORKING_FILE"

    log_info "Calculating hash of working file..."
    generate_hash_of_file "$WORKING_FILE" "$WORKING_HASH_FILE"

    if [ -f "$INPUT_HASH_FILE" ]; then
        log_info "Validating hash matches input hash..."
        INPUT_HASH=$(read_hash_from_file "$INPUT_HASH_FILE")
        WORKING_HASH=$(read_hash_from_file "$WORKING_HASH_FILE")

        if [ "$INPUT_HASH" != "$WORKING_HASH" ]; then
            log_error "Error: Hash of working file does not match input hash"
            log_info "Input Hash:    $INPUT_HASH"
            log_info "Working Hash:  $WORKING_HASH"
            exit 1
        else
            log_debug "Hash validation successful: $INPUT_HASH"
        fi
    else
        log_info "Warning: Input hash file does not exist, proceeding without validation"
    fi

    # Check for idempotency again only if OUTPUT_FILE exists and not skipping idempotency
    if [ "$SKIP_IDEMPOTENCY" = false ] && [ -f "$OUTPUT_FILE" ] && [ -f "$OUTPUT_PREV_HASH_FILE" ]; then
        log_info "Re-checking idempotency after copying..."
        OUTPUT_PREV_HASH=$(read_hash_from_file "$OUTPUT_PREV_HASH_FILE")
        WORKING_HASH=$(read_hash_from_file "$WORKING_HASH_FILE")

        if [ "$WORKING_HASH" = "$OUTPUT_PREV_HASH" ]; then
            log_info "Idempotency detected: Output file is up-to-date"
            echo "$OUTPUT_FILE"
            exit 0
        else
            log_debug "Hash mismatch after copying: WORKING_HASH ($WORKING_HASH) != OUTPUT_PREV_HASH ($OUTPUT_PREV_HASH)"
        fi
    else
        log_debug "Skipping re-idempotency check due to --force or missing output files."
    fi
}

# Prepare output directory
prepare_output_dir() {
    log_info "Preparing output directory..."
    mkdir -p "$OUTPUT_DIR"

    OUTPUT_FILE="$OUTPUT_DIR/${PREFIX}$(basename "$INPUT_FILE")"

    if [ -f "$OUTPUT_FILE" ] && [ "$OVERWRITE" = false ]; then
        log_error "Error: Output file '$OUTPUT_FILE' already exists. Use --overwrite to overwrite."
        exit 1
    fi

    if [ "$OVERWRITE" = true ] && [ -f "$OUTPUT_FILE" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_info "Dry-run: Would overwrite existing output file '$OUTPUT_FILE'"
        else
            log_info "Overwriting existing output file '$OUTPUT_FILE'"
            rm -f "$OUTPUT_FILE" "$OUTPUT_FILE.sha256" "$OUTPUT_FILE.prev.sha256"
        fi
    fi
}

# Invoke customization script
customize_image() {
    log_info "Invoking customization script..."
    if [ ! -f "$SCRIPT" ]; then
        log_error "Error: Customization script '$SCRIPT' not found"
        exit 1
    fi

    chmod +x "$SCRIPT"

    # Prepare flags to pass to the customization script
    INNER_SCRIPT_FLAGS=()
    if [ "$FORCE" = true ]; then
        INNER_SCRIPT_FLAGS+=("--force")
    fi
    if [ "$DRY_RUN" = true ]; then
        INNER_SCRIPT_FLAGS+=("--dry-run")
    fi
    if [ "$VERBOSE" = true ]; then
        INNER_SCRIPT_FLAGS+=("--verbose")
    fi

    log_debug "Executing customization script with flags: ${INNER_SCRIPT_FLAGS[*]}"

    if [ "$DRY_RUN" = true ]; then
        log_info "Dry-run: Executing customization script '$SCRIPT' with flags."
        "$SCRIPT" "${INNER_SCRIPT_FLAGS[@]}" "$WORKING_FILE"
    else
        if ! "$SCRIPT" "${INNER_SCRIPT_FLAGS[@]}" "$WORKING_FILE"; then
            log_error "Error: Customization script failed"
            exit 1
        fi
    fi

    # After processing, rename existing hash file and create a new one
    log_info "Updating hash files after processing..."
    if [ "$DRY_RUN" = true ]; then
        log_info "Dry-run: Skipping hash file updates"
    else
        if [ -f "$WORKING_HASH_FILE" ]; then
            mv "$WORKING_HASH_FILE" "${WORKING_HASH_FILE%.sha256}.prev.sha256"
            log_debug "Renamed '$WORKING_HASH_FILE' to '${WORKING_HASH_FILE%.sha256}.prev.sha256'"
        fi
        generate_hash_of_file "$WORKING_FILE" "$WORKING_HASH_FILE"
    fi
}

# Publish artifacts
publish_artifacts() {
    log_info "Publishing artifacts..."
    OUTPUT_FILE="$OUTPUT_DIR/${PREFIX}$(basename "$INPUT_FILE")"
    OUTPUT_HASH_FILE="$OUTPUT_FILE.sha256"
    OUTPUT_PREV_HASH_FILE="$OUTPUT_FILE.prev.sha256"

    if [ "$DRY_RUN" = true ]; then
        log_info "Dry-run: Skipping moving processed file to output directory."
        log_info "Dry-run: Skipping moving hash files to output directory."
    else
        log_info "Moving processed file to output directory..."
        mv "$WORKING_FILE" "$OUTPUT_FILE"

        log_info "Moving hash files to output directory..."
        mv "${WORKING_HASH_FILE%.sha256}.prev.sha256" "$OUTPUT_PREV_HASH_FILE" 2>/dev/null || log_debug "Previous hash file '${WORKING_HASH_FILE%.sha256}.prev.sha256' does not exist."
        mv "$WORKING_HASH_FILE" "$OUTPUT_HASH_FILE"
    fi
}

# Cleanup
cleanup() {
    log_info "Cleaning up working directory..."
    if [ "$DRY_RUN" = true ]; then
        log_info "Dry-run: Skipping actual file removals."
    else
        rm -f "$WORKING_FILE" "${WORKING_HASH_FILE%.sha256}.prev.sha256" "$WORKING_HASH_FILE" 2>/dev/null || log_debug "Some files may not have existed for removal."
    fi

    # Remove working dir if empty and it was a temporary directory
    if [ "$TEMP_WORKING_DIR" = true ] && [ -d "$WORKING_DIR" ] && [ -z "$(ls -A "$WORKING_DIR")" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_info "Dry-run: Would remove empty temporary working directory '$WORKING_DIR'"
        else
            log_info "Working directory '$WORKING_DIR' is empty, removing."
            rmdir "$WORKING_DIR"
        fi
    else
        log_debug "Working directory '$WORKING_DIR' is not empty or was provided by the user."
    fi
}

# Run main with all arguments
main "$@"
