#!/bin/bash

# Script to import Grafana dashboards from individual JSON files or a single file
# Usage:
#   ./dashboard_import.sh -u <grafana_url> -t <grafana_token> -o <input_directory>
#   ./dashboard_import.sh -u <grafana_url> -t <grafana_token> -f <input_file>
#   ./dashboard_import.sh -u <grafana_url> -t <grafana_token> -o <input_directory> -p

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the common configuration file
source "$SCRIPT_DIR/config.sh"

# Parse dashboard import options
parse_dashboard_import_options() {
    # If no arguments provided, show help
    if [ $# -eq 0 ]; then
        print_dashboard_import_usage "$(basename "$0")"
        exit 0
    fi
    
    # Initialize variables
    GRAFANA_URL=""
    GRAFANA_TOKEN=""
    DIRECTORY=""
    INPUT_FILE=""
    OVERWRITE="false"
    PRESERVE_FOLDERS="false"
    VERBOSE="false"
    
    # Parse options
    while getopts "u:t:o:f:pwvh" opt; do
        case $opt in
            u)
                GRAFANA_URL="$OPTARG"
                ;;
            t)
                GRAFANA_TOKEN="$OPTARG"
                ;;
            o)
                DIRECTORY="$OPTARG"
                ;;
            f)
                INPUT_FILE="$OPTARG"
                ;;
            p)
                PRESERVE_FOLDERS="true"
                ;;
            w)
                OVERWRITE="true"
                ;;
            v)
                VERBOSE="true"
                ;;
            h)
                print_dashboard_import_usage "$(basename "$0")"
                exit 0
                ;;
            \?)
                error_exit "Invalid option: -$OPTARG"
                ;;
            :)
                error_exit "Option -$OPTARG requires an argument"
                ;;
        esac
    done
    
    # Validate required parameters
    if [ -z "$GRAFANA_URL" ]; then
        error_exit "Grafana URL is required. Use -u option."
    fi
    
    if [ -z "$GRAFANA_TOKEN" ]; then
        error_exit "Grafana token is required. Use -t option."
    fi
    
    # Check that either -o or -f is specified, but not both
    if [ -n "$DIRECTORY" ] && [ -n "$INPUT_FILE" ]; then
        error_exit "Cannot specify both -o (directory) and -f (file). Use only one."
    fi
    
    if [ -z "$DIRECTORY" ] && [ -z "$INPUT_FILE" ]; then
        error_exit "Either input directory (-o) or input file (-f) is required."
    fi
    
    # Export variables for use in calling script
    export GRAFANA_URL
    export GRAFANA_TOKEN
    export DIRECTORY
    export INPUT_FILE
    export OVERWRITE
    export PRESERVE_FOLDERS
    export VERBOSE
}

# Print usage information
print_dashboard_import_usage() {
    local script_name=$1
    
    cat << EOF
Usage: $script_name [OPTIONS]

Import Grafana dashboards from individual JSON files.

Options:
  -u URL       Grafana base URL (required)
               Example: https://ecate.int.ingv.it
  -t TOKEN     Grafana API token for authorization (required)
  -o DIR       Input directory containing dashboard files (use -o OR -f, not both)
  -f FILE      Single dashboard JSON file to import (use -o OR -f, not both)
  -w           Overwrite existing dashboards (optional)
  -p           Preserve folder structure (create folders if needed) (optional)
  -v           Enable verbose mode (show curl commands and detailed logs)
  -h           Display this help message

Examples:
  # Import from directory
  $script_name -u https://ecate.int.ingv.it -t YOUR_TOKEN -o ./dashboards
  
  # Import single file
  $script_name -u https://ecate.int.ingv.it -t YOUR_TOKEN -f ./dashboard_abc123_my-dashboard.json
  
  # Import with overwrite enabled
  $script_name -u http://localhost:3000 -t glsa_token123 -o ./dashboards -w
  
  # Import with folder preservation
  $script_name -u http://localhost:3000 -t glsa_token123 -o ./dashboards -p
  
  # Import with verbose logging
  $script_name -u http://localhost:3000 -t glsa_token123 -o ./dashboards -v

EOF
}

# Parse command line options
parse_dashboard_import_options "$@"

# Remove trailing slash from GRAFANA_URL if present
GRAFANA_URL="${GRAFANA_URL%/}"

