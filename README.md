# DiskAtlas

## Overview

DiskAtlas is a flexible bash-based tool designed to centrally store and manage the metadata of files from multiple large hard drives. These drives contain a lifetime of data, including backups, media files such as movies and music, and other valuable files. By collecting and logging metadata into a central SQLite database, DiskAtlas enables users to keep track of their data archives, making it easier to search, organize, and manage their digital assets.

## Project Structure

- `src`: Source code directory containing the main script, configuration files, and helper scripts.
- `data`: Directory to store the SQLite database file.
- `logs`: Directory to store log files.

## Installation

### 1. Clone the repository:

```bash
git clone https://github.com/pequet/diskatlas.git 
cd diskatlas
```

### 2. Set up configuration:

Edit `src/config/exclusions.conf` to specify directories to exclude.

### 3. Usage

Run the script:

```bash
./src/scan/code/main.sh --drive /path/to/drive --id DRIVE_ID [--min-size SIZE] [--limit N]
```

- Replace /path/to/drive with the path of the drive you want to scan.
- Replace DRIVE_ID with a unique identifier for the drive.
- The optional `--min-size` flag allows you to specify a minimum file size (default is 1MB).
- The optional `--limit` flag limits the number of files processed, useful for testing.

### 4. View logs:

The `process.log` file will contain all logs, including errors, processed files, and any issues encountered.

### 5. Access Database:

The metadata is stored in `src/data/file_metadata.db`. You can query it using SQLite:

```bash
sqlite3 src/data/file_metadata.db
.tables
SELECT * FROM your_table_name;
.exit
```

## Features

- Modular Design: The project is structured with separate scripts for configuration, utilities, database interactions, and metadata collection, promoting reusability and maintainability.
- Error Handling: Implements robust error handling to gracefully manage issues like invalid paths or permission errors.
- Logging: All actions and errors are logged with timestamps to process.log, ensuring a clear audit trail.
- Exclusion Handling: The exclusions.conf file allows users to specify files or directories that should be ignored during metadata collection.
- Database Storage: Metadata is securely stored in an SQLite database, facilitating easy retrieval and analysis.

## License

This project is provided for educational purposes only. No guarantee that it will work as intended.

## Support

You can buy me a coffee at https://www.buymeacoffee.com/pequet

🚵
