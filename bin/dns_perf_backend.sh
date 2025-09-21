#!/bin/bash

# Daemon configuration
DAEMON_NAME="dnsperf_daemon"
STATIC_LOG_HEADER="${DAEMON_NAME}:"
export DAEMON_USER="root"  # Used by OpenRC init script
export DAEMON_PATH="/usr/local/bin"  # Used by OpenRC init script
DAEMON_PIDFILE="/var/run/${DAEMON_NAME}.pid"
DAEMON_LOGFILE="/var/log/${DAEMON_NAME}.log"
DAEMON_WORKDIR="/var/lib/${DAEMON_NAME}"
CONFIG_FILE="/etc/dnsperf_daemon.conf"

# Load configuration from file
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=../config/dnsperf_daemon.conf
        source "$CONFIG_FILE"
        log "Configuration loaded from $CONFIG_FILE"
    else
        log "Warning: Configuration file $CONFIG_FILE not found, using defaults"
        # Default values
        SLEEP_INTERVAL=30
        DNS_SERVER="1.1.1.1" # Default DNS server to test against
        QUERIES_PER_SECOND=20 # Number of queries per second dnsperf will wait for resolution of
        URL="http://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip"
        DOMAIN_COUNT=1000
        STATIC_HOSTS=(
        "google.de"
        "youtube.com"
        )
    fi
}

# URL und Dateinamen festlegen (based on loaded config)
declare ZIPFILE="$DAEMON_WORKDIR/top-1m.csv.zip"
declare CSVFILE="$DAEMON_WORKDIR/top-1m.csv"
declare TEMP_FILE="$DAEMON_WORKDIR/top_domains.txt"
declare DNSPERF_FILE="$DAEMON_WORKDIR/dns_perf.txt"
declare DNSPERF_FILE_SORTED="$DAEMON_WORKDIR/dns_perf_sorted.txt"
declare LATEST_RESULT_FILE="$DAEMON_WORKDIR/latest_result.txt"

# Current date
declare current_day=""
declare last_update_day=""
declare -a HOSTS
declare -a RUNNING_PIDS=()  # Array to track running dnsperf PIDs

DAILY_HOSTS=()

# === Logging-Funktion ===
log() {
    local line first=true indent=""

    # Determine input source: parameter or stdin
    if [[ -n "$1" ]]; then
        # If there are arguments, combine them into one string and feed to read loop
        while IFS= read -r line; do
            local LOG_HEADER
            LOG_HEADER="$(date "+%b %d %H:%M:%S") $STATIC_LOG_HEADER"

            if $first; then
                # Capture leading whitespace of the first line
                if [[ "$line" =~ ^([[:space:]]*) ]]; then
                    indent="${BASH_REMATCH[1]}"
                fi
                echo "$LOG_HEADER $line" >&1
                echo "$LOG_HEADER $line" >> "$DAEMON_LOGFILE"
                first=false
            else
                echo "$LOG_HEADER ${indent}    $line" >&1
                echo "$LOG_HEADER ${indent}    $line" >> "$DAEMON_LOGFILE"
            fi
        done <<< "$*"
    else
        # Read directly from stdin
        while IFS= read -r line; do
            local LOG_HEADER
            LOG_HEADER="$(date "+%b %d %H:%M:%S") $STATIC_LOG_HEADER"

            if $first; then
                if [[ "$line" =~ ^([[:space:]]*) ]]; then
                    indent="${BASH_REMATCH[1]}"
                fi
                echo "$LOG_HEADER $line" >&1
                echo "$LOG_HEADER $line" >> "$DAEMON_LOGFILE"
                first=false
            else
                echo "$LOG_HEADER ${indent}    $line" >&1
                echo "$LOG_HEADER ${indent}    $line" >> "$DAEMON_LOGFILE"
            fi
        done
    fi
}

# Create working directory
setup_daemon() {
    mkdir -p "$DAEMON_WORKDIR"
    cd "$DAEMON_WORKDIR" || exit 1
    touch "$DAEMON_LOGFILE"
    log "Daemon setup completed"
}

