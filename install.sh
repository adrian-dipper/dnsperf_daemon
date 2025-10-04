#!/bin/bash
#
# Installation script for DNS Performance Daemon (OpenRC)
#

set -e

DAEMON_NAME="dnsperf_daemon"
DAEMON_USER="root"
DAEMON_PATH="/usr/local/bin"
DAEMON_WORKDIR="/var/lib/${DAEMON_NAME}"
CONFIG_DIR="/etc"
INIT_DIR="/etc/init.d"
SYSTEMD_DIR="/etc/systemd/system"
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
if [ -f "$DAEMON_PATH/dns_perf_backend.sh" ] || [ -f "$INIT_DIR/dnsperf_daemon" ]; then
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

if ! command -v shuf >/dev/null 2>&1; then
    MISSING_DEPS="$MISSING_DEPS shuf(coreutils)"
fi

if [ -n "$MISSING_DEPS" ]; then
    echo "Error: Missing dependencies:$MISSING_DEPS"
    echo "Please install them first. For example:"
    echo "  emerge -av net-dns/bind-tools net-misc/wget app-arch/unzip sys-apps/coreutils"
    echo "  Note: dnsperf might need to be compiled from source"
    exit 1
fi

# Create directories with appropriate permissions
echo "Creating system directories..."
mkdir -p "$DAEMON_PATH"
mkdir -p "$DAEMON_WORKDIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$INIT_DIR"
mkdir -p "/var/log"
mkdir -p "/var/run"

# Set proper directory permissions
chmod 755 "$DAEMON_PATH"
chmod 755 "$DAEMON_WORKDIR"
chmod 755 "$CONFIG_DIR"
chmod 755 "$INIT_DIR"

# Backup existing configuration if updating
if [ "$EXISTING_INSTALLATION" = true ]; then
    echo "Backing up existing configuration..."
    if [ -f "$DAEMON_PATH/dns_perf_backend.sh" ]; then
        cp "$DAEMON_PATH/dns_perf_backend.sh" "$DAEMON_PATH/dns_perf_backend.sh.backup"
        echo "  Backup created: $DAEMON_PATH/dns_perf_backend.sh.backup"
    fi

    # Migrate old configuration file location if it exists
    if [ -f "$DAEMON_PATH/dnsperf_daemon.conf" ]; then
        echo "Migrating configuration from old location..."
        if [ ! -f "$CONFIG_DIR/dnsperf_daemon.conf" ]; then
            cp "$DAEMON_PATH/dnsperf_daemon.conf" "$CONFIG_DIR/"
            chmod 644 "$CONFIG_DIR/dnsperf_daemon.conf"
            chown root:root "$CONFIG_DIR/dnsperf_daemon.conf"
            echo "  Configuration migrated: $DAEMON_PATH/dnsperf_daemon.conf -> $CONFIG_DIR/dnsperf_daemon.conf"
            # Remove old config file after successful migration
            rm "$DAEMON_PATH/dnsperf_daemon.conf"
            echo "  Old configuration file removed from $DAEMON_PATH/"
        else
            echo "  Configuration already exists in $CONFIG_DIR/, keeping existing settings"
            echo "  Old configuration file will be removed from $DAEMON_PATH/"
            rm "$DAEMON_PATH/dnsperf_daemon.conf"
        fi
    fi

    # Migrate other potential old file locations
    OLD_LOCATIONS=(
        "/usr/bin/dns_perf_backend.sh"
        "/usr/sbin/dns_perf_backend.sh"
        "/opt/dnsperf_daemon/dns_perf_backend.sh"
    )

    for old_location in "${OLD_LOCATIONS[@]}"; do
        if [ -f "$old_location" ]; then
            echo "Removing old daemon script from: $old_location"
            rm "$old_location"
        fi
    done

    # Clean up old init script locations
    OLD_INIT_LOCATIONS=(
        "/usr/local/etc/init.d/dnsperf_daemon"
        "/opt/dnsperf_daemon/init/dnsperf_daemon"
    )

    for old_init in "${OLD_INIT_LOCATIONS[@]}"; do
        if [ -f "$old_init" ]; then
            echo "Removing old init script from: $old_init"
            # Remove from runlevel first if it was added
            if [ -x "$old_init" ]; then
                rc-update del dnsperf_daemon default 2>/dev/null || true
            fi
            rm "$old_init"
        fi
    done
fi

# Install daemon script to /usr/local/bin/
echo "Installing daemon script to $DAEMON_PATH/..."
cp "$PROJECT_ROOT/bin/dns_perf_backend.sh" "$DAEMON_PATH/"
chmod 755 "$DAEMON_PATH/dns_perf_backend.sh"
chown root:root "$DAEMON_PATH/dns_perf_backend.sh"

