#!/bin/bash

# DNS Performance API nginx + FastCGI Installation Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_USER="www-data"
API_GROUP="www-data"

echo "Installing DNS Performance API with nginx + FastCGI..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Detect init system
INIT_SYSTEM="unknown"
if command -v systemctl >/dev/null 2>&1 && [[ -d /etc/systemd/system ]]; then
    INIT_SYSTEM="systemd"
elif command -v rc-service >/dev/null 2>&1 && [[ -d /etc/init.d ]]; then
    INIT_SYSTEM="openrc"
fi

echo "Detected init system: $INIT_SYSTEM"

# Stop and disable old bash API if running
echo "Stopping old bash API service if running..."
if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    systemctl stop dnsperf_api 2>/dev/null || true
    systemctl disable dnsperf_api 2>/dev/null || true
elif [[ "$INIT_SYSTEM" == "openrc" ]]; then
    rc-service dnsperf_api stop 2>/dev/null || true
    rc-update del dnsperf_api 2>/dev/null || true
fi

# Kill any running bash API processes
pkill -f "dns_perf_api.sh" 2>/dev/null || true

# Install required packages
echo "Installing required packages..."
if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y nginx python3 python3-pip
elif command -v apk >/dev/null 2>&1; then
    apk update
    apk add nginx python3 py3-pip
else
    echo "Unsupported package manager. Please install nginx, python3, and python3-pip manually."
    exit 1
fi

# Install Python dependencies
echo "Installing Python dependencies..."
pip3 install flup

# Create user and group if they don't exist
if ! getent group "$API_GROUP" >/dev/null 2>&1; then
    echo "Creating group $API_GROUP..."
    groupadd "$API_GROUP"
fi

if ! getent passwd "$API_USER" >/dev/null 2>&1; then
    echo "Creating user $API_USER..."
    useradd -r -g "$API_GROUP" -s /bin/false -d /var/lib/dnsperf_daemon "$API_USER"
fi

# Create directories
echo "Creating directories..."
mkdir -p /var/lib/dnsperf_daemon
mkdir -p /var/log/nginx
mkdir -p /var/www/dnsperf_api/static

# Copy files
echo "Installing FastCGI application..."
cp "$SCRIPT_DIR/bin/dns_perf_api.py" /usr/local/bin/
chmod +x /usr/local/bin/dns_perf_api.py

# Install service based on init system
echo "Installing service for $INIT_SYSTEM..."
if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    cp "$SCRIPT_DIR/init/dnsperf_api_fastcgi.service" /etc/systemd/system/
    systemctl daemon-reload
elif [[ "$INIT_SYSTEM" == "openrc" ]]; then
    cp "$SCRIPT_DIR/init/dnsperf_api_fastcgi" /etc/init.d/
    chmod +x /etc/init.d/dnsperf_api_fastcgi
fi

# Install nginx configuration
echo "Installing nginx configuration..."
cp "$SCRIPT_DIR/config/nginx_dnsperf_api.conf" /etc/nginx/sites-available/dnsperf_api 2>/dev/null || \
cp "$SCRIPT_DIR/config/nginx_dnsperf_api.conf" /etc/nginx/conf.d/dnsperf_api.conf

# Enable site if using sites-available/sites-enabled
if [[ -d /etc/nginx/sites-enabled ]]; then
    ln -sf /etc/nginx/sites-available/dnsperf_api /etc/nginx/sites-enabled/

    # Remove default nginx site if it exists
    if [[ -f /etc/nginx/sites-enabled/default ]]; then
        echo "Removing default nginx site..."
        rm -f /etc/nginx/sites-enabled/default
    fi
fi

# Set proper permissions
echo "Setting permissions..."
chown -R $API_USER:$API_GROUP /var/lib/dnsperf_daemon
chown $API_USER:$API_GROUP /usr/local/bin/dns_perf_api.py
touch /var/log/dnsperf_api.log
chown $API_USER:$API_GROUP /var/log/dnsperf_api.log

# Test nginx configuration
echo "Testing nginx configuration..."
nginx -t

# Enable and start services
echo "Enabling and starting services..."
if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    systemctl enable dnsperf_api_fastcgi
    systemctl start dnsperf_api_fastcgi
    systemctl enable nginx
    systemctl restart nginx

    echo ""
    echo "Services status:"
    systemctl status dnsperf_api_fastcgi --no-pager -l
    systemctl status nginx --no-pager -l

elif [[ "$INIT_SYSTEM" == "openrc" ]]; then
    rc-update add dnsperf_api_fastcgi
    rc-service dnsperf_api_fastcgi start
    rc-update add nginx
    rc-service nginx restart

    echo ""
    echo "Services status:"
    rc-service dnsperf_api_fastcgi status
    rc-service nginx status
fi

echo ""
echo "Installation completed!"
echo ""
echo "Test the API with:"
echo "  curl http://localhost:8080/health"
echo "  curl http://localhost:8080/result"
echo ""
echo "Logs can be found at:"
if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    echo "  FastCGI: journalctl -u dnsperf_api_fastcgi -f"
else
    echo "  FastCGI: tail -f /var/log/dnsperf_api.log"
fi
echo "  Nginx: tail -f /var/log/nginx/dnsperf_api_error.log"
