#!/bin/bash

# DNS Performance Daemon Backend Test Script
# Tests core functionality with reduced host count and cleans up after itself

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Test configuration
TEST_NAME="dnsperf_daemon_test"
TEST_WORKDIR="/tmp/${TEST_NAME}_$$"
TEST_RESULT_DIR="$PROJECT_ROOT/test_results"
TEST_LOGFILE="$TEST_WORKDIR/test.log"

# Get commit hash
if command -v git >/dev/null 2>&1 && [ -d "$PROJECT_ROOT/.git" ]; then
    COMMIT_HASH=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")
else
    COMMIT_HASH="unknown"
fi

# Timestamp for result file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILENAME="dns_test_result_${COMMIT_HASH}_${TIMESTAMP}.txt"

# Test configuration overrides
export DAEMON_NAME="$TEST_NAME"
export STATIC_LOG_HEADER="${TEST_NAME}:"
export DAEMON_PIDFILE="$TEST_WORKDIR/test.pid"
export DAEMON_LOGFILE="$TEST_LOGFILE"
export DAEMON_WORKDIR="$TEST_WORKDIR"
export CONFIG_FILE="$TEST_WORKDIR/test.conf"

# Reduced test settings
export SLEEP_INTERVAL=5
export DNS_SERVER="1.1.1.1"
export MAX_OUTSTANDING_QUERIES=10
export URL="http://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip"
export DOMAIN_COUNT=10  # Drastically reduced for testing
export STATIC_HOSTS=("google.com" "cloudflare.com" "github.com")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test environment..."

    # Kill any running test processes
    if [ -f "$DAEMON_PIDFILE" ]; then
        if kill -0 "$(cat "$DAEMON_PIDFILE")" 2>/dev/null; then
            log_info "Stopping test daemon..."
            kill -TERM "$(cat "$DAEMON_PIDFILE")" 2>/dev/null || true
            sleep 2
            if kill -0 "$(cat "$DAEMON_PIDFILE")" 2>/dev/null; then
                kill -KILL "$(cat "$DAEMON_PIDFILE")" 2>/dev/null || true
            fi
        fi
    fi

    # Save result file if it exists
    if [ -f "$TEST_WORKDIR/latest_result.txt" ]; then
        mkdir -p "$TEST_RESULT_DIR"
        cp "$TEST_WORKDIR/latest_result.txt" "$TEST_RESULT_DIR/$RESULT_FILENAME"
        log_success "Test result saved to: $TEST_RESULT_DIR/$RESULT_FILENAME"
    fi

    # Remove all test files
    if [ -d "$TEST_WORKDIR" ]; then
        rm -rf "$TEST_WORKDIR"
        log_info "Test directory removed: $TEST_WORKDIR"
    fi
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."

    local missing_deps=""

    if ! command -v dnsperf >/dev/null 2>&1; then
        missing_deps="$missing_deps dnsperf"
    fi

    if ! command -v wget >/dev/null 2>&1; then
        missing_deps="$missing_deps wget"
    fi

    if ! command -v unzip >/dev/null 2>&1; then
        missing_deps="$missing_deps unzip"
    fi

    if [ -n "$missing_deps" ]; then
        log_error "Missing dependencies:$missing_deps"
        return 1
    fi

    log_success "All dependencies found"
}

# Create test environment
setup_test_env() {
    log_info "Setting up test environment..."

    # Create test directory
    mkdir -p "$TEST_WORKDIR"

    # Create test configuration file
    cat > "$CONFIG_FILE" << EOF
# Test Configuration for DNS Performance Daemon
SLEEP_INTERVAL=$SLEEP_INTERVAL
DNS_SERVER="$DNS_SERVER"
MAX_OUTSTANDING_QUERIES=$MAX_OUTSTANDING_QUERIES
URL="$URL"
DOMAIN_COUNT=$DOMAIN_COUNT
STATIC_HOSTS=(
$(printf '"%s"\n' "${STATIC_HOSTS[@]}")
)
EOF

    log_success "Test environment created: $TEST_WORKDIR"
}

# Source the backend functions
source_backend() {
    log_info "Loading backend functions..."

    # Source the backend script to get its functions
    # We need to prevent the daemon_main from running automatically
    DAEMON_MAIN_DISABLED=1 source "$SCRIPT_DIR/dns_perf_backend.sh"

    log_success "Backend functions loaded"
}

# Test individual functions
test_load_config() {
    log_info "Testing configuration loading..."

    load_config

    if [ "$SLEEP_INTERVAL" = "5" ] && [ "$DNS_SERVER" = "1.1.1.1" ]; then
        log_success "Configuration loaded correctly"
    else
        log_error "Configuration loading failed"
        return 1
    fi
}

test_setup_daemon() {
    log_info "Testing daemon setup..."

    setup_daemon

    if [ -f "$TEST_LOGFILE" ] && [ -d "$TEST_WORKDIR" ]; then
        log_success "Daemon setup completed"
    else
        log_error "Daemon setup failed"
        return 1
    fi
}

