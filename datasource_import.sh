#!/bin/bash

# Script to import Grafana datasources from individual JSON files or a single file
# Usage:
#   ./datasource_import.sh -u <grafana_url> -t <grafana_token> -o <input_directory>
#   ./datasource_import.sh -u <grafana_url> -t <grafana_token> -f <input_file>

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the common configuration file
source "$SCRIPT_DIR/config.sh"

# Parse command line options (import-specific with -f support)
parse_import_options "$@"

# Determine import mode: directory or single file
IMPORT_MODE=""
if [ -n "$DIRECTORY" ]; then
    IMPORT_MODE="directory"
    INPUT_DIR="$DIRECTORY"
elif [ -n "$INPUT_FILE" ]; then
    IMPORT_MODE="file"
fi

# Validate inputs
info_msg "Starting Grafana datasource import..."
info_msg "========================================"

# Show verbose mode status
if [ "$VERBOSE" = "true" ]; then
    info_msg "Verbose mode: ENABLED"
    verbose_msg "Import mode: $IMPORT_MODE"
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
test_grafana_connection "$GRAFANA_URL" "$GRAFANA_TOKEN"

# Import datasources
info_msg "Importing datasources..."

# Prepare file list based on mode
if [ "$IMPORT_MODE" = "directory" ]; then
    # Count JSON files in input directory
    JSON_FILES=("$INPUT_DIR"/*.json)
    if [ ! -e "${JSON_FILES[0]}" ]; then
        warning_msg "No JSON files found in directory: $INPUT_DIR"
        exit 0
    fi
    FILE_COUNT=${#JSON_FILES[@]}
    info_msg "Found $FILE_COUNT datasource file(s) to import from directory"
else
    # Single file mode
    JSON_FILES=("$INPUT_FILE")
    FILE_COUNT=1
    info_msg "Importing single datasource file"
fi

# Counters for tracking results
SUCCESS_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0

# Process each JSON file
for datasource_file in "${JSON_FILES[@]}"; do
    if [ ! -f "$datasource_file" ]; then
        continue
    fi
    
    FILENAME=$(basename "$datasource_file")
    info_msg "Processing: $FILENAME"
    
    # Validate JSON file
    if ! jq empty "$datasource_file" 2>/dev/null; then
        warning_msg "  Skipped: Invalid JSON format"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        continue
    fi
    
    # Get datasource name for better logging
    DS_NAME=$(jq -r '.name // "unknown"' "$datasource_file")
    
    # Remove id and uid fields as they might conflict with existing datasources
    # Create a clean version without these fields
    TEMP_FILE=$(mktemp)
    verbose_msg "Created temporary file: $TEMP_FILE"
    verbose_cmd "jq 'del(.id, .uid)' \"$datasource_file\" > \"$TEMP_FILE\""
    jq 'del(.id, .uid)' "$datasource_file" > "$TEMP_FILE"
    
    # Build verbose curl command (with redacted token)
    CURL_CMD="curl -s -w \"\\n%{http_code}\" -X POST -H \"Content-Type: application/json\" -H \"Authorization: Bearer [REDACTED]\" --data-binary @\"$TEMP_FILE\" \"$GRAFANA_URL\""
    verbose_cmd "$CURL_CMD"
    
    # Import datasource via POST request
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $GRAFANA_TOKEN" \
        --data-binary @"$TEMP_FILE" \
        "$GRAFANA_URL" 2>&1)
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')
    
    # Clean up temporary file
    verbose_msg "Cleaning up temporary file: $TEMP_FILE"
    rm -f "$TEMP_FILE"
    
    verbose_msg "HTTP Response Code: $HTTP_CODE"
    
    # Check response
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        success_msg "  Imported: $DS_NAME (HTTP $HTTP_CODE)"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    elif [ "$HTTP_CODE" = "409" ]; then
        warning_msg "  Already exists: $DS_NAME (HTTP $HTTP_CODE)"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    else
        warning_msg "  Failed: $DS_NAME (HTTP $HTTP_CODE)"
        if [ -n "$RESPONSE_BODY" ]; then
            echo "    Response: $RESPONSE_BODY" | head -n 3
        fi
        verbose_msg "Full response body: $RESPONSE_BODY"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
done

# Print summary
info_msg ""
info_msg "Import Summary:"
info_msg "==============="
info_msg "Total files:      $FILE_COUNT"
success_msg "Successfully imported: $SUCCESS_COUNT"
if [ $SKIPPED_COUNT -gt 0 ]; then
    warning_msg "Skipped/Exists:        $SKIPPED_COUNT"
fi
if [ $FAILED_COUNT -gt 0 ]; then
    warning_msg "Failed:                $FAILED_COUNT"
fi

if [ $FAILED_COUNT -gt 0 ]; then
    error_exit "Import completed with errors"
else
    success_msg "Datasource import completed successfully!"
fi