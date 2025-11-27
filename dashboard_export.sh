#!/bin/bash

# Script to export Grafana dashboards to individual JSON files
# Usage: 
#   ./dashboard_export.sh -u <grafana_url> -t <grafana_token> -o <output_directory>
#   ./dashboard_export.sh -u <grafana_url> -t <grafana_token> -o <output_directory> -d <dashboard_uid>

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the common configuration file
source "$SCRIPT_DIR/config.sh"

# Parse dashboard export options
parse_dashboard_export_options() {
    # If no arguments provided, show help
    if [ $# -eq 0 ]; then
        print_dashboard_export_usage "$(basename "$0")"
        exit 0
    fi
    
    # Initialize variables
    GRAFANA_URL=""
    GRAFANA_TOKEN=""
    DIRECTORY=""
    DASHBOARD_UID=""
    VERBOSE="false"
    
    # Parse options
    while getopts "u:t:o:d:vh" opt; do
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
            d)
                DASHBOARD_UID="$OPTARG"
                ;;
            v)
                VERBOSE="true"
                ;;
            h)
                print_dashboard_export_usage "$(basename "$0")"
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
    
    if [ -z "$DIRECTORY" ]; then
        error_exit "Output directory is required. Use -o option."
    fi
    
    # Export variables for use in calling script
    export GRAFANA_URL
    export GRAFANA_TOKEN
    export DIRECTORY
    export DASHBOARD_UID
    export VERBOSE
}

# Print usage information
print_dashboard_export_usage() {
    local script_name=$1
    
    cat << EOF
Usage: $script_name [OPTIONS]

Export Grafana dashboards to individual JSON files.

Options:
  -u URL       Grafana base URL (required)
               Example: https://ecate.int.ingv.it
  -t TOKEN     Grafana API token for authorization (required)
  -o DIR       Output directory for dashboard files (required)
  -d UID       Export only a specific dashboard by UID (optional)
  -v           Enable verbose mode (show curl commands and detailed logs)
  -h           Display this help message

Examples:
  # Export all dashboards
  $script_name -u https://ecate.int.ingv.it -t YOUR_TOKEN -o ./dashboards

  # Export single dashboard by UID
  $script_name -u https://ecate.int.ingv.it -t YOUR_TOKEN -o ./dashboards -d abc123xyz

  # Export with verbose logging
  $script_name -u http://localhost:3000 -t glsa_token123 -o ./backup -v

EOF
}

# Parse command line options
parse_dashboard_export_options "$@"

# Set OUTPUT_DIR from parsed DIRECTORY variable
OUTPUT_DIR="$DIRECTORY"

# Remove trailing slash from GRAFANA_URL if present
GRAFANA_URL="${GRAFANA_URL%/}"

# Validate inputs
info_msg "Starting Grafana dashboard export..."
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
test_grafana_connection "${GRAFANA_URL}/api/search" "$GRAFANA_TOKEN"

# Export dashboards
info_msg "Exporting dashboards..."

