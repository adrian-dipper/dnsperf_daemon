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
        RANDOM_SAMPLE_SIZE=100
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
declare HISTORY_FILE="$DAEMON_WORKDIR/dns_perf_history.txt"

# Current date
declare current_day=""
declare last_update_day=""
declare -a HOSTS
declare DNSPERF_PID=""  # Track current dnsperf process

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

# Kill any running child processes with timeout
kill_child_processes() {
    local timeout=${1:-10}  # Default 10 seconds timeout
    local pids
    local process_name
    local found_processes=()

    # List of programs used by the daemon
    local programs=("dnsperf" "wget" "unzip" "head" "cut" "sed" "sort")

    # Find all child processes for each program
    for program in "${programs[@]}"; do
        case $program in
            "dnsperf")
                # Use specific pattern for dnsperf with DNS_SERVER
                pids=$(pgrep -f "dnsperf.*${DNS_SERVER}" 2>/dev/null || true)
                process_name="dnsperf (targeting ${DNS_SERVER})"
                ;;
            "wget")
                # Find wget processes downloading our URL
                pids=$(pgrep -f "wget.*$(basename "$URL")" 2>/dev/null || true)
                process_name="wget (downloading domain list)"
                ;;
            "unzip")
                # Find unzip processes working with our zip file
                pids=$(pgrep -f "unzip.*$(basename "$ZIPFILE")" 2>/dev/null || true)
                process_name="unzip (extracting domain list)"
                ;;
            *)
                # For other programs, find any process with the name
                pids=$(pgrep "^${program}$" 2>/dev/null || true)
                process_name="$program"
                ;;
        esac

        if [ -n "$pids" ]; then
            log "Found running $process_name processes: $pids"
            found_processes+=("$process_name:$pids")

            # First try graceful termination with SIGTERM
            for pid in $pids; do
                if kill -TERM "$pid" 2>/dev/null; then
                    log "Sent SIGTERM to $process_name process $pid"
                fi
            done
        fi
    done

    if [ ${#found_processes[@]} -eq 0 ]; then
        log "No child processes found to terminate"
        return 0
    fi

    # Wait for graceful shutdown
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        local still_running=false

        # Check if any processes are still running
        for entry in "${found_processes[@]}"; do
            local name="${entry%%:*}"
            local pids_str="${entry#*:}"

            for pid in $pids_str; do
                if kill -0 "$pid" 2>/dev/null; then
                    still_running=true
                    break 2
                fi
            done
        done

        if ! $still_running; then
            log "All child processes terminated gracefully"
            return 0
        fi

        sleep 1
        elapsed=$((elapsed + 1))
    done

    # Force kill remaining processes
    local force_killed=false
    for entry in "${found_processes[@]}"; do
        local name="${entry%%:*}"
        local pids_str="${entry#*:}"

        for pid in $pids_str; do
            if kill -0 "$pid" 2>/dev/null; then
                log "Force killing $name process $pid (timeout after ${timeout}s)"
                kill -KILL "$pid" 2>/dev/null || true
                force_killed=true
            fi
        done
    done

    if $force_killed; then
        # Final check after force kill
        sleep 1
        local final_warnings=()

        for entry in "${found_processes[@]}"; do
            local name="${entry%%:*}"
            local pids_str="${entry#*:}"

            for pid in $pids_str; do
                if kill -0 "$pid" 2>/dev/null; then
                    final_warnings+=("$name:$pid")
                fi
            done
        done

        if [ ${#final_warnings[@]} -gt 0 ]; then
            local warning_msg="Warning: Could not kill processes:"
            for warning in "${final_warnings[@]}"; do
                warning_msg="$warning_msg ${warning#*:} (${warning%%:*})"
            done
            log "$warning_msg"
        else
            log "All child processes successfully terminated"
        fi
    fi
}

# Signal handlers
cleanup() {
    log "Daemon received shutdown signal"

    # Kill currently running dnsperf process if any
    if [ -n "$DNSPERF_PID" ] && kill -0 "$DNSPERF_PID" 2>/dev/null; then
        log "Terminating running dnsperf process (PID: $DNSPERF_PID)"
        if kill -TERM "$DNSPERF_PID" 2>/dev/null; then
            # Wait up to 5 seconds for graceful shutdown
            local waited=0
            while [ $waited -lt 5 ] && kill -0 "$DNSPERF_PID" 2>/dev/null; do
                sleep 1
                waited=$((waited + 1))
            done

            # Force kill if still running
            if kill -0 "$DNSPERF_PID" 2>/dev/null; then
                log "Force killing dnsperf process (PID: $DNSPERF_PID)"
                kill -KILL "$DNSPERF_PID" 2>/dev/null || true
            else
                log "dnsperf process terminated gracefully"
            fi
        fi
        DNSPERF_PID=""
    fi

    # Kill any other running child processes with 10 second timeout
    kill_child_processes 10

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

# === History management functions ===
# Add result to history with timestamp
add_to_history() {
    local result="$1"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Format: YYYY-MM-DD HH:MM:SS,latency_ms
    echo "${timestamp},${result}" >> "$HISTORY_FILE"
}

# Clean old entries from history based on retention days
cleanup_history() {
    if [ ! -f "$HISTORY_FILE" ]; then
        return 0
    fi
    
    # Calculate cutoff date (HISTORY_RETENTION_DAYS ago)
    local cutoff_date
    if command -v date >/dev/null 2>&1; then
        # Linux/GNU date
        if date --version 2>/dev/null | grep -q "GNU"; then
            cutoff_date=$(date -d "${HISTORY_RETENTION_DAYS} days ago" "+%Y-%m-%d")
        else
            # BSD/macOS date
            cutoff_date=$(date -v-${HISTORY_RETENTION_DAYS}d "+%Y-%m-%d")
        fi
    else
        log "Warning: date command not available, skipping history cleanup"
        return 1
    fi
    
    # Create temporary file for cleaned history
    local temp_history="${HISTORY_FILE}.tmp"
    
    # Keep entries newer than cutoff date
    local kept_entries=0
    local removed_entries=0
    
    if [ -f "$HISTORY_FILE" ]; then
        while IFS=',' read -r timestamp_part latency; do
            # Extract date part from timestamp (YYYY-MM-DD)
            local entry_date="${timestamp_part%% *}"
            
            # Compare dates (string comparison works for YYYY-MM-DD format)
            if [[ "$entry_date" > "$cutoff_date" ]] || [[ "$entry_date" == "$cutoff_date" ]]; then
                echo "${timestamp_part},${latency}" >> "$temp_history"
                kept_entries=$((kept_entries + 1))
            else
                removed_entries=$((removed_entries + 1))
            fi
        done < "$HISTORY_FILE"
        
        # Replace original file with cleaned version
        if [ -f "$temp_history" ]; then
            mv "$temp_history" "$HISTORY_FILE"
            if [ $removed_entries -gt 0 ]; then
                log "History cleanup: removed $removed_entries entries older than $cutoff_date, kept $kept_entries entries"
            fi
        fi
    fi
    
    # Clean up temp file if it exists
    rm -f "$temp_history"
}

# === Update HOSTS daily with Top n domains ===
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

    # Apply random sampling if configured and we have more domains than sample size
    if [ "$RANDOM_SAMPLE_SIZE" -gt 0 ] && [ ${#DAILY_HOSTS[@]} -gt "$RANDOM_SAMPLE_SIZE" ]; then
        log "Applying random sample: selecting $RANDOM_SAMPLE_SIZE from ${#DAILY_HOSTS[@]} daily hosts"

        # Use shuf to randomly sample domains
        local sampled_hosts=()
        while IFS= read -r domain; do
            sampled_hosts+=("$domain")
        done < <(printf '%s\n' "${DAILY_HOSTS[@]}" | shuf -n "$RANDOM_SAMPLE_SIZE")
        DAILY_HOSTS=("${sampled_hosts[@]}")
    elif [ "$RANDOM_SAMPLE_SIZE" -gt 0 ]; then
        log "Daily hosts (${#DAILY_HOSTS[@]}) <= sample size ($RANDOM_SAMPLE_SIZE), using all domains"
    fi

    # Combine static hosts and downloaded hosts
    HOSTS=("${STATIC_HOSTS[@]}" "${DAILY_HOSTS[@]}")
    log "Updated host list with ${#HOSTS[@]} domains (${#STATIC_HOSTS[@]} static + ${#DAILY_HOSTS[@]} sampled daily)"
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

    # Run DNS performance test in background and capture PID
    local dnsperf_output_file="${DAEMON_WORKDIR}/dnsperf_output.tmp"
    dnsperf -W -q "$QUERIES_PER_SECOND" -v -s "$DNS_SERVER" -f any -d "$DNSPERF_FILE_SORTED" > "$dnsperf_output_file" 2>&1 &
    DNSPERF_PID=$!
    log "Started dnsperf with PID: $DNSPERF_PID"

    # Wait for dnsperf to complete
    if wait "$DNSPERF_PID" 2>/dev/null; then
        # Extract result from output
        local result
        result=$(grep "Average Latency" "$dnsperf_output_file" | cut -d" " -f7)

        if [ -n "$result" ]; then
            # Store only the latest result (value only, no timestamp)
            echo "$result" > "$LATEST_RESULT_FILE"
            log "DNS test completed - Average Latency: ${result}ms"

            # Add result to history
            add_to_history "$result"

            # Cleanup old history entries
            cleanup_history
        else
            log "DNS test failed or returned no results"
        fi
    else
        log "DNS test was interrupted or failed"
    fi

    # Clean up
    DNSPERF_PID=""
    rm -f "$dnsperf_output_file"
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