# Determine import mode: directory or single file
IMPORT_MODE=""
if [ -n "$DIRECTORY" ]; then
    IMPORT_MODE="directory"
    INPUT_DIR="$DIRECTORY"
elif [ -n "$INPUT_FILE" ]; then
    IMPORT_MODE="file"
fi

# Validate inputs
info_msg "Starting Grafana dashboard import..."
info_msg "========================================"

# Show verbose mode status
if [ "$VERBOSE" = "true" ]; then
    info_msg "Verbose mode: ENABLED"
    verbose_msg "Import mode: $IMPORT_MODE"
    verbose_msg "Overwrite mode: $OVERWRITE"
    verbose_msg "Preserve folders: $PRESERVE_FOLDERS"
fi

# Check required programs
check_required_programs

# Validate Grafana URL
validate_grafana_url "$GRAFANA_URL"

# Validate Grafana token
validate_grafana_token "$GRAFANA_TOKEN"

# Validate input source based on mode
if [ "$IMPORT_MODE" = "directory" ]; then
    # Ensure input directory exists (do not create)
    ensure_directory_exists "$INPUT_DIR" "false"
elif [ "$IMPORT_MODE" = "file" ]; then
    # Ensure input file exists
    if [ ! -f "$INPUT_FILE" ]; then
        error_exit "Input file does not exist: $INPUT_FILE"
    fi
    info_msg "Input file exists: $INPUT_FILE"
fi

# Test Grafana API connection
test_grafana_connection "${GRAFANA_URL}/api/search" "$GRAFANA_TOKEN"

# Import dashboards
info_msg "Importing dashboards..."

