#!/bin/bash

#######################################
# SFTPGo Startup Script
# Starts SFTPGo with local filesystem storage and DARE encryption
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
SFTPGO_CONFIG_FILE="${SFTPGO_CONFIG_FILE:-${SFTPGO_HOME}/sftpgo-dare.json}"
SFTPGO_PID_FILE="${SFTPGO_HOME}/sftpgo.pid"
SFTPGO_LOG_FILE="${SFTPGO_HOME}/sftpgo.log"

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

# Function to check if SFTPGo is already running
check_running() {
    if [ -f "${SFTPGO_PID_FILE}" ]; then
        PID=$(cat "${SFTPGO_PID_FILE}")
        if kill -0 "${PID}" 2>/dev/null; then
            log_warn "SFTPGo is already running (PID: ${PID})"
            return 0
        else
            log_info "Removing stale PID file"
            rm -f "${SFTPGO_PID_FILE}"
        fi
    fi
    return 1
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if sftpgo is installed
    if ! command -v sftpgo &> /dev/null; then
        log_error "SFTPGo is not installed. Please install it first."
        exit 1
    fi
    
    # Check if configuration file exists
    if [ ! -f "${SFTPGO_CONFIG_FILE}" ]; then
        log_error "Configuration file not found: ${SFTPGO_CONFIG_FILE}"
        exit 1
    fi
    
    log_success "Prerequisites check completed"
}

# Function to display startup information
show_startup_info() {
    cat << EOF

${BLUE}========== SFTPGo Starting ==========${NC}
Configuration: ${SFTPGO_CONFIG_FILE}
Log File: ${SFTPGO_LOG_FILE}
PID File: ${SFTPGO_PID_FILE}

Services:
  - SFTP Server: sftp://0.0.0.0:2022
  - Web Admin: https://127.0.0.1:8443
  - REST API: http://0.0.0.0:8080

DARE Status: ${GREEN}ENABLED${NC}
Storage: Local Filesystem
${BLUE}===================================${NC}

EOF
}

# Function to start SFTPGo
start_sftpgo() {
    log_info "Starting SFTPGo with DARE encryption..."
    
    cd "${SFTPGO_HOME}"
    
    # Start SFTPGo in the background
    nohup sftpgo serve -c "${SFTPGO_CONFIG_FILE}" > "${SFTPGO_LOG_FILE}" 2>&1 &
    
    SFTPGO_PID=$!
    echo ${SFTPGO_PID} > "${SFTPGO_PID_FILE}"
    
    # Give it a moment to start
    sleep 2
    
    # Check if process is still running
    if ! kill -0 ${SFTPGO_PID} 2>/dev/null; then
        log_error "Failed to start SFTPGo. Check the log file:"
        log_error "  ${SFTPGO_LOG_FILE}"
        tail -n 20 "${SFTPGO_LOG_FILE}"
        rm -f "${SFTPGO_PID_FILE}"
        exit 1
    fi
    
    log_success "SFTPGo started successfully (PID: ${SFTPGO_PID})"
}

# Function to verify services
verify_services() {
    log_info "Verifying services..."
    
    # Check SFTP port
    if nc -z 0.0.0.0 2022 2>/dev/null || sleep 1 && nc -z localhost 2022 2>/dev/null; then
        log_success "SFTP service is listening on port 2022"
    else
        log_warn "Could not verify SFTP service on port 2022"
    fi
    
    # Check REST API port
    if nc -z 0.0.0.0 8080 2>/dev/null || sleep 1 && nc -z localhost 8080 2>/dev/null; then
        log_success "REST API service is listening on port 8080"
    else
        log_warn "Could not verify REST API service on port 8080"
    fi
    
    # Check Web Admin port
    if nc -z 127.0.0.1 8443 2>/dev/null || sleep 1 && nc -z localhost 8443 2>/dev/null; then
        log_success "Web Admin service is listening on port 8443"
    else
        log_warn "Could not verify Web Admin service on port 8443"
    fi
}

# Function to show usage
show_usage() {
    cat << EOF

${BLUE}SFTPGo Server Details:${NC}

SFTP Connection:
  sftp -P 2022 admin@localhost
  Password: password123!

Web Admin:
  URL: https://127.0.0.1:8443/
  Username: admin
  Password: password123!

REST API:
  Base URL: http://127.0.0.1:8080/api/

Data Directory:
  /srv/sftpgo/data

To stop SFTPGo:
  kill $(cat ${SFTPGO_PID_FILE})

To view logs:
  tail -f ${SFTPGO_LOG_FILE}

${BLUE}Note: DARE (Data At Rest Encryption) is enabled${NC}

EOF
}

# Main execution
main() {
    echo ""
    log_info "========== SFTPGo Startup Script =========="
    
    check_prerequisites
    
    # Check if already running
    if check_running; then
        PID=$(cat "${SFTPGO_PID_FILE}")
        log_info "SFTPGo is already running with PID ${PID}"
        show_usage
        return 0
    fi
    
    show_startup_info
    start_sftpgo
    verify_services
    show_usage
    
    echo ""
    log_success "SFTPGo with DARE encryption is now running!"
    echo ""
}

# Run main function
main "$@"
