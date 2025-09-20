#!/bin/bash
#
# Installation script for DNS Performance Daemon
#

set -e

DAEMON_NAME="dnsperf_daemon"
DAEMON_USER="root"
DAEMON_PATH="/usr/local/bin"
DAEMON_WORKDIR="/var/lib/${DAEMON_NAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing DNS Performance Daemon..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root"
    exit 1
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
    echo "  Ubuntu/Debian: apt-get install dnsperf wget unzip"
    echo "  RHEL/CentOS: yum install bind-utils wget unzip"
    echo "  Note: dnsperf might need to be compiled from source on some systems"
    exit 1
fi

# Create directories
echo "Creating directories..."
mkdir -p "$DAEMON_PATH"
mkdir -p "$DAEMON_WORKDIR"
mkdir -p "/var/log"
mkdir -p "/var/run"

# Copy daemon script
echo "Installing daemon script..."
cp "$SCRIPT_DIR/dns_perf_backend.sh" "$DAEMON_PATH/"
chmod +x "$DAEMON_PATH/dns_perf_backend.sh"

# Detect init system
if systemctl --version >/dev/null 2>&1; then
    echo "Installing systemd service..."
    cp "$SCRIPT_DIR/dnsperf_daemon.service" "/etc/systemd/system/"
    systemctl daemon-reload
    systemctl enable dnsperf_daemon
    echo "Service installed. Use 'systemctl start dnsperf_daemon' to start"
    echo "Use 'systemctl status dnsperf_daemon' to check status"
elif [ -d "/etc/init.d" ]; then
    echo "Installing SysV init script..."
    cp "$SCRIPT_DIR/dnsperf_daemon" "/etc/init.d/"
    chmod +x "/etc/init.d/dnsperf_daemon"

    # Try to enable with chkconfig or update-rc.d
    if command -v chkconfig >/dev/null 2>&1; then
        chkconfig --add dnsperf_daemon
        chkconfig dnsperf_daemon on
    elif command -v update-rc.d >/dev/null 2>&1; then
        update-rc.d dnsperf_daemon defaults
    fi

    echo "Service installed. Use 'service dnsperf_daemon start' to start"
    echo "Use 'service dnsperf_daemon status' to check status"
else
    echo "Warning: Could not detect init system. Manual setup required."
fi

# Set permissions
echo "Setting permissions..."
chown -R "$DAEMON_USER:$DAEMON_USER" "$DAEMON_WORKDIR"
chmod 755 "$DAEMON_WORKDIR"

echo ""
echo "Installation completed successfully!"
echo ""
echo "Configuration:"
echo "  Daemon script: $DAEMON_PATH/dns_perf_backend.sh"
echo "  Working directory: $DAEMON_WORKDIR"
echo "  Log file: /var/log/dnsperf_daemon.log"
echo "  Results file: $DAEMON_WORKDIR/dns_results.txt"
echo ""
echo "To customize the configuration, edit: $DAEMON_PATH/dns_perf_backend.sh"
echo "Important settings:"
echo "  - SLEEP_INTERVAL: Time between tests (default: 300 seconds)"
echo "  - DNS_SERVER: DNS server to test (default: 1.1.1.1)"
echo "  - QUERIES_PER_SECOND: Test intensity (default: 20)"
echo ""
echo "Start the daemon with:"
if systemctl --version >/dev/null 2>&1; then
    echo "  systemctl start dnsperf_daemon"
else
    echo "  service dnsperf_daemon start"
fi