if [ -n "$DASHBOARD_UID" ]; then
    # Export single dashboard by UID
    info_msg "Export mode: Single dashboard (UID: $DASHBOARD_UID)"
    
    # Fetch dashboard
    CURL_CMD="curl -s -H \"Authorization: Bearer [REDACTED]\" \"${GRAFANA_URL}/api/dashboards/uid/${DASHBOARD_UID}\""
    verbose_cmd "$CURL_CMD"
    
    DASHBOARD_JSON=$(curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" "${GRAFANA_URL}/api/dashboards/uid/${DASHBOARD_UID}")
    
    if [ $? -ne 0 ]; then
        error_exit "Failed to fetch dashboard with UID: $DASHBOARD_UID"
    fi
    
    # Check if response is valid JSON
    if ! echo "$DASHBOARD_JSON" | jq empty 2>/dev/null; then
        error_exit "Invalid JSON response for dashboard UID: $DASHBOARD_UID"
    fi
    
    # Check if dashboard was found
    if echo "$DASHBOARD_JSON" | jq -e '.message' > /dev/null 2>&1; then
        ERROR_MSG=$(echo "$DASHBOARD_JSON" | jq -r '.message')
        error_exit "Dashboard not found: $ERROR_MSG"
    fi
    
    # Extract dashboard metadata
    DASHBOARD_TITLE=$(echo "$DASHBOARD_JSON" | jq -r '.meta.slug // .dashboard.title // "unknown"' | tr ' ' '_' | tr '/' '_')
    DASHBOARD_UID_FROM_JSON=$(echo "$DASHBOARD_JSON" | jq -r '.dashboard.uid // "unknown"')
    
    OUTPUT_FILE="$OUTPUT_DIR/dashboard_${DASHBOARD_UID_FROM_JSON}_${DASHBOARD_TITLE}.json"
    
    verbose_msg "Processing dashboard: $DASHBOARD_TITLE (UID: $DASHBOARD_UID_FROM_JSON)"
    verbose_cmd "echo \"\$DASHBOARD_JSON\" | jq '.' > \"$OUTPUT_FILE\""
    
    # Save dashboard to file with pretty formatting
    echo "$DASHBOARD_JSON" | jq '.' > "$OUTPUT_FILE"
    
    if [ $? -eq 0 ]; then
        success_msg "Dashboard exported successfully!"
        success_msg "Exported to: $OUTPUT_FILE"
    else
        error_exit "Failed to export dashboard"
    fi
    
else
    # Export all dashboards
    info_msg "Export mode: All dashboards"
    
    # Fetch dashboard list
    TEMP_FILE=$(mktemp)
    verbose_msg "Created temporary file: $TEMP_FILE"
    
    CURL_CMD="curl -s -H \"Authorization: Bearer [REDACTED]\" \"${GRAFANA_URL}/api/search?type=dash-db\""
    verbose_cmd "$CURL_CMD"
    
    curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" "${GRAFANA_URL}/api/search?type=dash-db" > "$TEMP_FILE"
    
    # Check if the request was successful
    if [ $? -ne 0 ]; then
        rm -f "$TEMP_FILE"
        error_exit "Failed to fetch dashboards from Grafana API"
    fi
    
    # Check if response is valid JSON
    if ! jq empty "$TEMP_FILE" 2>/dev/null; then
        rm -f "$TEMP_FILE"
        error_exit "Invalid JSON response from Grafana API"
    fi
    
    # Count dashboards
    DASHBOARD_COUNT=$(jq 'length' "$TEMP_FILE")
    
    if [ "$DASHBOARD_COUNT" -eq 0 ]; then
        rm -f "$TEMP_FILE"
        warning_msg "No dashboards found in Grafana"
        exit 0
    fi
    
    info_msg "Found $DASHBOARD_COUNT dashboard(s)"
    
    # Clean output directory (remove old dashboard files)
    info_msg "Cleaning output directory..."
    verbose_cmd "rm -f \"$OUTPUT_DIR\"/dashboard_*.json"
    rm -f "$OUTPUT_DIR"/dashboard_*.json
    
    # Export each dashboard to a separate file
    COUNTER=1
    SUCCESS_COUNT=0
    FAILED_COUNT=0
    
    jq -c -M '.[]' "$TEMP_FILE" | while read -r dashboard_summary; do
        DASHBOARD_UID=$(echo "$dashboard_summary" | jq -r '.uid')
        DASHBOARD_TITLE=$(echo "$dashboard_summary" | jq -r '.title // "unknown"' | tr ' ' '_' | tr '/' '_')
        
        verbose_msg "Fetching dashboard: $DASHBOARD_TITLE (UID: $DASHBOARD_UID)"
        
        # Fetch full dashboard
        DASHBOARD_JSON=$(curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" "${GRAFANA_URL}/api/dashboards/uid/${DASHBOARD_UID}")
        
        if [ $? -ne 0 ]; then
            warning_msg "  Failed to fetch dashboard: $DASHBOARD_TITLE"
            continue
        fi
        
        # Check if response is valid JSON
        if ! echo "$DASHBOARD_JSON" | jq empty 2>/dev/null; then
            warning_msg "  Invalid JSON for dashboard: $DASHBOARD_TITLE"
            continue
        fi
        
        # Extract slug from meta if available
        DASHBOARD_SLUG=$(echo "$DASHBOARD_JSON" | jq -r '.meta.slug // empty')
        if [ -n "$DASHBOARD_SLUG" ]; then
            OUTPUT_FILE="$OUTPUT_DIR/dashboard_${DASHBOARD_UID}_${DASHBOARD_SLUG}.json"
        else
            OUTPUT_FILE="$OUTPUT_DIR/dashboard_${DASHBOARD_UID}_${DASHBOARD_TITLE}.json"
        fi
        
        verbose_cmd "echo \"\$DASHBOARD_JSON\" | jq '.' > \"$OUTPUT_FILE\""
        
        # Save dashboard to file with pretty formatting
        echo "$DASHBOARD_JSON" | jq '.' > "$OUTPUT_FILE"
        
        if [ $? -eq 0 ]; then
            info_msg "  Exported: $(basename "$OUTPUT_FILE")"
        else
            warning_msg "  Failed to export dashboard: $DASHBOARD_TITLE"
        fi
        
        COUNTER=$((COUNTER + 1))
    done
    
    # Clean up temporary file
    verbose_msg "Cleaning up temporary file: $TEMP_FILE"
    rm -f "$TEMP_FILE"
    
    success_msg "Dashboard export completed!"
    success_msg "Exported dashboards to: $OUTPUT_DIR"
fi