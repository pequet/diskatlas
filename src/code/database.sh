#!/bin/bash

# Database setup and functions
DB_FILE="$PROJECT_ROOT/data/file_metadata.db"

# Create the database if it doesn't exist
create_database() {
    local table_name="$1"
    
    # Create the database file if it doesn't exist
    if [ ! -f "$DB_FILE" ]; then
        log_message "Creating new database at $DB_FILE"
        touch "$DB_FILE"
    fi
    
    # Create table for this drive if it doesn't exist
    log_message "Ensuring table $table_name exists"
    sqlite3 "$DB_FILE" <<EOF
    CREATE TABLE IF NOT EXISTS $table_name (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        drive_id TEXT,
        file_path TEXT,
        file_name TEXT,
        file_size INTEGER,
        file_type TEXT,
        last_modified DATETIME,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        modified_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(drive_id, file_path, file_name)
    );
    CREATE INDEX IF NOT EXISTS idx_${table_name}_path ON $table_name(file_path);
    CREATE INDEX IF NOT EXISTS idx_${table_name}_type ON $table_name(file_type);
EOF
    
    if [ $? -eq 0 ]; then
        log_message "Database table $table_name ready"
    else
        exit_on_error "Failed to create database table $table_name"
    fi
}

# Function to clean old records for a drive
clean_old_records() {
    local table_name="$1"
    local drive_id="$2"
    
    log_message "Cleaning old records for drive $drive_id"
    
    # First ensure the table exists
    create_database "$table_name"
    
    # Then clean old records
    sqlite3 "$DB_FILE" "DELETE FROM $table_name WHERE drive_id = '$drive_id';"
    
    if [ $? -eq 0 ]; then
        log_message "Cleaned old records for drive $drive_id"
    else
        exit_on_error "Failed to clean old records for drive $drive_id"
    fi
}

insert_record() {
    local table_name="$1"
    local drive_id="$2"
    local file_path="$3"
    local file_name="$4"
    local file_size="$5"
    local file_type="$6"
    local last_modified="$7"

    # Escape single quotes in values
    local drive_id_escaped=$(echo "$drive_id" | sed "s/'/''/g")
    local file_path_escaped=$(echo "$file_path" | sed "s/'/''/g")
    local file_name_escaped=$(echo "$file_name" | sed "s/'/''/g")
    local file_type_escaped=$(echo "$file_type" | sed "s/'/''/g")
    local last_modified_escaped=$(echo "$last_modified" | sed "s/'/''/g")

    # Execute the SQL command
    sql_command=$(cat <<EOF
INSERT INTO "$table_name" (drive_id, file_path, file_name, file_size, file_type, last_modified, created_at, modified_at)
VALUES ('$drive_id_escaped', '$file_path_escaped', '$file_name_escaped', $file_size, '$file_type_escaped', '$last_modified_escaped', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT(drive_id, file_path, file_name) DO UPDATE SET
    file_name = excluded.file_name,
    file_size = excluded.file_size,
    file_type = excluded.file_type,
    last_modified = excluded.last_modified,
    modified_at = CURRENT_TIMESTAMP;
EOF
)

    # Execute the SQL command
    echo "$sql_command" | sqlite3 "$DB_FILE"

    # Check for errors
    if [ $? -ne 0 ]; then
        log_message "ERROR: Failed to execute SQL command."
        log_message "DEBUG: SQL Command that failed: $sql_command"
    fi
}



# Check if a drive has records in the database
check_drive_exists() {
    local table_name="$1"
    local drive_id="$2"
    
    # Count records for this drive
    local count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM $table_name WHERE drive_id='$drive_id';")
    
    # Return true (0) if records exist, false (1) otherwise
    [ "$count" -gt 0 ]
}

log_message "Database functions loaded"