# Install configuration file to /etc/
echo "Installing configuration file to $CONFIG_DIR/..."
if [ ! -f "$CONFIG_DIR/dnsperf_daemon.conf" ] || [ "$EXISTING_INSTALLATION" = false ]; then
    cp "$PROJECT_ROOT/config/dnsperf_daemon.conf" "$CONFIG_DIR/"
    chmod 644 "$CONFIG_DIR/dnsperf_daemon.conf"
    chown root:root "$CONFIG_DIR/dnsperf_daemon.conf"
    echo "  Configuration installed: $CONFIG_DIR/dnsperf_daemon.conf"
else
    # Configuration file exists - check if new parameters need to be added
    echo "  Configuration file already exists: $CONFIG_DIR/dnsperf_daemon.conf"

    # Check if RANDOM_SAMPLE_SIZE parameter exists
    if ! grep -q "^RANDOM_SAMPLE_SIZE=" "$CONFIG_DIR/dnsperf_daemon.conf"; then
        echo "  Adding new parameter RANDOM_SAMPLE_SIZE to existing configuration..."

        # Create backup before modifying
        cp "$CONFIG_DIR/dnsperf_daemon.conf" "$CONFIG_DIR/dnsperf_daemon.conf.backup.$(date +%Y%m%d_%H%M%S)"
        echo "  Backup created: $CONFIG_DIR/dnsperf_daemon.conf.backup.$(date +%Y%m%d_%H%M%S)"

        # Add the new parameter after DOMAIN_COUNT line
        sed -i '/^DOMAIN_COUNT=/a RANDOM_SAMPLE_SIZE=100  # Number of domains to randomly sample from daily_hosts for testing (0 = use all)' "$CONFIG_DIR/dnsperf_daemon.conf"
        echo "  Added RANDOM_SAMPLE_SIZE parameter (default: 100)"
    else
        echo "  Configuration already up-to-date with all parameters"
    fi

    # Offer to reset to defaults if user wants
    echo "  Do you want to reset configuration to default settings? (y/N)"
    read -r response

    case "$response" in
        [Yy]|[Yy][Ee][Ss])
            echo "  Creating backup of existing configuration..."
            cp "$CONFIG_DIR/dnsperf_daemon.conf" "$CONFIG_DIR/dnsperf_daemon.conf.backup.$(date +%Y%m%d_%H%M%S)"
            echo "  Backup created: $CONFIG_DIR/dnsperf_daemon.conf.backup.$(date +%Y%m%d_%H%M%S)"

            echo "  Installing new default configuration..."
            cp "$PROJECT_ROOT/config/dnsperf_daemon.conf" "$CONFIG_DIR/"
            chmod 644 "$CONFIG_DIR/dnsperf_daemon.conf"
            chown root:root "$CONFIG_DIR/dnsperf_daemon.conf"
            echo "  Configuration reset to defaults: $CONFIG_DIR/dnsperf_daemon.conf"
            ;;
        *)
            echo "  Keeping existing configuration with user-defined values"
            ;;
    esac
fi

# Install OpenRC init script to /etc/init.d/
echo "Installing OpenRC init script to $INIT_DIR/..."
cp "$PROJECT_ROOT/init/dnsperf_daemon" "$INIT_DIR/"
chmod 755 "$INIT_DIR/dnsperf_daemon"
chown root:root "$INIT_DIR/dnsperf_daemon"

# Install systemd service file (optional, for reference)
if [ -d "$SYSTEMD_DIR" ]; then
    echo "Installing systemd service file to $SYSTEMD_DIR/ (for reference)..."
    cp "$PROJECT_ROOT/init/dnsperf_daemon.service" "$SYSTEMD_DIR/"
    chmod 644 "$SYSTEMD_DIR/dnsperf_daemon.service"
    chown root:root "$SYSTEMD_DIR/dnsperf_daemon.service"
    echo "  Note: systemd service installed but OpenRC takes precedence"
fi

# Add service to default runlevel (only for fresh installations)
if [ "$EXISTING_INSTALLATION" = false ]; then
    echo "Adding service to default runlevel..."
    rc-update add dnsperf_daemon default
else
    echo "Service already in runlevel, skipping rc-update add..."
fi

# Set proper ownership and permissions for working directory
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
echo "Files installed in standard system locations:"
echo "  Daemon executable: $DAEMON_PATH/dns_perf_backend.sh"
echo "  Configuration: $CONFIG_DIR/dnsperf_daemon.conf"
echo "  OpenRC init script: $INIT_DIR/dnsperf_daemon"
if [ -f "$SYSTEMD_DIR/dnsperf_daemon.service" ]; then
    echo "  Systemd service: $SYSTEMD_DIR/dnsperf_daemon.service (reference)"
fi
echo "  Runtime data: $DAEMON_WORKDIR/"
echo "  Log file: /var/log/dnsperf_daemon.log"
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
