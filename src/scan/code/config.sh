#!/bin/bash

# Load exclusions from config file
load_exclusions() {
    local config_file="$SCRIPT_DIR/../config/exclusions.conf"
    # Initialize global array without -g flag
    exclusions=()
    
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        exclusions+=("$line")
    done < "$config_file"
    
    log_message "Loaded ${#exclusions[@]} exclusion patterns"
}

# Load configurations
load_exclusions

log_message "Configurations loaded"

