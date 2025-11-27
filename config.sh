#!/bin/bash

# Common configuration and functions for Grafana datasource scripts

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print error message and exit
error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

# Print success message
success_msg() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

# Print warning message
warning_msg() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

# Print info message
info_msg() {
    echo -e "$1"
}

# Print verbose message (only if VERBOSE is enabled)
verbose_msg() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${YELLOW}[VERBOSE]${NC} $1"
    fi
}

# Log command execution in verbose mode
verbose_cmd() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${YELLOW}[CMD]${NC} $*"
    fi
}

# Check if required programs are installed
check_required_programs() {
    local missing_programs=()
    
    # Check for curl
    if ! command -v curl &> /dev/null; then
        missing_programs+=("curl")
    fi
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        missing_programs+=("jq")
    fi
    
    if [ ${#missing_programs[@]} -gt 0 ]; then
        error_exit "Required programs not found: ${missing_programs[*]}\nPlease install them before running this script."
    fi
    
    info_msg "All required programs (curl, jq) are available."
}

# Validate Grafana URL
validate_grafana_url() {
    local url=$1
    
    if [ -z "$url" ]; then
        error_exit "Grafana URL cannot be empty"
    fi
    
    if [[ ! "$url" =~ ^https?:// ]]; then
        error_exit "Grafana URL must start with http:// or https://"
    fi
    
    info_msg "Grafana URL validated: $url"
}

# Validate Grafana token
validate_grafana_token() {
    local token=$1
    
    if [ -z "$token" ]; then
        error_exit "Grafana token cannot be empty"
    fi
    
    info_msg "Grafana token validated."
}

# Check if directory exists, create if not
ensure_directory_exists() {
    local dir=$1
    local create_if_missing=$2  # true or false
    
    if [ -z "$dir" ]; then
        error_exit "Directory path cannot be empty"
    fi
    
    if [ ! -d "$dir" ]; then
        if [ "$create_if_missing" = "true" ]; then
            mkdir -p "$dir" || error_exit "Failed to create directory: $dir"
            success_msg "Directory created: $dir"
        else
            error_exit "Directory does not exist: $dir"
        fi
    else
        info_msg "Directory exists: $dir"
    fi
}

# Test Grafana API connection
test_grafana_connection() {
    local url=$1
    local token=$2
    
    info_msg "Testing Grafana API connection..."
    
    local response=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $token" "$url" 2>&1)
    local http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ]; then
        success_msg "Successfully connected to Grafana API"
        return 0
    else
        error_exit "Failed to connect to Grafana API. HTTP status code: $http_code"
    fi
}

# Print usage information for export script
print_export_usage() {
    local script_name=$1
    
    cat << EOF
Usage: $script_name [OPTIONS]

Export Grafana datasources to individual JSON files.

Options:
  -u URL       Grafana API endpoint (required)
               Example: https://ecate.int.ingv.it/api/datasources
  -t TOKEN     Grafana API token for authorization (required)
  -o DIR       Output directory for datasource files (required)
  -v           Enable verbose mode (show curl commands and detailed logs)
  -h           Display this help message

Examples:
  $script_name -u https://ecate.int.ingv.it/api/datasources -t YOUR_TOKEN -o ./datasources
  $script_name -u http://localhost:3000/api/datasources -t glsa_token123 -o ./backup
  $script_name -u http://localhost:3000/api/datasources -t glsa_token123 -o ./backup -v

EOF
}

# Print usage information for import script
print_import_usage() {
    local script_name=$1
    
    cat << EOF
Usage: $script_name [OPTIONS]

Import Grafana datasources from individual JSON files.

Options:
  -u URL       Grafana API endpoint (required)
               Example: https://ecate.int.ingv.it/api/datasources
  -t TOKEN     Grafana API token for authorization (required)
  -o DIR       Input directory containing datasource files (use -o OR -f, not both)
  -f FILE      Single datasource JSON file to import (use -o OR -f, not both)
  -v           Enable verbose mode (show curl commands and detailed logs)
  -h           Display this help message

Examples:
  # Import from directory
  $script_name -u https://ecate.int.ingv.it/api/datasources -t YOUR_TOKEN -o ./datasources
  
  # Import single file
  $script_name -u https://ecate.int.ingv.it/api/datasources -t YOUR_TOKEN -f ./datasource_1_Prometheus.json
  
  # Import with verbose logging
  $script_name -u https://ecate.int.ingv.it/api/datasources -t YOUR_TOKEN -o ./datasources -v

EOF
}

# Parse common options for both export and import scripts
# Returns: Sets GRAFANA_URL, GRAFANA_TOKEN, and DIRECTORY variables
parse_common_options() {
    local script_type=$1  # "export" or "import"
    shift
    
    # If no arguments provided, show help
    if [ $# -eq 0 ]; then
        if [ "$script_type" = "export" ]; then
            print_export_usage "$(basename "$0")"
        else
            print_import_usage "$(basename "$0")"
        fi
        exit 0
    fi
    
    # Initialize variables
    GRAFANA_URL=""
    GRAFANA_TOKEN=""
    DIRECTORY=""
    VERBOSE="false"
    
    # Parse options
    while getopts "u:t:o:vh" opt; do
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
            v)
                VERBOSE="true"
                ;;
            h)
                if [ "$script_type" = "export" ]; then
                    print_export_usage "$(basename "$0")"
                else
                    print_import_usage "$(basename "$0")"
                fi
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
        if [ "$script_type" = "export" ]; then
            error_exit "Output directory is required. Use -o option."
        else
            error_exit "Input directory is required. Use -o option."
        fi
    fi
    
    # Export variables for use in calling script
    export GRAFANA_URL
    export GRAFANA_TOKEN
    export DIRECTORY
    export VERBOSE
}

# Parse import-specific options including file option
# Returns: Sets GRAFANA_URL, GRAFANA_TOKEN, DIRECTORY, and INPUT_FILE variables
parse_import_options() {
    # If no arguments provided, show help
    if [ $# -eq 0 ]; then
        print_import_usage "$(basename "$0")"
        exit 0
    fi
    
    # Initialize variables
    GRAFANA_URL=""
    GRAFANA_TOKEN=""
    DIRECTORY=""
    INPUT_FILE=""
    VERBOSE="false"
    
    # Parse options
    while getopts "u:t:o:f:vh" opt; do
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
            v)
                VERBOSE="true"
                ;;
            h)
                print_import_usage "$(basename "$0")"
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
    export VERBOSE
}