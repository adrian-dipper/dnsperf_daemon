#!/bin/bash

# DNS Performance Daemon REST API
# Minimal HTTP server to serve DNS performance results

# Configuration
API_PORT=${API_PORT:-8080}
API_HOST=${API_HOST:-0.0.0.0}
DAEMON_WORKDIR=${DAEMON_WORKDIR:-/var/lib/dnsperf_daemon}
LATEST_RESULT_FILE="$DAEMON_WORKDIR/latest_result.txt"
API_PIDFILE="/var/run/dnsperf_api.pid"
API_LOGFILE="/var/log/dnsperf_api.log"

# Logging function
api_log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [API] $1" | tee -a "$API_LOGFILE"
}

# HTTP response helper functions
send_response() {
    local status="$1"
    local content_type="$2"
    local body="$3"

    echo -e "HTTP/1.1 $status\r"
    echo -e "Content-Type: $content_type\r"
    echo -e "Content-Length: ${#body}\r"
    echo -e "Access-Control-Allow-Origin: *\r"
    echo -e "Connection: close\r"
    echo -e "\r"
    echo -n "$body"
}

send_json_response() {
    local status="$1"
    local json="$2"
    send_response "$status" "application/json" "$json"
}

send_text_response() {
    local status="$1"
    local text="$2"
    send_response "$status" "text/plain" "$text"
}

# Handle HTTP request
handle_request() {
    local method path

    # Read the first line (request line)
    read -r method path _

    # Remove carriage return
    method=$(echo "$method" | tr -d '\r')
    path=$(echo "$path" | tr -d '\r')

    # Skip headers (read until empty line)
    while read -r line; do
        line=$(echo "$line" | tr -d '\r')
        [ -z "$line" ] && break
    done

    api_log "Request: $method $path"

    case "$method" in
        GET)
            case "$path" in
                /|/health)
                    # Health check endpoint
                    local timestamp=$(date -Iseconds)
                    local json="{\"status\":\"ok\",\"timestamp\":\"$timestamp\",\"service\":\"dnsperf-api\"}"
                    send_json_response "200 OK" "$json"
                    ;;
                /result|/latest)
                    # Get latest DNS performance result
                    if [ -f "$LATEST_RESULT_FILE" ]; then
                        local result=$(cat "$LATEST_RESULT_FILE" 2>/dev/null)
                        local timestamp=$(date -r "$LATEST_RESULT_FILE" -Iseconds 2>/dev/null || date -Iseconds)

                        if [ -n "$result" ]; then
                            local json="{\"latency\":$result,\"unit\":\"ms\",\"timestamp\":\"$timestamp\",\"status\":\"ok\"}"
                            send_json_response "200 OK" "$json"
                        else
                            local json="{\"error\":\"Result file is empty\",\"status\":\"error\"}"
                            send_json_response "500 Internal Server Error" "$json"
                        fi
                    else
                        local json="{\"error\":\"No result available yet\",\"status\":\"error\"}"
                        send_json_response "404 Not Found" "$json"
                    fi
                    ;;
                /result/raw)
                    # Get raw result (just the number)
                    if [ -f "$LATEST_RESULT_FILE" ]; then
                        local result=$(cat "$LATEST_RESULT_FILE" 2>/dev/null)
                        if [ -n "$result" ]; then
                            send_text_response "200 OK" "$result"
                        else
                            send_text_response "500 Internal Server Error" "Result file is empty"
                        fi
                    else
                        send_text_response "404 Not Found" "No result available yet"
                    fi
                    ;;
                *)
                    # 404 Not Found
                    local json="{\"error\":\"Endpoint not found\",\"available_endpoints\":[\"/health\",\"/result\",\"/result/raw\"],\"status\":\"error\"}"
                    send_json_response "404 Not Found" "$json"
                    ;;
            esac
            ;;
        OPTIONS)
            # CORS preflight
            echo -e "HTTP/1.1 200 OK\r"
            echo -e "Access-Control-Allow-Origin: *\r"
            echo -e "Access-Control-Allow-Methods: GET, OPTIONS\r"
            echo -e "Access-Control-Allow-Headers: Content-Type\r"
            echo -e "Content-Length: 0\r"
            echo -e "\r"
            ;;
        *)
            # Method not allowed
            local json="{\"error\":\"Method not allowed\",\"allowed_methods\":[\"GET\",\"OPTIONS\"],\"status\":\"error\"}"
            send_json_response "405 Method Not Allowed" "$json"
            ;;
    esac
}

# Start HTTP server
start_server() {
    api_log "Starting DNS Performance API server on $API_HOST:$API_PORT"
    api_log "Serving results from: $LATEST_RESULT_FILE"

    # Check if netcat is available
    if ! command -v nc >/dev/null 2>&1; then
        api_log "ERROR: netcat (nc) is required but not installed"
        exit 1
    fi

    # Create PID file
    echo $$ > "$API_PIDFILE"

    # Start listening
    while true; do
        # Use netcat to listen for connections
        nc -l -p "$API_PORT" -q 1 < <(handle_request) 2>/dev/null || {
            api_log "Connection handled"
            sleep 0.1
        }
    done
}

# Signal handlers
cleanup() {
    api_log "API server received shutdown signal"
    rm -f "$API_PIDFILE"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Main execution
main() {
    case "${1:-start}" in
        start)
            start_server
            ;;
        stop)
            if [ -f "$API_PIDFILE" ]; then
                local pid=$(cat "$API_PIDFILE")
                if kill -0 "$pid" 2>/dev/null; then
                    kill -TERM "$pid"
                    echo "API server stopped"
                else
                    echo "API server not running"
                fi
            else
                echo "API server not running (no PID file)"
            fi
            ;;
        status)
            if [ -f "$API_PIDFILE" ]; then
                local pid=$(cat "$API_PIDFILE")
                if kill -0 "$pid" 2>/dev/null; then
                    echo "API server running (PID: $pid)"
                    exit 0
                else
                    echo "API server not running (stale PID file)"
                    exit 1
                fi
            else
                echo "API server not running"
                exit 1
            fi
            ;;
        test)
            echo "Testing API endpoints..."
            echo "Health check: curl http://localhost:$API_PORT/health"
            echo "Get result: curl http://localhost:$API_PORT/result"
            echo "Get raw result: curl http://localhost:$API_PORT/result/raw"
            ;;
        *)
            echo "Usage: $0 {start|stop|status|test}"
            exit 1
            ;;
    esac
}

main "$@"
