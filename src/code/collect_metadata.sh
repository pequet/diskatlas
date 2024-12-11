#!/bin/bash

# Helper functions for file metadata
get_file_size() {
    local file="$1"
    stat -f "%z" "$file" 2>/dev/null || echo "0"
}

get_mime_type() {
    local file="$1"
    file --brief --mime-type "$file" 2>/dev/null || echo "unknown"
}

# Function to build the find command with exclusions and minimum size
build_find_command() {
    local path="$1"
    local min_size="$2"
    local command="find \"$path\""
    
    # Add exclusion patterns
    for excl in "${exclusions[@]}"; do
        command+=" -path \"$path/$excl\" -prune -o"
    done
    
    # Add type and size filters
    command+=" -type f -size $min_size"
    
    echo "$command"
}

# Initialize the file count variable
declare -i file_count=0
declare -i files_processed=0
declare -i files_skipped_size=0
declare -i files_skipped_perm=0
declare -i files_skipped_other=0

process_file() {
    local file="$1"
    local drive_id="$2"
    local table_name="${drive_id//-/_}_files"
    
    # log_message "Processing file: $file"
    
    # Get file metadata
    local size
    local mime_type
    local file_name
    local file_path
    local last_modified
    
    size=$(get_file_size "$file")
    if [ $? -ne 0 ]; then
        log_message "ERROR: Failed to get size for file: $file"
        ((files_skipped_other++))
        return 1
    fi
    # log_message "File size: $size bytes"

    mime_type=$(get_mime_type "$file")
    if [ $? -ne 0 ]; then
        log_message "ERROR: Failed to get mime-type for file: $file"
        ((files_skipped_other++))
        return 1
    fi
    # log_message "Mime type: $mime_type"
    
    # Get file path components
    file_name=$(basename "$file")
    file_path="$file"  # Keep the full directory path
    file_path=$(echo "$file_path" | sed 's#//#/#g')  # Clean up any double slashes
    
    last_modified=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || echo "unknown")
    
    # Insert record into database
    if ! insert_record "$table_name" "$drive_id" "$file_path" "$file_name" "$size" "$mime_type" "$last_modified"; then
        log_message "ERROR: Failed to insert/update file in database: $file"
        ((files_skipped_other++))
        return 1
    fi
    # log_message "Successfully inserted/updated file in database"
    
    ((files_processed++))
    return 0
}

# Function to collect metadata from the drive
collect_metadata() {
    local drive_path="$1"
    local drive_id="$2"
    local limit_flag="$3"
    local limit_count="$4"
    local min_size="$5"
    local table_name="${drive_id//-/_}_files"
    
    # Validate inputs
    if [ ! -d "$drive_path" ]; then
        exit_on_error "Invalid drive path: $drive_path"
    fi
    
    # Create database table if it doesn't exist
    create_database "$table_name"
    
    # Check if drive has been scanned before
    if check_drive_exists "$table_name" "$drive_id"; then
        echo "This drive ($drive_id) has already been scanned. Choose an action:"
        echo "1) Update existing records (add new files only)"
        echo "2) Erase everything and start again"
        echo "3) Stop the operation"
        read -p "Enter your choice (1-3): " choice
        
        case $choice in
            1)
                log_message "User chose to update existing records for drive $drive_id"
                # Continue without cleaning old records
                ;;
            2)
                log_message "User chose to erase and rescan drive $drive_id"
                clean_old_records "$table_name" "$drive_id"
                ;;
            3)
                log_message "User chose to stop operation for drive $drive_id"
                echo "Operation cancelled."
                exit 0
                ;;
            *)
                log_message "Invalid choice for drive $drive_id. Stopping for safety."
                echo "Invalid choice. Operation cancelled for safety."
                exit 0
                ;;
        esac
    else
        # First time scanning this drive
        log_message "First time scanning drive $drive_id"
    fi
    
    # Initialize counters
    declare -i total_files_found=0
    
    log_message "Starting metadata collection from $drive_path (Drive ID: $drive_id)"
    log_message "Using minimum file size: $min_size"
    
    # Build and execute the find command
    local find_command
    find_command=$(build_find_command "$drive_path" "$min_size")
    # log_message "Find command: $find_command"
    
    # Get total files before processing
    local total_files
    total_files=$(eval "$find_command" | wc -l)
    total_files=$(echo "$total_files" | tr -d '[:space:]')
    # log_message "Total files found: $total_files"

    log_message "Starting to collect metadata with $total_files files to process"
    
    # Process each file
    local current_file=0

    files_skipped_size=0
    files_skipped_perm=0
    files_skipped_other=0

    while IFS= read -r file; do
        ((current_file++))
        # log_message "[$current_file/$total_files] Found file: $file"
        
        # Check file count limit
        if [ "$limit_flag" = true ] && [ $file_count -ge $limit_count ]; then
            log_message "Reached limit of $limit_count files"
            break
        fi
        
        # Handle permission denied
        if [[ "$file" == *"Permission denied"* ]]; then
            log_message "Permission denied: $file"
            ((files_skipped_perm++))
            continue
        fi
        
        if [ ! -r "$file" ]; then
            log_message "SKIP: No read permission: $file"
            ((files_skipped_perm++))
            continue
        fi
        
        if ! process_file "$file" "$drive_id"; then
            log_message "SKIP: Failed to process file: $file"
            continue
        fi
        
        ((file_count++))
        
        # Log progress every 1000 files
        if ((file_count % 1000 == 0)); then
            log_message "Processed $file_count/$total_files files"
        fi
    done < <(eval "$find_command")
    
    # Log final statistics
    log_message "Scan statistics for drive $drive_id:"
    log_message "🗄️ Files processed and added to database: $files_processed"
    log_message "😑 Files skipped due to size: $files_skipped_size"
    log_message "😕 Files skipped due to permissions: $files_skipped_perm"
    log_message "🤨 Files skipped for other reasons: $files_skipped_other"
    # log_message "Completed scanning drive $drive_id. Total files processed: $file_count"

    # Get total rows in table
    local total_rows
    total_rows=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM $table_name;")
    log_message "Total rows in table $table_name: $total_rows"
}