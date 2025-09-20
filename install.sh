#!/bin/bash
#
# Installation script for DNS Performance Daemon (OpenRC)
#

set -e

DAEMON_NAME="dnsperf_daemon"
DAEMON_USER="root"
DAEMON_PATH="/usr/local/bin"
DAEMON_WORKDIR="/var/lib/${DAEMON_NAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"

echo "Installing DNS Performance Daemon for OpenRC..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Check if OpenRC is available
if ! command -v rc-update >/dev/null 2>&1; then
    echo "Error: OpenRC (rc-update) not found. This script is designed for OpenRC systems."
    exit 1
fi

# Check if this is an update or fresh installation
EXISTING_INSTALLATION=false
if [ -f "$DAEMON_PATH/dns_perf_backend.sh" ] || [ -f "/etc/init.d/dnsperf_daemon" ]; then
    EXISTING_INSTALLATION=true
    echo "Existing installation detected. Performing update..."

    # Stop the daemon if it's running
    if rc-service dnsperf_daemon status >/dev/null 2>&1; then
        echo "Stopping running daemon..."
        rc-service dnsperf_daemon stop
        DAEMON_WAS_RUNNING=true
    else
        DAEMON_WAS_RUNNING=false
    fi
else
    echo "Fresh installation detected..."
fi

# Check dependencies
echo "Checking dependencies..."
MISSING_DEPS=""

if ! command -v dnsperf >/dev/null 2>&1; then
    MISSING_DEPS="$MISSING_DEPS dnsperf"
fi

if ! command -v wget >/dev/null 2>&1; then
    MISSING_DEPS="$MISSING_DEPS wget"
fi

if ! command -v unzip >/dev/null 2>&1; then
    MISSING_DEPS="$MISSING_DEPS unzip"
fi

if [ -n "$MISSING_DEPS" ]; then
    echo "Error: Missing dependencies:$MISSING_DEPS"
    echo "Please install them first. For example:"
    echo "  emerge -av net-dns/bind-tools net-misc/wget app-arch/unzip"
    echo "  Note: dnsperf might need to be compiled from source"
    exit 1
fi

# Create directories
echo "Creating directories..."
mkdir -p "$DAEMON_PATH"
mkdir -p "$DAEMON_WORKDIR"
mkdir -p "/var/log"
mkdir -p "/var/run"

# Backup existing configuration if updating
if [ "$EXISTING_INSTALLATION" = true ]; then
    echo "Backing up existing configuration..."
    if [ -f "$DAEMON_PATH/dns_perf_backend.sh" ]; then
        cp "$DAEMON_PATH/dns_perf_backend.sh" "$DAEMON_PATH/dns_perf_backend.sh.backup"
        echo "  Backup created: $DAEMON_PATH/dns_perf_backend.sh.backup"
    fi
fi

# Copy daemon script
echo "Installing daemon script..."
cp "$PROJECT_ROOT/bin/dns_perf_backend.sh" "$DAEMON_PATH/"
chmod +x "$DAEMON_PATH/dns_perf_backend.sh"

# Install configuration file
echo "Installing configuration file..."
if [ ! -f "/etc/dnsperf_daemon.conf" ] || [ "$EXISTING_INSTALLATION" = false ]; then
    cp "$PROJECT_ROOT/bin/dnsperf_daemon.conf" "/etc/"
    chmod 644 "/etc/dnsperf_daemon.conf"
    echo "  Configuration installed: /etc/dnsperf_daemon.conf"
else
    echo "  Configuration file exists, skipping to preserve settings"
    echo "  New template available at: $PROJECT_ROOT/bin/dnsperf_daemon.conf"
fi

# Install OpenRC init script
echo "Installing OpenRC init script..."
cp "$PROJECT_ROOT/init/dnsperf_daemon" "/etc/init.d/"
chmod +x "/etc/init.d/dnsperf_daemon"

# Add service to default runlevel (only for fresh installations)
if [ "$EXISTING_INSTALLATION" = false ]; then
    echo "Adding service to default runlevel..."
    rc-update add dnsperf_daemon default
else
    echo "Service already in runlevel, skipping rc-update add..."
fi

# Set permissions
echo "Setting permissions..."
chown -R "$DAEMON_USER:$DAEMON_USER" "$DAEMON_WORKDIR"
chmod 755 "$DAEMON_WORKDIR"

# Restart daemon if it was running before
if [ "$EXISTING_INSTALLATION" = true ] && [ "$DAEMON_WAS_RUNNING" = true ]; then
    echo "Restarting daemon..."
    rc-service dnsperf_daemon start
fi

echo ""
if [ "$EXISTING_INSTALLATION" = true ]; then
    echo "Update completed successfully!"
    if [ -f "$DAEMON_PATH/dns_perf_backend.sh.backup" ]; then
        echo "Note: Previous configuration backed up to $DAEMON_PATH/dns_perf_backend.sh.backup"
    fi
else
    echo "Installation completed successfully!"
fi

echo ""
echo "Configuration:"
echo "  Daemon script: $DAEMON_PATH/dns_perf_backend.sh"
echo "  Configuration file: /etc/dnsperf_daemon.conf"
echo "  Working directory: $DAEMON_WORKDIR"
echo "  Log file: /var/log/dnsperf_daemon.log"
echo "  Latest result: $DAEMON_WORKDIR/latest_result.txt"
echo ""
echo "To customize the configuration, edit: /etc/dnsperf_daemon.conf"
echo "Important settings:"
echo "  - SLEEP_INTERVAL: Time between tests (default: 30 seconds)"
echo "  - DNS_SERVER: DNS server to test (default: 1.1.1.1)"
echo "  - QUERIES_PER_SECOND: Test intensity (default: 20)"
echo "  - DOMAIN_COUNT: Number of domains to download (default: 1000)"
echo ""
echo "After changing configuration, reload with:"
echo "  rc-service dnsperf_daemon reload"
echo ""
echo "Start the daemon with:"
echo "  rc-service dnsperf_daemon start"
echo ""
echo "Check status with:"
echo "  rc-service dnsperf_daemon status"
echo ""
echo "View latest result with:"
echo "  cat $DAEMON_WORKDIR/latest_result.txt"
