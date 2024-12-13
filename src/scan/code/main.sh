#!/bin/bash

# Enable error handling
set -e  # Exit on error
set -u  # Exit on undefined variable

# Early error handling function (before we have log_message)
early_error() {
    echo "ERROR: $1"
    if [ "$2" == "show_help" ]; then
        show_help
    fi
    exit 1
}

# PRINT BANNER
echo "
 █ █    DiskAtlas
█ █ █   Version:  1.0.2
   █ █  Author:   Benjamin Pequet
        Github:   https://github.com/pequet/diskatlas/
"

# Changelog:
# 1.0.0 - Initial release
# 1.0.1 - Fixed bug in file size validation and file count
# 1.0.2 - Restructured scanning code into src/scan/code/

# Determine the directory where this script is located
SCRIPT_DIR=$(dirname "$0")
PROJECT_ROOT="$SCRIPT_DIR/../../.."

# Create necessary directories if they don't exist
mkdir -p "$PROJECT_ROOT/data" || early_error "Failed to create data directory"
mkdir -p "$PROJECT_ROOT/logs" || early_error "Failed to create logs directory"

# Source utils.sh first for logging
if [ ! -f "$SCRIPT_DIR/utils.sh" ]; then
    early_error "utils.sh not found"
fi
source "$SCRIPT_DIR/utils.sh" || early_error "Failed to source utils.sh"

# Now we can set up logging and error trap
LOG_FILE="$PROJECT_ROOT/logs/process.log"
touch "$LOG_FILE" || exit_on_error "Failed to create/access log file"

log_message "🚵 Starting DiskAtlas script"
log_message "Command line parameters: $*"

# Set up error trap after utils.sh is sourced
trap 'log_message "Error on line $LINENO"' ERR

# Default settings
MIN_FILE_SIZE="1M"  # Skip files smaller than 1MB
LIMIT_FILES=false   # No limit by default
LIMIT_COUNT=100    # Default limit when --limit is used

# Function to display help
show_help() {
    echo "Usage: $0 --drive PATH --id DRIVE_ID [OPTIONS]"
    echo
    echo "Required:"
    echo "  --drive PATH     Path to the drive to scan"
    echo "  --id DRIVE_ID    Unique identifier for the drive"
    echo
    echo "Options:"
    echo "  --min-size SIZE  Minimum file size (default: 1M)"
    echo "  --limit N        Limit number of files (for testing)"
    echo "  --help          Show this help message"
    echo
    echo "Size format: NUMBER[UNIT]"
    echo "Units: K (KB), M (MB), G (GB)"
    exit 0
}

# Convert size to bytes and validate format
validate_size() {
    local size="$1"
    # Remove any leading + if present
    size="${size#+}"
    
    # Extract number and suffix
    local number="${size%[KkMmGg]}"
    local suffix="${size#$number}"
    
    # Validate number is numeric
    if ! [[ "$number" =~ ^[0-9]+$ ]]; then
        early_error "Invalid size format. Number must be a positive integer: $size"
    fi
    
    # Convert to bytes based on suffix
    case "$(echo "$suffix" | tr '[:upper:]' '[:lower:]')" in
        "k") number=$((number * 1024)) ;;
        "m") number=$((number * 1024 * 1024)) ;;
        "g") number=$((number * 1024 * 1024 * 1024)) ;;
        "") ;;  # already in bytes
        *) early_error "Invalid size suffix. Use K, M, or G: $size" ;;
    esac
    
    # Return size in bytes with + prefix for find
    echo "+${number}c"
}

# Parse command-line arguments
DRIVE_PATH=""
DRIVE_ID=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --drive)
            DRIVE_PATH="$2"
            shift 2
            ;;
        --id)
            DRIVE_ID="$2"
            shift 2
            ;;
        --min-size)
            if [ -z "${2:-}" ]; then
                early_error "Missing value for --min-size parameter"
            fi
            MIN_FILE_SIZE=$(validate_size "$2")
            shift 2
            ;;
        --limit)
            LIMIT_FILES=true
            LIMIT_COUNT="$2"
            shift 2
            ;;
        --help)
            show_help
            ;;
        *)
            early_error "Unknown option $1"
            ;;
    esac
done

# Validate required arguments
if [ -z "$DRIVE_PATH" ] || [ -z "$DRIVE_ID" ]; then
    early_error "Drive path and drive ID must be provided" "show_help"
fi

# Check for required files
required_files=(
    "$SCRIPT_DIR/../config/exclusions.conf"
    "$SCRIPT_DIR/config.sh"
    "$SCRIPT_DIR/database.sh"
    "$SCRIPT_DIR/collect_metadata.sh"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        exit_on_error "Required file not found: $file"
    fi
done


# Source the remaining scripts
for script in config.sh database.sh collect_metadata.sh; do
    if ! source "$SCRIPT_DIR/$script"; then
        exit_on_error "Failed to source $script"
    fi
done

# Log start of execution
log_message "Starting scan of drive $DRIVE_ID at path $DRIVE_PATH"
log_message "Minimum file size: $MIN_FILE_SIZE"
if [ "$LIMIT_FILES" = true ]; then
    log_message "Limiting scan to $LIMIT_COUNT files"
fi

# Run the metadata collection process
collect_metadata "$DRIVE_PATH" "$DRIVE_ID" "$LIMIT_FILES" "$LIMIT_COUNT" "$MIN_FILE_SIZE"

# Log completion
log_message "🏁 Scan completed for drive $DRIVE_ID"