# Kill any running dnsperf processes with timeout
kill_dnsperf_processes() {
    local timeout=${1:-10}  # Default 10 seconds timeout
    local pids

    # Find all dnsperf processes
    pids=$(pgrep -f "dnsperf.*${DNS_SERVER}" 2>/dev/null || true)

    if [ -n "$pids" ]; then
        log "Found running dnsperf processes: $pids"

        # First try graceful termination with SIGTERM
        for pid in $pids; do
            if kill -TERM "$pid" 2>/dev/null; then
                log "Sent SIGTERM to dnsperf process $pid"
            fi
        done

        # Wait for graceful shutdown
        local elapsed=0
        while [ $elapsed -lt $timeout ]; do
            # Check if any processes are still running
            local still_running=""
            for pid in $pids; do
                if kill -0 "$pid" 2>/dev/null; then
                    still_running="$still_running $pid"
                fi
            done

            if [ -z "$still_running" ]; then
                log "All dnsperf processes terminated gracefully"
                return 0
            fi

            sleep 1
            elapsed=$((elapsed + 1))
        done

        # Force kill remaining processes
        for pid in $pids; do
            if kill -0 "$pid" 2>/dev/null; then
                log "Force killing dnsperf process $pid (timeout after ${timeout}s)"
                kill -KILL "$pid" 2>/dev/null || true
            fi
        done

        # Final check
        sleep 1
        local final_check=""
        for pid in $pids; do
            if kill -0 "$pid" 2>/dev/null; then
                final_check="$final_check $pid"
            fi
        done

        if [ -n "$final_check" ]; then
            log "Warning: Could not kill dnsperf processes: $final_check"
        else
            log "All dnsperf processes successfully terminated"
        fi
    fi
}

# Signal handlers
cleanup() {
    log "Daemon received shutdown signal"

    # Kill any running dnsperf processes with 10 second timeout
    kill_dnsperf_processes 10

    rm -f "$DAEMON_PIDFILE"
    log "Daemon stopped gracefully"
    exit 0
}

reload_config() {
    log "Received reload signal - reloading configuration"
    load_config

    # Reset and update all configuration-dependent variables
    DAILY_HOSTS=()

    # Update file paths that depend on DAEMON_WORKDIR (in case it changed)
    ZIPFILE="$DAEMON_WORKDIR/top-1m.csv.zip"
    CSVFILE="$DAEMON_WORKDIR/top-1m.csv"
    TEMP_FILE="$DAEMON_WORKDIR/top_domains.txt"
    DNSPERF_FILE="$DAEMON_WORKDIR/dns_perf.txt"
    DNSPERF_FILE_SORTED="$DAEMON_WORKDIR/dns_perf_sorted.txt"
    LATEST_RESULT_FILE="$DAEMON_WORKDIR/latest_result.txt"

    # Force host list update to reflect new STATIC_HOSTS configuration
    last_update_day=""  # Reset to force update on next cycle

    # Immediately update hosts to get accurate count for logging
    update_hosts >/dev/null 2>&1

    log "Configuration reloaded successfully"
    log "Updated configuration: SLEEP_INTERVAL=${SLEEP_INTERVAL}s, DNS_SERVER=${DNS_SERVER}, QUERIES_PER_SECOND=${QUERIES_PER_SECOND}"
    log "Host list updated with ${#HOSTS[@]} domains (${#STATIC_HOSTS[@]} static + ${#DAILY_HOSTS[@]} dynamic)"
}

trap cleanup SIGTERM SIGINT
trap reload_config SIGHUP

# Interruptible sleep function that can be interrupted by signals
interruptible_sleep() {
    local sleep_time=$1
    local elapsed=0

    while [ $elapsed -lt $sleep_time ]; do
        sleep 1 2>/dev/null || return 1  # Sleep for 1 second at a time
        elapsed=$((elapsed + 1))
    done
    return 0
}

