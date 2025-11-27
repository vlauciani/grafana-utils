# Grafana Datasource Export/Import Scripts

A set of bash scripts to export and import Grafana datasources using the Grafana API.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Scripts](#scripts)
- [Usage](#usage)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)

## Overview

These scripts allow you to:
- **Export** all datasources from a Grafana instance to individual JSON files
- **Import** datasources from JSON files back into a Grafana instance

This is useful for:
- Backing up datasource configurations
- Migrating datasources between Grafana instances
- Version controlling datasource configurations
- Disaster recovery

## Prerequisites

Before using these scripts, ensure you have:

1. **Required Tools:**
   - `curl` - Command line tool for HTTP requests
   - `jq` - JSON processor for parsing and formatting JSON data
   - `bash` - Bash shell (version 4.0 or higher)

2. **Grafana Access:**
   - A Grafana API token with appropriate permissions
   - Access to the Grafana API endpoint

### Installing Prerequisites

**On macOS:**
```bash
brew install curl jq
```

**On Ubuntu/Debian:**
```bash
sudo apt-get install curl jq
```

**On CentOS/RHEL:**
```bash
sudo yum install curl jq
```

### Creating a Grafana API Token

1. Log in to your Grafana instance
2. Go to **Configuration** → **API Keys** (or **Service Accounts** in newer versions)
3. Click **Add API Key** or **Create service account token**
4. Give it a name (e.g., "Datasource Backup")
5. Set the role to **Admin** (required for datasource management)
6. Set an expiration date or leave it empty for no expiration
7. Click **Add** and copy the generated token

## Scripts

### 1. `config.sh`
Common configuration file containing:
- Validation functions (URL, token, directories)
- Error handling and logging
- Connection testing
- Required program checks

### 2. `datasource_export.sh`
Exports all datasources from Grafana to individual JSON files.

**Options:**
- `-u URL` - Grafana API endpoint (required, e.g., `https://ecate.int.ingv.it/api/datasources`)
- `-t TOKEN` - Your Grafana API token (required)
- `-o DIR` - Output directory where datasource files will be saved (required)
- `-v` - Enable verbose mode (show curl commands and detailed logs)
- `-h` - Display help message

### 3. `datasource_import.sh`
Imports datasources from JSON files into Grafana.

**Options:**
- `-u URL` - Grafana API endpoint (required, e.g., `https://ecate.int.ingv.it/api/datasources`)
- `-t TOKEN` - Your Grafana API token (required)
- `-o DIR` - Input directory containing datasource JSON files (use `-o` OR `-f`, not both)
- `-f FILE` - Single datasource JSON file to import (use `-o` OR `-f`, not both)
- `-v` - Enable verbose mode (show curl commands and detailed logs)
- `-h` - Display help message

### 4. `datasource_add_password.sh`
Adds passwords to exported datasource JSON files by adding the `secureJsonData.password` field.

**Options:**
- `-f FILE` - Input JSON file to modify (required)
- `-p PASSWORD` - Password to add to the datasource (required)
- `-o FILE` - Output file path (optional, defaults to overwriting input file)
- `-v` - Enable verbose mode (show detailed processing information)
- `-h` - Display help message

**Security Note:** Be careful when specifying passwords in command line as they may be visible in shell history. Consider using environment variables or reading from secure files.

## Usage

### Exporting Datasources

```bash
./datasource_export.sh -u <grafana_url> -t <grafana_token> -o <output_directory>
```

**What it does:**
1. Validates prerequisites and connection
2. Fetches all datasources from Grafana
3. Creates individual JSON files for each datasource
4. Names files as `datasource_{id}_{name}.json`
5. Cleans old files from the output directory

### Importing Datasources

**From a directory:**
```bash
./datasource_import.sh -u <grafana_url> -t <grafana_token> -o <input_directory>
```

**From a single file:**
```bash
./datasource_import.sh -u <grafana_url> -t <grafana_token> -f <datasource_file.json>
```

**What it does:**
1. Validates prerequisites and connection
2. Reads JSON file(s) from the specified directory or single file
3. Removes `id` and `uid` fields to avoid conflicts
4. Imports each datasource via POST request
5. Provides detailed import summary

### Adding Password to Datasources

```bash
./datasource_add_password.sh -f <datasource_file.json> -p <password>
```

**What it does:**
1. Validates the input JSON file
2. Adds the `secureJsonData.password` field with the specified password
3. Validates the output is still valid JSON
4. Saves to output file (overwrites input by default)
5. Displays the final JSON content

## Examples

### Example 1: Export from Production Grafana

```bash
# Export all datasources from production Grafana
./datasource_export.sh \
  -u https://ecate.int.ingv.it/api/datasources \
  -t glsa_YourTokenHere1234567890 \
  -o ./datasources_backup
```

**Output:**
```
Starting Grafana datasource export...
========================================
All required programs (curl, jq) are available.
Grafana URL validated: https://ecate.int.ingv.it/api/datasources
Grafana token validated.
Directory created: ./datasources_backup
Testing Grafana API connection...
Successfully connected to Grafana API
Exporting datasources...
Found 3 datasource(s)
Cleaning output directory...
  Exported: datasource_1_Prometheus.json
  Exported: datasource_2_Loki.json
  Exported: datasource_3_PostgreSQL.json
SUCCESS: Datasource export completed!
SUCCESS: Exported 3 datasource(s) to: ./datasources_backup
```

### Example 2: Import to Staging Grafana

**Import from directory:**
```bash
# Import all datasources from directory to staging Grafana
./datasource_import.sh \
  -u http://localhost:3000/api/datasources \
  -t glsa_StagingTokenHere1234567890 \
  -o ./datasources_backup
```

**Import single file:**
```bash
# Import a single datasource file to staging Grafana
./datasource_import.sh \
  -u http://localhost:3000/api/datasources \
  -t glsa_StagingTokenHere1234567890 \
  -f ./datasources_backup/datasource_1_Prometheus.json
```

**Output:**
```
Starting Grafana datasource import...
========================================
All required programs (curl, jq) are available.
Grafana URL validated: http://localhost:3000/api/datasources
Grafana token validated.
Directory exists: ./datasources_backup
Testing Grafana API connection...
Successfully connected to Grafana API
Importing datasources...
Found 3 datasource file(s) to import
Processing: datasource_1_Prometheus.json
  Imported: Prometheus (HTTP 200)
Processing: datasource_2_Loki.json
  Imported: Loki (HTTP 201)
Processing: datasource_3_PostgreSQL.json
  Already exists: PostgreSQL (HTTP 409)

Import Summary:
===============
Total files:      3
Successfully imported: 2
Skipped/Exists:        1
SUCCESS: Datasource import completed successfully!
```

### Example 3: Migrate Between Environments

```bash
# Step 1: Export from production
./datasource_export.sh \
  -u https://prod.example.com/api/datasources \
  -t glsa_ProdToken \
  -o ./prod_datasources

# Step 2: Import to staging
./datasource_import.sh \
  -u https://staging.example.com/api/datasources \
  -t glsa_StagingToken \
  -o ./prod_datasources

# Step 3: Import to development
./datasource_import.sh \
  -u http://localhost:3000/api/datasources \
  -t glsa_DevToken \
  -o ./prod_datasources
```

### Example 4: Backup with Timestamp

```bash
# Create dated backup
BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
./datasource_export.sh \
  -u https://ecate.int.ingv.it/api/datasources \
  -t glsa_YourToken \
  -o "$BACKUP_DIR"
```

### Example 5: Using Verbose Mode for Debugging

```bash
# Export with verbose logging to see curl commands
./datasource_export.sh \
  -u https://ecate.int.ingv.it/api/datasources \
  -t glsa_YourToken \
  -o ./datasources \
  -v

# Import with verbose logging to troubleshoot issues
./datasource_import.sh \
  -u http://localhost:3000/api/datasources \
  -t glsa_Token \
  -f ./datasources/datasource_1_Prometheus.json \
  -v
```

**Verbose output includes:**
- Curl commands being executed (with redacted tokens)
- Temporary file paths
- HTTP response codes
- Detailed processing information
- Full error response bodies

### Example 6: Adding Passwords to Exported Datasources

After exporting datasources, you may need to add passwords for datasources that require authentication:

```bash
# Add password to a single datasource file (overwrites original)
./datasource_add_password.sh \
  -f ./datasources/datasource_2_psqlha1v.int.ingv.it.json \
  -p "MySecretPassword"

# Add password and save to a new file
./datasource_add_password.sh \
  -f ./datasources/datasource_2_psqlha1v.int.ingv.it.json \
  -p "MySecretPassword" \
  -o ./datasources/datasource_2_with_password.json

# Add password with verbose output
./datasource_add_password.sh \
  -f ./datasources/datasource_2_psqlha1v.int.ingv.it.json \
  -p "MySecretPassword" \
  -v
```

**Output:**
```
Starting password addition to datasource JSON...
================================================
All required programs (curl, jq) are available.
Input file exists: ./datasources/datasource_2_psqlha1v.int.ingv.it.json
Input file is valid JSON
Adding password to secureJsonData.password...
SUCCESS: Password added successfully

Final JSON content:
===================
{
  "id": 2,
  "uid": "af53pk5wjupkwe",
  "orgId": 1,
  "name": "psqlha1v.int.ingv.it",
  "type": "grafana-postgresql-datasource",
  "typeName": "PostgreSQL",
  "typeLogoUrl": "public/app/plugins/datasource/grafana-postgresql-datasource/img/postgresql_logo.svg",
  "access": "proxy",
  "url": "psqlha1v.int.ingv.it",
  "user": "zabbix_monitor",
  "database": "",
  "basicAuth": false,
  "isDefault": false,
  "jsonData": {
    "connMaxLifetime": 14400,
    "database": "postgres",
    "maxIdleConns": 100,
    "maxIdleConnsAuto": true,
    "maxOpenConns": 100,
    "postgresVersion": 1500,
    "sslmode": "disable"
  },
  "readOnly": false,
  "secureJsonData": {
    "password": "MySecretPassword"
  }
}

SUCCESS: Password addition completed successfully!
Output file: ./datasources/datasource_2_psqlha1v.int.ingv.it.json
WARNING: SECURITY NOTE: The password is now stored in the JSON file.
WARNING: Ensure this file is stored securely and not committed to version control.
```

### Example 7: Complete Workflow with Password Addition

```bash
# Step 1: Export datasources from production
./datasource_export.sh \
  -u https://ecate.int.ingv.it/api/datasources \
  -t glsa_ProdToken \
  -o ./datasources_backup

# Step 2: Add passwords to datasources that need them
./datasource_add_password.sh \
  -f ./datasources_backup/datasource_2_PostgreSQL.json \
  -p "postgres_password"

./datasource_add_password.sh \
  -f ./datasources_backup/datasource_3_MySQL.json \
  -p "mysql_password"

# Step 3: Import to new Grafana instance with passwords
./datasource_import.sh \
  -u http://new-grafana.example.com/api/datasources \
  -t glsa_NewToken \
  -o ./datasources_backup
```

### Example 8: Using Environment Variables for Security

To avoid exposing passwords in command history:

```bash
# Set password in environment variable
export DB_PASSWORD="MySecretPassword"

# Use the environment variable
./datasource_add_password.sh \
  -f ./datasources/datasource_2_psqlha1v.int.ingv.it.json \
  -p "$DB_PASSWORD"

# Clear the variable after use
unset DB_PASSWORD
```

## Troubleshooting

### Common Issues

#### 1. "Required programs not found"
**Problem:** `curl` or `jq` is not installed.

**Solution:**
```bash
# Install on macOS
brew install curl jq

# Install on Ubuntu/Debian
sudo apt-get install curl jq
```

#### 2. "Failed to connect to Grafana API"
**Problem:** Cannot reach the Grafana API endpoint.

**Possible causes:**
- Incorrect URL (check for typos)
- Network connectivity issues
- Grafana server is down
- Firewall blocking access

**Solution:**
```bash
# Test connection manually
curl -H "Authorization: Bearer YOUR_TOKEN" https://your-grafana.com/api/datasources

# Or use the help option to check command syntax
./datasource_export.sh -h
./datasource_import.sh -h
```

#### 3. "HTTP status code: 401"
**Problem:** Authentication failed.

**Possible causes:**
- Invalid or expired token
- Token doesn't have sufficient permissions

**Solution:**
- Generate a new API token with Admin role
- Verify the token is copied correctly (no extra spaces)

#### 4. "Cannot specify both -o and -f"
**Problem:** Both directory (-o) and file (-f) options were specified.

**Solution:** Use only one option:
```bash
# Either import from directory
./datasource_import.sh -u URL -t TOKEN -o ./datasources

# OR import single file
./datasource_import.sh -u URL -t TOKEN -f ./datasource_1_Prometheus.json
```

#### 5. "HTTP status code: 409" during import
**Problem:** Datasource already exists with the same name.

**This is normal:** The script skips existing datasources automatically. If you want to update, you'll need to delete the existing datasource first or modify the name in the JSON file.

#### 6. "Directory does not exist" or "Input file does not exist"
**Problem:** Trying to import from a non-existent directory.

**Solution:**
```bash
# Check directory exists
ls -la ./datasources_backup

# If not, check the path
pwd
```

#### 7. "Invalid JSON format"
**Problem:** Corrupted or invalid JSON file.

**Solution:**
```bash
# Validate JSON file
jq empty datasources/datasource_1_Prometheus.json

# If invalid, re-export from source
```

#### 8. Password Addition Issues

**Problem:** Password not being added correctly or file becomes corrupted.

**Possible causes:**
- Input file is not valid JSON
- Insufficient permissions to write output file
- Special characters in password not properly escaped

**Solution:**
```bash
# Validate input file first
jq empty ./datasources/datasource_2_psqlha1v.int.ingv.it.json

# Run with verbose mode to see details
./datasource_add_password.sh -f ./datasources/datasource_2_psqlha1v.int.ingv.it.json -p "password" -v

# If password has special characters, use single quotes
./datasource_add_password.sh -f ./datasources/datasource_2_psqlha1v.int.ingv.it.json -p 'P@ssw0rd!#$'

# Save to new file first to avoid overwriting
./datasource_add_password.sh -f ./datasources/datasource_2_psqlha1v.int.ingv.it.json -p "password" -o ./datasources/test.json
```

### Getting Help

If you encounter issues:

1. **Check usage and options:**
   ```bash
   # Display help for export script
   ./datasource_export.sh -h
   
   # Display help for import script
   ./datasource_import.sh -h
   ```

2. **Use verbose mode to see detailed execution:**
   ```bash
   # Run export with verbose logging
   ./datasource_export.sh -u URL -t TOKEN -o DIR -v
   
   # Run import with verbose logging
   ./datasource_import.sh -u URL -t TOKEN -o DIR -v
   ```

3. **Run with bash debug mode for even more detail:**
   ```bash
   bash -x ./datasource_export.sh -u URL -t TOKEN -o DIR
   ```

4. **Check the JSON files:**
   ```bash
   # Pretty print a datasource file
   jq '.' datasources/datasource_1_Prometheus.json
   ```

5. **Verify API access:**
   ```bash
   # Test API manually
   curl -H "Authorization: Bearer YOUR_TOKEN" \
        https://your-grafana.com/api/datasources
   ```

6. **Check logs:**
   - Look at Grafana server logs for API errors
   - Review script output for detailed error messages

## File Naming Convention

Exported files follow this pattern:
```
datasource_{id}_{name}.json
```

Where:
- `{id}` - Datasource ID from Grafana
- `{name}` - Datasource name (spaces and slashes replaced with underscores)

Example:
- `datasource_1_Prometheus.json`
- `datasource_2_My_PostgreSQL_DB.json`

## Security Notes

⚠️ **Important Security Considerations:**

1. **Protect your API tokens:**
   - Never commit tokens to version control
   - Store tokens in secure password managers
   - Use environment variables for automation:
     ```bash
     export GRAFANA_TOKEN="glsa_YourToken"
     export GRAFANA_URL="https://ecate.int.ingv.it/api/datasources"
     
     # Use in scripts
     ./datasource_export.sh -u "$GRAFANA_URL" -t "$GRAFANA_TOKEN" -o ./backup
     ```

2. **Review exported files:**
   - Datasource configurations may contain sensitive information
   - Passwords and secrets might be included in the exports (especially after using `datasource_add_password.sh`)
   - Store backups securely and encrypt if possible

3. **Token permissions:**
   - Use the principle of least privilege
   - Create separate tokens for export and import if possible
   - Set appropriate expiration dates

4. **Password management:**
   - Avoid typing passwords directly in command line (visible in shell history)
   - Use environment variables or secure files for password input
   - Add `datasource_*.json` to `.gitignore` to prevent committing sensitive data
   - Consider using `.env` files with restricted permissions (chmod 600)
   - Clear shell history after entering sensitive commands:
     ```bash
     history -c  # Clear current session history
     ```

5. **Secure file permissions:**
   ```bash
   # Restrict permissions on datasource files with passwords
   chmod 600 ./datasources/*.json
   
   # Restrict directory permissions
   chmod 700 ./datasources
   ```

## Best Practices

1. **Export and Backup Workflow:**
   ```bash
   # Create dated backup directory
   BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
   
   # Export datasources
   ./datasource_export.sh -u "$GRAFANA_URL" -t "$GRAFANA_TOKEN" -o "$BACKUP_DIR"
   
   # Add passwords to specific datasources
   for ds in "$BACKUP_DIR"/datasource_*PostgreSQL*.json; do
     ./datasource_add_password.sh -f "$ds" -p "$POSTGRES_PASSWORD"
   done
   
   # Compress and encrypt backup
   tar czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"
   gpg -c "$BACKUP_DIR.tar.gz"  # Encrypt with password
   rm -rf "$BACKUP_DIR" "$BACKUP_DIR.tar.gz"  # Remove unencrypted files
   ```

2. **Migration Workflow:**
   ```bash
   # Export from source
   ./datasource_export.sh -u "$SOURCE_URL" -t "$SOURCE_TOKEN" -o ./migration
   
   # Add passwords (use environment variables)
   source .env  # Contains DB_PASSWORD1, DB_PASSWORD2, etc.
   ./datasource_add_password.sh -f ./migration/datasource_2_DB1.json -p "$DB_PASSWORD1"
   ./datasource_add_password.sh -f ./migration/datasource_3_DB2.json -p "$DB_PASSWORD2"
   
   # Import to destination
   ./datasource_import.sh -u "$DEST_URL" -t "$DEST_TOKEN" -o ./migration
   
   # Clean up
   rm -rf ./migration
   ```

3. **Version Control:**
   - Never commit files with passwords
   - Add to `.gitignore`:
     ```
     grafana-utils/datasources/
     grafana-utils/backups/
     grafana-utils/.env
     **/datasource_*.json
     ```

## License

These scripts are provided as-is for managing Grafana datasources.