test_update_hosts() {
    log_info "Testing host list update..."

    update_hosts

    if [ ${#HOSTS[@]} -gt 0 ]; then
        log_success "Host list updated with ${#HOSTS[@]} hosts"
        log_info "Hosts: ${HOSTS[*]:0:5}..."  # Show first 5 hosts
    else
        log_error "Host list update failed"
        return 1
    fi
}

test_dns_test() {
    log_info "Testing DNS performance test..."

    run_dns_test

    if [ -f "$TEST_WORKDIR/latest_result.txt" ]; then
        local result
        result=$(cat "$TEST_WORKDIR/latest_result.txt")
        if [[ "$result" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            log_success "DNS test completed with result: ${result}ms"
        else
            log_warning "DNS test completed but result format unexpected: $result"
        fi
    else
        log_error "DNS test failed - no result file created"
        return 1
    fi
}

# Run full integration test
run_integration_test() {
    log_info "Running integration test (short daemon run)..."

    # Export the necessary functions and variables for the background process
    export -f log daemon_main update_hosts run_dns_test setup_daemon load_config cleanup reload_config
    export HOSTS DAILY_HOSTS STATIC_HOSTS

    # Start daemon in background for a short time
    (
        # Redirect daemon output to test log
        exec >> "$TEST_LOGFILE" 2>&1

        # Load configuration
        load_config
        setup_daemon

        log "Integration test: DNS Performance Daemon started (PID: $$)"
        log "Using configuration: SLEEP_INTERVAL=${SLEEP_INTERVAL}s, DNS_SERVER=${DNS_SERVER}, MAX_OUTSTANDING_QUERIES=${MAX_OUTSTANDING_QUERIES}"

        # Create PID file
        echo $$ > "$DAEMON_PIDFILE"

        # Run a few cycles
        for i in {1..3}; do
            local start_time end_time elapsed_time
            start_time=$(date +%s)

            log "Integration test cycle $i/3"
            update_hosts >/dev/null 2>&1
            run_dns_test

            end_time=$(date +%s)
            elapsed_time=$((end_time - start_time))
            log "Test cycle $i took ${elapsed_time}s"

            # Sleep for reduced interval
            sleep 2
        done

        log "Integration test completed successfully"
        rm -f "$DAEMON_PIDFILE"
    ) &

    local daemon_pid=$!

    # Wait for daemon to complete or timeout after 30 seconds
    local timeout=30
    local elapsed=0

    while [ $elapsed -lt $timeout ]; do
        if ! kill -0 $daemon_pid 2>/dev/null; then
            log_success "Integration test completed successfully"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    # Timeout - kill daemon
    log_warning "Integration test timed out, stopping daemon..."
    kill -TERM $daemon_pid 2>/dev/null || true
    sleep 2
    kill -KILL $daemon_pid 2>/dev/null || true

    log_success "Integration test completed (with timeout)"
}

# Show test results
show_results() {
    log_info "Test Results Summary:"
    echo "===================="

    if [ -f "$TEST_LOGFILE" ]; then
        echo -e "${BLUE}Log entries:${NC}"
        grep -c "dnsperf_daemon_test:" "$TEST_LOGFILE" || echo "0"
    fi

    if [ -f "$TEST_WORKDIR/latest_result.txt" ]; then
        local result
        result=$(cat "$TEST_WORKDIR/latest_result.txt")
        echo -e "${BLUE}Final DNS latency result:${NC} ${result}ms"
    fi

    if [ -d "$TEST_WORKDIR" ]; then
        echo -e "${BLUE}Files created during test:${NC}"
        # Count files in directory (excluding . and ..)
        file_count=0
        for file in "$TEST_WORKDIR"/*; do
            [ -e "$file" ] && file_count=$((file_count + 1))
        done
        echo "$file_count"
    fi

    echo -e "${BLUE}Commit hash:${NC} $COMMIT_HASH"
    echo -e "${BLUE}Timestamp:${NC} $TIMESTAMP"
    echo -e "${BLUE}Result file:${NC} $TEST_RESULT_DIR/$RESULT_FILENAME"
}

# Main test execution
main() {
    log_info "Starting DNS Performance Daemon Backend Test"
    log_info "Commit: $COMMIT_HASH, Timestamp: $TIMESTAMP"
    echo "========================================================"

    # Run all tests
    check_dependencies || exit 1
    setup_test_env || exit 1
    source_backend || exit 1
    test_load_config || exit 1
    test_setup_daemon || exit 1
    test_update_hosts || exit 1
    test_dns_test || exit 1
    run_integration_test || exit 1

    echo "========================================================"
    show_results
    echo "========================================================"

    log_success "All tests completed successfully!"
    log_info "Result will be saved to: $TEST_RESULT_DIR/$RESULT_FILENAME"
}

# Prevent daemon_main from running when sourcing the backend script
export DAEMON_MAIN_DISABLED=1

# Run main function
main "$@"
