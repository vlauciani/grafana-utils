#!/bin/bash

# Script to add password to Grafana datasource JSON file
# Usage: ./datasource_add_password.sh -f <input_file> -p <password>

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the common configuration file
source "$SCRIPT_DIR/config.sh"

# Print usage information
print_usage() {
    local script_name=$1
    
    cat << EOF
Usage: $script_name [OPTIONS]

Add password to Grafana datasource JSON file by adding secureJsonData.password field.

Options:
  -f FILE      Input JSON file to modify (required)
  -p PASSWORD  Password to add to the datasource (required)
  -o FILE      Output file path (optional, defaults to overwriting input file)
  -v           Enable verbose mode (show detailed processing information)
  -h           Display this help message

Examples:
  # Add password and overwrite original file
  $script_name -f ./datasources/datasource_2_psqlha1v.int.ingv.it.json -p "MySecretPassword"
  
  # Add password and save to new file
  $script_name -f ./datasources/datasource_2_psqlha1v.int.ingv.it.json -p "MySecretPassword" -o ./datasources/updated_datasource.json
  
  # Add password with verbose output
  $script_name -f ./datasources/datasource_2_psqlha1v.int.ingv.it.json -p "MySecretPassword" -v

Security Note:
  Be careful when specifying passwords in command line as they may be visible in shell history.
  Consider using environment variables or reading from secure files.

EOF
}

# Parse command line options
parse_options() {
    # If no arguments provided, show help
    if [ $# -eq 0 ]; then
        print_usage "$(basename "$0")"
        exit 0
    fi
    
    # Initialize variables
    INPUT_FILE=""
    OUTPUT_FILE=""
    PASSWORD=""
    VERBOSE="false"
    
    # Parse options
    while getopts "f:p:o:vh" opt; do
        case $opt in
            f)
                INPUT_FILE="$OPTARG"
                ;;
            p)
                PASSWORD="$OPTARG"
                ;;
            o)
                OUTPUT_FILE="$OPTARG"
                ;;
            v)
                VERBOSE="true"
                ;;
            h)
                print_usage "$(basename "$0")"
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
    if [ -z "$INPUT_FILE" ]; then
        error_exit "Input file is required. Use -f option."
    fi
    
    if [ -z "$PASSWORD" ]; then
        error_exit "Password is required. Use -p option."
    fi
    
    # If no output file specified, use input file (overwrite)
    if [ -z "$OUTPUT_FILE" ]; then
        OUTPUT_FILE="$INPUT_FILE"
        verbose_msg "No output file specified, will overwrite input file"
    fi
    
    # Export variables for use in script
    export INPUT_FILE
    export OUTPUT_FILE
    export PASSWORD
    export VERBOSE
}

# Main script execution
main() {
    # Parse command line options
    parse_options "$@"
    
    # Start processing
    info_msg "Starting password addition to datasource JSON..."
    info_msg "================================================"
    
    # Show verbose mode status
    if [ "$VERBOSE" = "true" ]; then
        info_msg "Verbose mode: ENABLED"
    fi
    
    # Check required programs
    check_required_programs
    
    # Validate input file exists
    if [ ! -f "$INPUT_FILE" ]; then
        error_exit "Input file does not exist: $INPUT_FILE"
    fi
    info_msg "Input file exists: $INPUT_FILE"
    
    # Validate input file is valid JSON
    if ! jq empty "$INPUT_FILE" 2>/dev/null; then
        error_exit "Input file is not valid JSON: $INPUT_FILE"
    fi
    info_msg "Input file is valid JSON"
    
    # Get datasource name for logging
    DS_NAME=$(jq -r '.name // "unknown"' "$INPUT_FILE")
    verbose_msg "Datasource name: $DS_NAME"
    
    # Create temporary file for processing
    TEMP_FILE=$(mktemp)
    verbose_msg "Created temporary file: $TEMP_FILE"
    
    # Add password to secureJsonData field
    info_msg "Adding password to secureJsonData.password..."
    
    # Use jq to add the password field
    verbose_cmd "jq '.secureJsonData.password = \"[REDACTED]\"' \"$INPUT_FILE\" > \"$TEMP_FILE\""
    
    jq --arg password "$PASSWORD" '.secureJsonData.password = $password' "$INPUT_FILE" > "$TEMP_FILE"
    
    # Check if jq command was successful
    if [ $? -ne 0 ]; then
        rm -f "$TEMP_FILE"
        error_exit "Failed to add password to JSON file"
    fi
    
    # Validate the output is still valid JSON
    if ! jq empty "$TEMP_FILE" 2>/dev/null; then
        rm -f "$TEMP_FILE"
        error_exit "Output is not valid JSON after password addition"
    fi
    success_msg "Password added successfully"
    
    # Move temporary file to output file
    verbose_msg "Moving temporary file to output file: $OUTPUT_FILE"
    mv "$TEMP_FILE" "$OUTPUT_FILE"
    
    if [ $? -ne 0 ]; then
        rm -f "$TEMP_FILE"
        error_exit "Failed to write output file: $OUTPUT_FILE"
    fi
    
    # Print the final JSON
    info_msg ""
    info_msg "Final JSON content:"
    info_msg "==================="
    jq '.' "$OUTPUT_FILE"
    
    # Summary
    info_msg ""
    success_msg "Password addition completed successfully!"
    info_msg "Output file: $OUTPUT_FILE"
    
    # Security warning
    warning_msg "SECURITY NOTE: The password is now stored in the JSON file."
    warning_msg "Ensure this file is stored securely and not committed to version control."
}

# Run main function
main "$@"