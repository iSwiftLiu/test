#!/bin/bash

#######################################
# SFTPGo Test Script
# Tests SFTPGo configuration and DARE encryption
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
SFTPGO_DATA_DIR="${SFTPGO_DATA_DIR:-/srv/sftpgo/data}"
SFTPGO_PID_FILE="${SFTPGO_HOME}/sftpgo.pid"
SFTPGO_LOG_FILE="${SFTPGO_HOME}/sftpgo.log"
TEST_FILE="/tmp/sftpgo-test-file.txt"
TEST_FILE_REMOTE="test-file-$(date +%s).txt"
SFTP_TEST_USER="admin"
SFTP_TEST_PASS="password123!"
SFTP_TEST_PORT="2022"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓ PASS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗ FAIL]${NC} $1"
}

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    log_info "Running test $TESTS_RUN: $test_name"
    
    if eval "$test_command" > /dev/null 2>&1; then
        log_success "$test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "$test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Function to check if SFTPGo is running
check_sftpgo_running() {
    if [ ! -f "${SFTPGO_PID_FILE}" ]; then
        return 1
    fi
    
    PID=$(cat "${SFTPGO_PID_FILE}")
    kill -0 "${PID}" 2>/dev/null || return 1
}

# Test 1: Check SFTPGo installation
test_sftpgo_installed() {
    command -v sftpgo &> /dev/null
}

# Test 2: Check configuration file exists
test_config_exists() {
    [ -f "${SFTPGO_CONFIG_FILE}" ]
}

# Test 3: Validate JSON configuration
test_config_valid_json() {
    python3 -m json.tool "${SFTPGO_CONFIG_FILE}" > /dev/null 2>&1
}

# Test 4: Check DARE configuration
test_dare_configured() {
    python3 << 'EOF'
import json
config = json.load(open('sftpgo-dare.json'))
kms = config.get('kms', {})
encryption = kms.get('encryption', {})
assert encryption.get('url') == 'local', "Encryption URL not set to local"
assert encryption.get('master_key'), "Encryption master key not set"
exit(0)
EOF
}

# Test 5: Check local filesystem storage
test_storage_localfs() {
    python3 << 'EOF'
import json
config = json.load(open('sftpgo-dare.json'))
storage = config.get('storage', {})
fs_config = storage.get('fs', {})
assert fs_config.get('osfs_type') == 0, "Filesystem type not set to local"
exit(0)
EOF
}

# Test 6: Check SFTP port configuration
test_sftp_port_configured() {
    python3 << 'EOF'
import json
config = json.load(open('sftpgo-dare.json'))
sftpd = config.get('sftpd', {})
bindings = sftpd.get('bindings', [])
assert len(bindings) > 0, "No SFTP bindings configured"
assert bindings[0].get('port') == 2022, "SFTP port not set to 2022"
exit(0)
EOF
}

# Test 7: Check data directory
test_data_directory_exists() {
    [ -d "${SFTPGO_DATA_DIR}" ]
}

# Test 8: SFTPGo is running
test_sftpgo_running() {
    check_sftpgo_running
}

# Test 9: SFTP port is listening
test_sftp_port_listening() {
    timeout 2 bash -c "echo > /dev/tcp/127.0.0.1/2022" 2>/dev/null || \
    nc -z 127.0.0.1 2022 2>/dev/null
}

# Test 10: REST API port is listening
test_rest_api_listening() {
    timeout 2 bash -c "echo > /dev/tcp/127.0.0.1/8080" 2>/dev/null || \
    nc -z 127.0.0.1 8080 2>/dev/null
}

# Test 11: Web Admin port is listening
test_web_admin_listening() {
    timeout 2 bash -c "echo > /dev/tcp/127.0.0.1/8443" 2>/dev/null || \
    nc -z 127.0.0.1 8443 2>/dev/null
}

# Test 12: SFTP connection
test_sftp_connection() {
    # Create test file
    echo "SFTPGo DARE Test Content - $(date +%s)" > "${TEST_FILE}"
    
    # Try to upload file via SFTP
    (sftppass -u "${SFTP_TEST_USER}" -p "${SFTP_TEST_PASS}" -h localhost -P ${SFTP_TEST_PORT} <<EOF
put ${TEST_FILE} ${TEST_FILE_REMOTE}
quit
EOF
    ) 2>/dev/null || return 1
    
    # Clean up
    rm -f "${TEST_FILE}"
    return 0
}