# Prepare file list based on mode
if [ "$IMPORT_MODE" = "directory" ]; then
    # Count JSON files in input directory
    JSON_FILES=("$INPUT_DIR"/*.json)
    if [ ! -e "${JSON_FILES[0]}" ]; then
        warning_msg "No JSON files found in directory: $INPUT_DIR"
        exit 0
    fi
    FILE_COUNT=${#JSON_FILES[@]}
    info_msg "Found $FILE_COUNT dashboard file(s) to import from directory"
else
    # Single file mode
    JSON_FILES=("$INPUT_FILE")
    FILE_COUNT=1
    info_msg "Importing single dashboard file"
fi

# Counters for tracking results
SUCCESS_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0
FOLDERS_CREATED=0

# Cache for created folders (to avoid duplicate creation attempts)
# Using simple string format: "uid1:id1|uid2:id2|..."
FOLDER_CACHE=""

# Process each JSON file
for dashboard_file in "${JSON_FILES[@]}"; do
    if [ ! -f "$dashboard_file" ]; then
        continue
    fi
    
    FILENAME=$(basename "$dashboard_file")
    info_msg "Processing: $FILENAME"
    
    # Validate JSON file
    if ! jq empty "$dashboard_file" 2>/dev/null; then
        warning_msg "  Skipped: Invalid JSON format"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        continue
    fi
    
    # Check if file contains a dashboard object (exported format)
    HAS_DASHBOARD=$(jq -e '.dashboard' "$dashboard_file" > /dev/null 2>&1 && echo "yes" || echo "no")
    
    # Create payload with proper structure for Grafana API
    TEMP_FILE=$(mktemp)
    verbose_msg "Created temporary file: $TEMP_FILE"
    
    if [ "$HAS_DASHBOARD" = "yes" ]; then
        # File already has the correct structure (from export)
        # Extract dashboard and rebuild with overwrite flag
        verbose_cmd "jq '{dashboard: .dashboard, overwrite: $OVERWRITE}' \"$dashboard_file\" > \"$TEMP_FILE\""
        jq "{dashboard: .dashboard, overwrite: $OVERWRITE}" "$dashboard_file" > "$TEMP_FILE"
        
        DASHBOARD_TITLE=$(jq -r '.dashboard.title // "unknown"' "$dashboard_file")
        DASHBOARD_UID=$(jq -r '.dashboard.uid // "none"' "$dashboard_file")
    else
        # File contains raw dashboard JSON, wrap it
        verbose_cmd "jq '{dashboard: ., overwrite: $OVERWRITE}' \"$dashboard_file\" > \"$TEMP_FILE\""
        jq "{dashboard: ., overwrite: $OVERWRITE}" "$dashboard_file" > "$TEMP_FILE"
        
        DASHBOARD_TITLE=$(jq -r '.title // "unknown"' "$dashboard_file")
        DASHBOARD_UID=$(jq -r '.uid // "none"' "$dashboard_file")
    fi
    
    # Remove id from dashboard to avoid conflicts
    verbose_cmd "jq 'del(.dashboard.id)' \"$TEMP_FILE\""
    jq 'del(.dashboard.id)' "$TEMP_FILE" > "$TEMP_FILE.tmp" && mv "$TEMP_FILE.tmp" "$TEMP_FILE"
    
    verbose_msg "Dashboard: $DASHBOARD_TITLE (UID: $DASHBOARD_UID)"
    
    # Handle folder preservation if enabled
    if [ "$PRESERVE_FOLDERS" = "true" ]; then
        # Extract folder information from the exported dashboard
        if [ "$HAS_DASHBOARD" = "yes" ]; then
            FOLDER_UID=$(jq -r '.meta.folderUid // empty' "$dashboard_file")
            FOLDER_TITLE=$(jq -r '.meta.folderTitle // empty' "$dashboard_file")
        else
            FOLDER_UID=""
            FOLDER_TITLE=""
        fi
        
        # If dashboard has a folder (not in General/root)
        if [ -n "$FOLDER_UID" ] && [ "$FOLDER_UID" != "null" ]; then
            verbose_msg "Dashboard is in folder: $FOLDER_TITLE (UID: $FOLDER_UID)"
            
            # Check if we've already processed this folder
            CACHED_FOLDER_ID=$(echo "$FOLDER_CACHE" | grep -o "${FOLDER_UID}:[0-9]*" | cut -d: -f2)
            
            if [ -z "$CACHED_FOLDER_ID" ]; then
                # Check if folder exists
                FOLDER_CHECK=$(curl -s -w "\n%{http_code}" \
                    -H "Authorization: Bearer $GRAFANA_TOKEN" \
                    "${GRAFANA_URL}/api/folders/${FOLDER_UID}" 2>&1)
                
                FOLDER_HTTP_CODE=$(echo "$FOLDER_CHECK" | tail -n1)
                
                if [ "$FOLDER_HTTP_CODE" = "200" ]; then
                    # Folder exists, extract folderId
                    FOLDER_RESPONSE=$(echo "$FOLDER_CHECK" | sed '$d')
                    FOLDER_ID=$(echo "$FOLDER_RESPONSE" | jq -r '.id')
                    # Add to cache
                    if [ -z "$FOLDER_CACHE" ]; then
                        FOLDER_CACHE="${FOLDER_UID}:${FOLDER_ID}"
                    else
                        FOLDER_CACHE="${FOLDER_CACHE}|${FOLDER_UID}:${FOLDER_ID}"
                    fi
                    verbose_msg "Folder exists with ID: $FOLDER_ID"
                else
                    # Folder doesn't exist, create it
                    verbose_msg "Folder does not exist, creating: $FOLDER_TITLE"
                    
                    # Prepare folder creation payload
                    FOLDER_PAYLOAD=$(jq -n \
                        --arg uid "$FOLDER_UID" \
                        --arg title "${FOLDER_TITLE:-Imported Folder}" \
                        '{uid: $uid, title: $title}')
                    
                    FOLDER_CREATE=$(curl -s -w "\n%{http_code}" \
                        -X POST \
                        -H "Content-Type: application/json" \
                        -H "Authorization: Bearer $GRAFANA_TOKEN" \
                        -d "$FOLDER_PAYLOAD" \
                        "${GRAFANA_URL}/api/folders" 2>&1)
                    
                    FOLDER_CREATE_CODE=$(echo "$FOLDER_CREATE" | tail -n1)
                    FOLDER_CREATE_RESPONSE=$(echo "$FOLDER_CREATE" | sed '$d')
                    
                    if [ "$FOLDER_CREATE_CODE" = "200" ]; then
                        FOLDER_ID=$(echo "$FOLDER_CREATE_RESPONSE" | jq -r '.id')
                        # Add to cache
                        if [ -z "$FOLDER_CACHE" ]; then
                            FOLDER_CACHE="${FOLDER_UID}:${FOLDER_ID}"
                        else
                            FOLDER_CACHE="${FOLDER_CACHE}|${FOLDER_UID}:${FOLDER_ID}"
                        fi
                        FOLDERS_CREATED=$((FOLDERS_CREATED + 1))
                        verbose_msg "Folder created successfully with ID: $FOLDER_ID"
                    else
                        warning_msg "Failed to create folder (HTTP $FOLDER_CREATE_CODE), dashboard will be imported to General folder"
                        verbose_msg "Folder creation response: $FOLDER_CREATE_RESPONSE"
                        FOLDER_ID=""
                    fi
                fi
            else
                # Folder already in cache
                FOLDER_ID="$CACHED_FOLDER_ID"
                verbose_msg "Using cached folder ID: $FOLDER_ID"
            fi
            
            # Add folderId to the import payload if we have one
            if [ -n "$FOLDER_ID" ] && [ "$FOLDER_ID" != "null" ]; then
                verbose_cmd "jq '.folderId = $FOLDER_ID' \"$TEMP_FILE\""
                jq --argjson folderId "$FOLDER_ID" '.folderId = $folderId' "$TEMP_FILE" > "$TEMP_FILE.tmp" && mv "$TEMP_FILE.tmp" "$TEMP_FILE"
                verbose_msg "Set folderId to: $FOLDER_ID"
            fi
        else
            verbose_msg "Dashboard has no folder (will be imported to General folder)"
        fi
    fi
    
    # Build verbose curl command (with redacted token)
    CURL_CMD="curl -s -w \"\\n%{http_code}\" -X POST -H \"Content-Type: application/json\" -H \"Authorization: Bearer [REDACTED]\" --data-binary @\"$TEMP_FILE\" \"${GRAFANA_URL}/api/dashboards/db\""
    verbose_cmd "$CURL_CMD"
    
    # Import dashboard via POST request
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $GRAFANA_TOKEN" \
        --data-binary @"$TEMP_FILE" \
        "${GRAFANA_URL}/api/dashboards/db" 2>&1)
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')
    
    # Clean up temporary file
    verbose_msg "Cleaning up temporary file: $TEMP_FILE"
    rm -f "$TEMP_FILE"
    
    verbose_msg "HTTP Response Code: $HTTP_CODE"
    
    # Check response
    if [ "$HTTP_CODE" = "200" ]; then
        success_msg "  Imported: $DASHBOARD_TITLE (HTTP $HTTP_CODE)"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        
        # Show the URL of the imported dashboard if available
        DASHBOARD_URL=$(echo "$RESPONSE_BODY" | jq -r '.url // empty' 2>/dev/null)
        if [ -n "$DASHBOARD_URL" ]; then
            verbose_msg "    Dashboard URL: ${GRAFANA_URL}${DASHBOARD_URL}"
        fi
    elif [ "$HTTP_CODE" = "412" ]; then
        warning_msg "  Already exists: $DASHBOARD_TITLE (HTTP $HTTP_CODE) - use -w to overwrite"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    else
        warning_msg "  Failed: $DASHBOARD_TITLE (HTTP $HTTP_CODE)"
        if [ -n "$RESPONSE_BODY" ]; then
            ERROR_MSG=$(echo "$RESPONSE_BODY" | jq -r '.message // .error // empty' 2>/dev/null)
            if [ -n "$ERROR_MSG" ]; then
                echo "    Error: $ERROR_MSG"
            else
                echo "    Response: $RESPONSE_BODY" | head -n 3
            fi
        fi
        verbose_msg "Full response body: $RESPONSE_BODY"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
done

# Print summary
info_msg ""
info_msg "Import Summary:"
info_msg "==============="
info_msg "Total files:           $FILE_COUNT"
success_msg "Successfully imported: $SUCCESS_COUNT"
if [ $SKIPPED_COUNT -gt 0 ]; then
    warning_msg "Skipped/Exists:        $SKIPPED_COUNT"
fi
if [ $FAILED_COUNT -gt 0 ]; then
    warning_msg "Failed:                $FAILED_COUNT"
fi
if [ "$PRESERVE_FOLDERS" = "true" ] && [ $FOLDERS_CREATED -gt 0 ]; then
    info_msg "Folders created:       $FOLDERS_CREATED"
fi

if [ $FAILED_COUNT -gt 0 ]; then
    error_exit "Import completed with errors"
else
    success_msg "Dashboard import completed successfully!"
fi