# === Update HOSTS daily with Top 100 domains ===
update_hosts() {
    local current_day
    current_day=$(date +%F)

    DAILY_HOSTS=()

    # Check if we need to update (different day or first run)
    if [ "$current_day" != "$last_update_day" ]; then
        log "Updating domain list for $current_day"
        last_update_day="$current_day"

        # 1. Download der ZIP
        log "Executing wget to download domain list..."
        if wget -N "$URL" -O "$ZIPFILE" 2>&1 | log; then
            log "Successfully downloaded domain list"
        else
            log "Failed to download domain list, using existing file"
            if [ ! -f "$TEMP_FILE" ]; then
                log "No existing domain file found, using static hosts only"
                return
            fi
        fi

        # 2. CSV aus ZIP extrahieren und Top 100 Domains filtern
        log "Executing unzip to extract domain list..."
        if unzip -o "$ZIPFILE" -d "$DAEMON_WORKDIR" 2>&1 | log; then
            head -n "$DOMAIN_COUNT" "$CSVFILE" | cut -d, -f2 | sed 's/\r$//g' >"$TEMP_FILE"
            log "Successfully extracted and filtered domains"
        else
            log "Failed to extract domain list"
        fi
    fi

    # === Update DAILY_HOSTS ===
    if [ -f "$TEMP_FILE" ]; then
        while IFS= read -r domain; do
            if [ -n "$domain" ]; then
                DAILY_HOSTS+=("$domain")
            fi
        done < "$TEMP_FILE"
    fi

    # Combine static hosts and downloaded hosts
    HOSTS=("${STATIC_HOSTS[@]}" "${DAILY_HOSTS[@]}")
    log "Updated host list with ${#HOSTS[@]} domains"
}

# DNS Performance test function
run_dns_test() {
    log "Starting DNS performance test with ${#HOSTS[@]} domains"

    # Generate DNS test file
    echo "" >"$DNSPERF_FILE"
    for host in "${HOSTS[@]}"; do
        echo "$host A" >>"$DNSPERF_FILE"
        echo "$host AAAA" >>"$DNSPERF_FILE"
    done

    # Sort and remove duplicates
    sort "$DNSPERF_FILE" | uniq >"$DNSPERF_FILE_SORTED"

    # Run DNS performance test
    local result
    result=$(dnsperf -W -q "$QUERIES_PER_SECOND" -v -s "$DNS_SERVER" -f any -d "$DNSPERF_FILE_SORTED" 2>/dev/null | grep "Average Latency" | cut -d" " -f7)

    if [ -n "$result" ]; then
        # Store only the latest result (value only, no timestamp)
        echo "$result" > "$LATEST_RESULT_FILE"
        log "DNS test completed - Average Latency: ${result}ms"
    else
        log "DNS test failed or returned no results"
    fi
}

# Daemon main function
daemon_main() {
    # Load initial configuration
    load_config

    setup_daemon
    log "DNS Performance Daemon started (PID: $$)"
    log "Using configuration: SLEEP_INTERVAL=${SLEEP_INTERVAL}s, DNS_SERVER=${DNS_SERVER}, QUERIES_PER_SECOND=${QUERIES_PER_SECOND}"

    # Create PID file
    echo $$ > "$DAEMON_PIDFILE"

    while true; do
        # Record start time
        local start_time
        local end_time
        local elapsed_time
        local remaining_sleep

        start_time=$(date +%s)

        update_hosts >/dev/null 2>&1
        run_dns_test

        # Calculate elapsed time
        end_time=$(date +%s)
        elapsed_time=$((end_time - start_time))

        # Calculate remaining sleep time
        remaining_sleep=$((SLEEP_INTERVAL - elapsed_time))

        if [ $remaining_sleep -gt 0 ]; then
            log "Test took ${elapsed_time}s, sleeping for ${remaining_sleep}s"
            if ! interruptible_sleep "$remaining_sleep"; then
                # Sleep was interrupted, likely by a signal - exit gracefully
                log "Sleep interrupted by signal, exiting"
                break
            fi
        else
            log "Test took ${elapsed_time}s (longer than interval of ${SLEEP_INTERVAL}s), running immediately"
        fi
    done
}

# Run daemon
if [ -z "$DAEMON_MAIN_DISABLED" ]; then
    daemon_main
fi
