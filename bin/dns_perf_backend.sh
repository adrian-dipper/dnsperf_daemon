#!/bin/bash

# Daemon configuration
DAEMON_NAME="dnsperf_daemon"
DAEMON_USER="root"
DAEMON_PATH="/usr/local/bin"
DAEMON_PIDFILE="/var/run/${DAEMON_NAME}.pid"
DAEMON_LOGFILE="/var/log/${DAEMON_NAME}.log"
DAEMON_WORKDIR="/var/lib/${DAEMON_NAME}"
CONFIG_FILE="/etc/dnsperf_daemon.conf"

# Load configuration from file
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        log_message "Configuration loaded from $CONFIG_FILE"
    else
        log_message "Warning: Configuration file $CONFIG_FILE not found, using defaults"
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
declare TODAY_DNSPERF_LOG="$DAEMON_WORKDIR/today_dnsperf_log.txt"
declare LATEST_RESULT_FILE="$DAEMON_WORKDIR/latest_result.txt"

# Current date
declare current_day=""
declare -a HOSTS

DAILY_HOSTS=()

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$DAEMON_LOGFILE"
}

# Create working directory
setup_daemon() {
    mkdir -p "$DAEMON_WORKDIR"
    cd "$DAEMON_WORKDIR"
    touch "$DAEMON_LOGFILE"
    log_message "Daemon setup completed"
}

# Signal handlers
cleanup() {
    log_message "Daemon received shutdown signal"
    rm -f "$DAEMON_PIDFILE"
    exit 0
}

reload_config() {
    log_message "Received reload signal - reloading configuration"
    load_config
    log_message "Configuration reloaded successfully"
}

trap cleanup SIGTERM SIGINT
trap reload_config SIGHUP

# === Update HOSTS daily with Top 100 domains ===
update_hosts() {
    local today=""
    local current_day
    current_day=$(date +%F)

    # Read today's date from log file if it exists
    if [ -f "$TODAY_DNSPERF_LOG" ]; then
        today=$(cat "$TODAY_DNSPERF_LOG" 2>/dev/null || echo "")
    fi

    DAILY_HOSTS=()

    # If file does not exist or is from previous day, fetch new list
    if [ "$current_day" != "$today" ]; then
        log_message "Updating domain list for $current_day"
        echo "$current_day" >"$TODAY_DNSPERF_LOG"

        # 1. Download der ZIP
        log_message "Executing wget to download domain list..."
        if wget -N "$URL" -O "$ZIPFILE" >> "$DAEMON_LOGFILE" 2>&1; then
            log_message "Successfully downloaded domain list"
        else
            log_message "Failed to download domain list, using existing file"
            if [ ! -f "$TEMP_FILE" ]; then
                log_message "No existing domain file found, using static hosts only"
                return
            fi
        fi

        # 2. CSV aus ZIP extrahieren und Top 100 Domains filtern
        log_message "Executing unzip to extract domain list..."
        if unzip -o "$ZIPFILE" -d "$DAEMON_WORKDIR" >> "$DAEMON_LOGFILE" 2>&1; then
            head -n "$DOMAIN_COUNT" "$CSVFILE" | cut -d, -f2 | sed 's/\r$//g' >"$TEMP_FILE"
            log_message "Successfully extracted and filtered domains"
        else
            log_message "Failed to extract domain list"
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
    log_message "Updated host list with ${#HOSTS[@]} domains"
}

# DNS Performance test function
run_dns_test() {
    log_message "Starting DNS performance test with ${#HOSTS[@]} domains"

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
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        # Store only the latest result (value only, no timestamp)
        echo "$result" > "$LATEST_RESULT_FILE"
        log_message "DNS test completed - Average Latency: ${result}ms"
    else
        log_message "DNS test failed or returned no results"
    fi
}

# Daemon main function
daemon_main() {
    # Load initial configuration
    load_config

    setup_daemon
    log_message "DNS Performance Daemon started (PID: $$)"
    log_message "Using configuration: SLEEP_INTERVAL=${SLEEP_INTERVAL}s, DNS_SERVER=${DNS_SERVER}, QUERIES_PER_SECOND=${QUERIES_PER_SECOND}"

    # Create PID file
    echo $$ > "$DAEMON_PIDFILE"

    while true; do
        # Record start time
        local start_time=$(date +%s)

        update_hosts >/dev/null 2>&1
        run_dns_test

        # Calculate elapsed time
        local end_time=$(date +%s)
        local elapsed_time=$((end_time - start_time))

        # Calculate remaining sleep time
        local remaining_sleep=$((SLEEP_INTERVAL - elapsed_time))

        if [ $remaining_sleep -gt 0 ]; then
            log_message "Test took ${elapsed_time}s, sleeping for ${remaining_sleep}s"
            sleep "$remaining_sleep"
        else
            log_message "Test took ${elapsed_time}s (longer than interval of ${SLEEP_INTERVAL}s), running immediately"
        fi
    done
}

# Run daemon
daemon_main
