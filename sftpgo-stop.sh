#!/bin/bash

#######################################
# SFTPGo Stop Script
# Stops the running SFTPGo instance
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
SFTPGO_PID_FILE="${SFTPGO_HOME}/sftpgo.pid"

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

# Main execution
main() {
    echo ""
    log_info "========== SFTPGo Stop Script =========="
    
    if [ ! -f "${SFTPGO_PID_FILE}" ]; then
        log_warn "PID file not found: ${SFTPGO_PID_FILE}"
        log_info "SFTPGo may not be running"
        echo ""
        return 0
    fi
    
    PID=$(cat "${SFTPGO_PID_FILE}")
    
    log_info "Attempting to stop SFTPGo (PID: ${PID})..."
    
    # Check if process exists
    if ! kill -0 "${PID}" 2>/dev/null; then
        log_warn "Process with PID ${PID} is not running"
        rm -f "${SFTPGO_PID_FILE}"
        log_success "Removed stale PID file"
        echo ""
        return 0
    fi
    
    # Send SIGTERM
    log_info "Sending SIGTERM signal..."
    kill -TERM "${PID}" 2>/dev/null || true
    
    # Wait for graceful shutdown
    WAIT_COUNT=0
    MAX_WAIT=15
    
    while kill -0 "${PID}" 2>/dev/null && [ ${WAIT_COUNT} -lt ${MAX_WAIT} ]; do
        sleep 1
        WAIT_COUNT=$((WAIT_COUNT + 1))
        echo -ne "\rWaiting for process to stop... ${WAIT_COUNT}/${MAX_WAIT}s"
    done
    
    echo ""
    
    # Check if process is still running
    if kill -0 "${PID}" 2>/dev/null; then
        log_warn "Graceful shutdown timeout, forcing kill..."
        kill -9 "${PID}" 2>/dev/null || true
        sleep 1
    fi
    
    # Verify process is stopped
    if ! kill -0 "${PID}" 2>/dev/null; then
        rm -f "${SFTPGO_PID_FILE}"
        log_success "SFTPGo stopped successfully"
    else
        log_error "Failed to stop SFTPGo"
        echo ""
        return 1
    fi
    
    echo ""
}

# Run main function
main "$@"
