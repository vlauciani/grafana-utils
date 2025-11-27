# Grafana Datasource Export/Import Scripts

Bash scripts to export and import Grafana datasources using the Grafana API.

## Overview

- **Export** all datasources from Grafana to individual JSON files
- **Import** datasources from JSON files back into Grafana
- **Add passwords** to exported datasource configurations

Useful for backing up, migrating, and version controlling datasource configurations.

## Prerequisites

**Required Tools:**
- `curl` - HTTP requests
- `jq` - JSON processing
- `bash` - Version 4.0 or higher

**Grafana Access:**
- API token with Admin permissions
- Access to Grafana API endpoint

### Installation

```bash
# macOS
brew install curl jq

# Ubuntu/Debian
sudo apt-get install curl jq

# CentOS/RHEL
sudo yum install curl jq
```

### Creating API Token

1. Log in to Grafana
2. Go to **Configuration** → **API Keys** (or **Service Accounts**)
3. Click **Add API Key** / **Create service account token**
4. Set role to **Admin**
5. Copy the generated token

## Scripts

### `datasource_export.sh`
Export all datasources to JSON files.

**Options:**
- `-u URL` - Grafana API endpoint (required)
- `-t TOKEN` - API token (required)
- `-o DIR` - Output directory (required)
- `-v` - Verbose mode
- `-h` - Help

### `datasource_import.sh`
Import datasources from JSON files.

**Options:**
- `-u URL` - Grafana API endpoint (required)
- `-t TOKEN` - API token (required)
- `-o DIR` - Input directory (use `-o` OR `-f`)
- `-f FILE` - Single file to import (use `-o` OR `-f`)
- `-v` - Verbose mode
- `-h` - Help

### `datasource_add_password.sh`
Add passwords to datasource JSON files.

**Options:**
- `-f FILE` - Input JSON file (required)
- `-p PASSWORD` - Password to add (required)
- `-o FILE` - Output file (optional, defaults to overwrite)
- `-v` - Verbose mode
- `-h` - Help

## Usage

### Export
```bash
./datasource_export.sh -u <grafana_url> -t <token> -o <output_dir>
```

### Import from Directory
```bash
./datasource_import.sh -u <grafana_url> -t <token> -o <input_dir>
```

### Import Single File
```bash
./datasource_import.sh -u <grafana_url> -t <token> -f <file.json>
```

### Add Password
```bash
# IMPORTANT: Always use single quotes around passwords to prevent shell expansion
./datasource_add_password.sh -f <file.json> -p 'password'
```

## Examples

### Basic Export/Import
```bash
# Export from production
./datasource_export.sh \
  -u https://grafana.example.com \
  -t glsa_YourToken \
  -o ./backup

# Import to staging
./datasource_import.sh \
  -u https://staging.example.com \
  -t glsa_StagingToken \
  -o ./backup
```

### Complete Migration Workflow
```bash
# 1. Export
./datasource_export.sh -u $PROD_URL -t $PROD_TOKEN -o ./migration

# 2. Add passwords (use single quotes to protect special characters)
./datasource_add_password.sh -f ./migration/datasource_2_PostgreSQL.json -p 'MySecretP@ssw0rd$123!'

# 3. Import
./datasource_import.sh -u $NEW_URL -t $NEW_TOKEN -o ./migration
```

### Timestamped Backup
```bash
BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
./datasource_export.sh -u $GRAFANA_URL -t $TOKEN -o "$BACKUP_DIR"
```

## Troubleshooting

### Common Issues

**"Required programs not found"**
- Install `curl` and `jq` (see Installation section)

**"Failed to connect to Grafana API"**
- Check URL for typos
- Verify network connectivity
- Test manually: `curl -H "Authorization: Bearer TOKEN" URL`

**"HTTP 401 - Unauthorized"**
- Token is invalid or expired
- Token lacks Admin permissions
- Regenerate token with Admin role

**"HTTP 409 - Conflict"**
- Datasource already exists (normal behavior)
- Script skips existing datasources automatically

**Password issues**
- **CRITICAL: Always use single quotes** around passwords to prevent shell expansion of special characters (`$`, `!`, `*`, etc.)
- Example: `./datasource_add_password.sh -f file.json -p 'P@ssw0rd!#$123'`
- For environment variables, set with single quotes: `export PASSWORD='P@ssw0rd!#$123'`, then use: `-p "$PASSWORD"`
- Validate JSON after: `jq empty file.json`

### Debug Mode
```bash
# Enable verbose logging
./datasource_export.sh -u URL -t TOKEN -o DIR -v

# Bash debug mode
bash -x ./datasource_export.sh -u URL -t TOKEN -o DIR
```

## File Naming

Exported files follow this pattern:
```
datasource_{id}_{name}.json
```

Example: `datasource_1_Prometheus.json`

## Security Notes

⚠️ **Important:**

- **Never commit tokens to version control**
- **Use environment variables for automation**
- **Exported files may contain sensitive data**
- **Secure file permissions:** `chmod 600 *.json`

**Using environment variables:**
```bash
export GRAFANA_TOKEN="glsa_YourToken"
export GRAFANA_URL="https://grafana.example.com

./datasource_export.sh -u "$GRAFANA_URL" -t "$GRAFANA_TOKEN" -o ./backup
```

**Add to `.gitignore`:**
```
datasources/
backups/
.env
**/datasource_*.json
```

## License

These scripts are provided as-is for managing Grafana datasources.

## Contributors

Thanks to all contributors!

<a href="https://github.com/vlauciani/grafana-utils/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=vlauciani/grafana-utils" />
</a>

## Author

(c) 2025 Valentino Lauciani vlauciani[at]gmail.it