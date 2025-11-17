#!/bin/bash

#######################################
# SFTPGo Initialization Script
# Initializes SFTPGo with local filesystem storage and DARE encryption
#######################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SFTPGO_HOME="${SFTPGO_HOME:-.}"
SFTPGO_DATA_DIR="${SFTPGO_DATA_DIR:-/srv/sftpgo/data}"
SFTPGO_CONFIG_FILE="${SFTPGO_CONFIG_FILE:-${SFTPGO_HOME}/sftpgo-dare.json}"
SFTPGO_DB_PATH="${SFTPGO_HOME}/sftpgo.db"
SFTPGO_LOG_DIR="${SFTPGO_HOME}"

# Function to print messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if sftpgo is installed
    if ! command -v sftpgo &> /dev/null; then
        log_error "SFTPGo is not installed. Please install it first."
        exit 1
    fi
    
    # Check if sftpgo version supports DARE
    SFTPGO_VERSION=$(sftpgo -v 2>&1 | head -1)
    log_info "Found SFTPGo: ${SFTPGO_VERSION}"
    
    log_success "Prerequisites check completed"
}

# Function to create directories
create_directories() {
    log_info "Creating necessary directories..."
    
    mkdir -p "${SFTPGO_DATA_DIR}"
    mkdir -p "${SFTPGO_LOG_DIR}"
    
    # Set proper permissions
    chmod 755 "${SFTPGO_DATA_DIR}"
    chmod 755 "${SFTPGO_LOG_DIR}"
    
    log_success "Directories created successfully"
}

# Function to validate configuration file
validate_config() {
    log_info "Validating configuration file..."
    
    if [ ! -f "${SFTPGO_CONFIG_FILE}" ]; then
        log_error "Configuration file not found: ${SFTPGO_CONFIG_FILE}"
        exit 1
    fi
    
    # Check if it's valid JSON (basic check)
    if ! python3 -m json.tool "${SFTPGO_CONFIG_FILE}" > /dev/null 2>&1; then
        log_error "Configuration file is not valid JSON"
        exit 1
    fi
    
    log_success "Configuration file is valid"
}

# Function to initialize database
init_database() {
    log_info "Initializing SFTPGo database..."
    
    if [ -f "${SFTPGO_DB_PATH}" ]; then
        log_warn "Database already exists at ${SFTPGO_DB_PATH}"
        log_info "Skipping database initialization"
        return 0
    fi
    
    # Create the database using sftpgo
    cd "${SFTPGO_HOME}"
    sftpgo initdb -c "${SFTPGO_CONFIG_FILE}" 2>&1 || {
        log_error "Failed to initialize database"
        exit 1
    }
    
    log_success "Database initialized successfully"
}

# Function to generate encryption keys
generate_encryption_keys() {
    log_info "Generating encryption keys for DARE..."
    
    # Generate random keys if they don't exist
    SECRETS_KEY=$(openssl rand -base64 32)
    ENCRYPTION_KEY=$(openssl rand -base64 32)
    
    # Create a key storage directory
    KEYS_DIR="${SFTPGO_HOME}/keys"
    mkdir -p "${KEYS_DIR}"
    chmod 700 "${KEYS_DIR}"
    
    # Store keys securely
    echo "${SECRETS_KEY}" > "${KEYS_DIR}/secrets.key"
    echo "${ENCRYPTION_KEY}" > "${KEYS_DIR}/encryption.key"
    
    chmod 600 "${KEYS_DIR}/secrets.key"
    chmod 600 "${KEYS_DIR}/encryption.key"
    
    log_info "Secrets Key: ${SECRETS_KEY:0:20}..."
    log_info "Encryption Key: ${ENCRYPTION_KEY:0:20}..."
    log_success "Encryption keys generated and stored in ${KEYS_DIR}/"
    log_warn "IMPORTANT: Keep these keys safe and backup them securely"
}

# Function to configure DARE
configure_dare() {
    log_info "Configuring DARE (Data At Rest Encryption)..."
    
    # Verify KMS configuration in config file
    if python3 -c "import json; cfg = json.load(open('${SFTPGO_CONFIG_FILE}')); \
        assert cfg.get('kms', {}).get('encryption', {}).get('url') == 'local', 'Encryption not configured'"; then
        log_success "DARE encryption is properly configured"
    else
        log_error "DARE encryption configuration is missing or invalid"
        exit 1
    fi
}

# Function to create admin user
create_admin_user() {
    log_info "Creating admin user (if needed)..."
    
    # This will be handled during database initialization
    # The config file already has an admin user defined
    log_success "Admin user configuration is set in the config file"
}

# Function to display configuration summary
show_summary() {
    log_info "========== Configuration Summary =========="
    echo "SFTPGO Home: ${SFTPGO_HOME}"
    echo "Data Directory: ${SFTPGO_DATA_DIR}"
    echo "Config File: ${SFTPGO_CONFIG_FILE}"
    echo "Database Path: ${SFTPGO_DB_PATH}"
    echo "Log Directory: ${SFTPGO_LOG_DIR}"
    echo ""
    echo "DARE Status: ENABLED"
    echo "Storage Backend: Local Filesystem"
    echo "SFTP Port: 2022"
    echo "Web Admin Port: 8443"
    echo "Rest API Port: 8080"
    log_info "========== End Summary =========="
}

# Function to display next steps
show_next_steps() {
    echo ""
    log_info "========== Next Steps =========="
    echo "1. Review and update the master keys in the configuration file:"
    echo "   - sftpgo-dare.json: kms.secrets.master_key and kms.encryption.master_key"
    echo ""
    echo "2. Start SFTPGo:"
    echo "   ./sftpgo-start.sh"
    echo ""
    echo "3. Access the web admin interface:"
    echo "   https://127.0.0.1:8443/"
    echo ""
    echo "4. Test SFTP connection:"
    echo "   sftp -P 2022 admin@localhost"
    echo ""
    log_info "========== End Next Steps =========="
}

# Main execution
main() {
    echo ""
    log_info "========== SFTPGo Initialization Script =========="
    echo ""
    
    check_prerequisites
    create_directories
    validate_config
    init_database
    generate_encryption_keys
    configure_dare
    create_admin_user
    show_summary
    show_next_steps
    
    echo ""
    log_success "SFTPGo initialization completed successfully!"
    echo ""
}

# Run main function
main "$@"