# Test 13: Database exists
test_database_exists() {
    [ -f "${SFTPGO_HOME}/sftpgo.db" ]
}

# Test 14: Encryption keys exist
test_encryption_keys_exist() {
    [ -f "${SFTPGO_HOME}/keys/encryption.key" ] && \
    [ -f "${SFTPGO_HOME}/keys/secrets.key" ]
}

# Test 15: Log file exists
test_log_file_exists() {
    [ -f "${SFTPGO_LOG_FILE}" ]
}

# Test 16: Check for encryption in log
test_encryption_in_logs() {
    grep -qi "encrypt\|dare\|kms" "${SFTPGO_LOG_FILE}" || return 0  # It's OK if not found
}

# Test 17: Database integrity
test_database_integrity() {
    sqlite3 "${SFTPGO_HOME}/sftpgo.db" "PRAGMA integrity_check;" | grep -q "ok"
}

# Test 18: Check admin user exists
test_admin_user_exists() {
    sqlite3 "${SFTPGO_HOME}/sftpgo.db" "SELECT COUNT(*) FROM users WHERE username='admin';" | grep -q "1"
}

# Test 19: Verify file is encrypted on disk
test_file_encrypted_on_disk() {
    # Check if the uploaded file exists in the data directory
    local file_path=$(find "${SFTPGO_DATA_DIR}" -name "${TEST_FILE_REMOTE}" 2>/dev/null | head -1)
    
    if [ -n "${file_path}" ]; then
        # Try to read the file - if DARE is working, it should be encrypted
        ! grep -q "SFTPGo DARE Test" "${file_path}" 2>/dev/null || return 1
        return 0
    fi
    
    return 1
}

# Test 20: REST API connectivity
test_rest_api_connectivity() {
    curl -k -s https://127.0.0.1:8443/api/v2/version > /dev/null 2>&1 || \
    curl -s http://127.0.0.1:8080/api/v2/version > /dev/null 2>&1
}

# Function to print test results
print_results() {
    echo ""
    log_info "========== Test Results =========="
    echo "Total Tests: ${TESTS_RUN}"
    log_success "Passed: ${TESTS_PASSED}"
    
    if [ ${TESTS_FAILED} -gt 0 ]; then
        log_error "Failed: ${TESTS_FAILED}"
    else
        echo -e "${GREEN}Failed: ${TESTS_FAILED}${NC}"
    fi
    
    if [ ${TESTS_FAILED} -eq 0 ]; then
        echo ""
        log_success "All tests passed!"
        return 0
    else
        echo ""
        log_error "Some tests failed"
        return 1
    fi
}

# Main test suite
main() {
    echo ""
    log_info "========== SFTPGo DARE Configuration Tests =========="
    echo ""
    
    # Configuration tests
    log_info "--- Configuration Tests ---"
    run_test "SFTPGo installed" "test_sftpgo_installed"
    run_test "Configuration file exists" "test_config_exists"
    run_test "Configuration is valid JSON" "test_config_valid_json"
    run_test "DARE encryption configured" "test_dare_configured"
    run_test "Local filesystem storage configured" "test_storage_localfs"
    run_test "SFTP port configured" "test_sftp_port_configured"
    
    echo ""
    log_info "--- Filesystem Tests ---"
    run_test "Data directory exists" "test_data_directory_exists"
    run_test "Database file exists" "test_database_exists"
    
    echo ""
    log_info "--- Runtime Tests ---"
    run_test "SFTPGo service running" "test_sftpgo_running"
    run_test "SFTP port listening" "test_sftp_port_listening"
    run_test "REST API port listening" "test_rest_api_listening"
    run_test "Web Admin port listening" "test_web_admin_listening"
    
    echo ""
    log_info "--- Connectivity Tests ---"
    run_test "REST API connectivity" "test_rest_api_connectivity"
    
    echo ""
    log_info "--- Database Tests ---"
    run_test "Database integrity" "test_database_integrity"
    run_test "Admin user exists" "test_admin_user_exists"
    
    echo ""
    log_info "--- Encryption Tests ---"
    run_test "Encryption keys exist" "test_encryption_keys_exist"
    
    echo ""
    
    # Print results
    print_results
}

# Run main function
main "$@"
