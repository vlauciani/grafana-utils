#!/bin/bash

# Script to export Grafana datasources to individual JSON files
# Usage: ./datasource_export.sh -u <grafana_url> -t <grafana_token> -o <output_directory>

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the common configuration file
source "$SCRIPT_DIR/config.sh"

# Parse command line options
parse_common_options "export" "$@"

# Set OUTPUT_DIR from parsed DIRECTORY variable
OUTPUT_DIR="$DIRECTORY"

# Validate inputs
info_msg "Starting Grafana datasource export..."
info_msg "========================================"

# Show verbose mode status
if [ "$VERBOSE" = "true" ]; then
    info_msg "Verbose mode: ENABLED"
fi

# Check required programs
check_required_programs

# Validate Grafana URL
validate_grafana_url "$GRAFANA_URL"

# Validate Grafana token
validate_grafana_token "$GRAFANA_TOKEN"

# Ensure output directory exists (create if missing)
ensure_directory_exists "$OUTPUT_DIR" "true"

# Test Grafana API connection
test_grafana_connection "$GRAFANA_URL" "$GRAFANA_TOKEN"

# Export datasources
info_msg "Exporting datasources..."

# Fetch datasources and save to temporary file
TEMP_FILE=$(mktemp)
verbose_msg "Created temporary file: $TEMP_FILE"

# Build and execute curl command
CURL_CMD="curl -s -H \"Authorization: Bearer [REDACTED]\" \"$GRAFANA_URL\""
verbose_cmd "$CURL_CMD"

curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" "$GRAFANA_URL" > "$TEMP_FILE"

# Check if the request was successful
if [ $? -ne 0 ]; then
    rm -f "$TEMP_FILE"
    error_exit "Failed to fetch datasources from Grafana API"
fi

# Check if response is valid JSON
if ! jq empty "$TEMP_FILE" 2>/dev/null; then
    rm -f "$TEMP_FILE"
    error_exit "Invalid JSON response from Grafana API"
fi

# Count datasources
DATASOURCE_COUNT=$(jq 'length' "$TEMP_FILE")

if [ "$DATASOURCE_COUNT" -eq 0 ]; then
    rm -f "$TEMP_FILE"
    warning_msg "No datasources found in Grafana"
    exit 0
fi

info_msg "Found $DATASOURCE_COUNT datasource(s)"

# Clean output directory (remove old datasource files)
info_msg "Cleaning output directory..."
verbose_cmd "rm -f \"$OUTPUT_DIR\"/datasource_*.json"
rm -f "$OUTPUT_DIR"/datasource_*.json

# Export each datasource to a separate file
COUNTER=1
jq -c -M '.[]' "$TEMP_FILE" | while read -r datasource; do
    # Generate filename with datasource name if available
    DS_NAME=$(echo "$datasource" | jq -r '.name // "unknown"' | tr ' ' '_' | tr '/' '_')
    DS_ID=$(echo "$datasource" | jq -r '.id // "0"')
    
    OUTPUT_FILE="$OUTPUT_DIR/datasource_${DS_ID}_${DS_NAME}.json"
    
    verbose_msg "Processing datasource ID: $DS_ID, Name: $DS_NAME"
    verbose_cmd "echo \"\$datasource\" | jq '.' > \"$OUTPUT_FILE\""
    
    # Save datasource to file with pretty formatting
    echo "$datasource" | jq '.' > "$OUTPUT_FILE"
    
    if [ $? -eq 0 ]; then
        info_msg "  Exported: $(basename "$OUTPUT_FILE")"
    else
        warning_msg "  Failed to export datasource ID: $DS_ID"
    fi
    
    COUNTER=$((COUNTER + 1))
done

# Clean up temporary file
verbose_msg "Cleaning up temporary file: $TEMP_FILE"
rm -f "$TEMP_FILE"

success_msg "Datasource export completed!"
success_msg "Exported $(($COUNTER - 1)) datasource(s) to: $OUTPUT_DIR"