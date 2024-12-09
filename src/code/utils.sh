#!/bin/bash

# Function to log messages with timestamp and hostname to the log file
log_message() {
    local message="$1"
    local log_file="$PROJECT_ROOT/logs/process.log"
    local hostname=$(hostname -s)
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$hostname] - $message" | tee -a "$log_file"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to exit script on error with logging
exit_on_error() {
    local message="$1"
    log_message "ERROR: $message"
    exit 1
}

# Function to validate file size format (e.g., "1M", "500K", "2G")
validate_size_format() {
    local size="$1"
    if [[ ! "$size" =~ ^[0-9]+[KMG]$ ]]; then
        exit_on_error "Invalid size format: $size. Must be NUMBER followed by K, M, or G"
    fi
}

log_message "Utils script loaded"