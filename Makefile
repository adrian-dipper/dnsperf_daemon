#!/usr/bin/make -f

# DNS Performance Daemon Makefile (OpenRC)

DAEMON_NAME = dnsperf_daemon
DAEMON_PATH = /usr/local/bin
DAEMON_SCRIPT = dns_perf_backend.sh
DAEMON_WORKDIR = /var/lib/$(DAEMON_NAME)
DAEMON_LOGFILE = /var/log/$(DAEMON_NAME).log

PROJECT_ROOT = $(shell pwd)
INSTALL_SCRIPT = $(PROJECT_ROOT)/install.sh

.PHONY: all install uninstall start stop restart status logs clean help

all: help

install:
	@echo "Installing DNS Performance Daemon for OpenRC..."
	@$(INSTALL_SCRIPT)

uninstall:
	@echo "Uninstalling DNS Performance Daemon..."
	@rc-service $(DAEMON_NAME) stop 2>/dev/null || true
	@rc-update del $(DAEMON_NAME) default 2>/dev/null || true
	@rm -f /etc/init.d/$(DAEMON_NAME)
	@rm -f $(DAEMON_PATH)/$(DAEMON_SCRIPT)
	@rm -rf $(DAEMON_WORKDIR)
	@rm -f $(DAEMON_LOGFILE)
	@rm -f /var/run/$(DAEMON_NAME).pid
	@echo "Uninstallation completed."

start:
	@rc-service $(DAEMON_NAME) start

stop:
	@rc-service $(DAEMON_NAME) stop

restart:
	@rc-service $(DAEMON_NAME) restart

status:
	@rc-service $(DAEMON_NAME) status

logs:
	@tail -f $(DAEMON_LOGFILE)

result:
	@echo "Latest DNS performance result:"
	@cat $(DAEMON_WORKDIR)/latest_result.txt 2>/dev/null || echo "No result file found"

test:
	@echo "Running DNS Performance Daemon Backend Test..."
	@chmod +x $(PROJECT_ROOT)/bin/test_dns_perf_backend.sh
	@$(PROJECT_ROOT)/bin/test_dns_perf_backend.sh

test-results:
	@echo "Available test results:"
	@ls -la $(PROJECT_ROOT)/test_results/ 2>/dev/null || echo "No test results found"

# API targets
start-api:
	@rc-service dnsperf_api start

stop-api:
	@rc-service dnsperf_api stop

restart-api:
	@rc-service dnsperf_api restart

status-api:
	@rc-service dnsperf_api status

test-api:
	@echo "Testing API endpoints..."
	@echo "Health check:"
	@curl -s http://localhost:8080/health || echo "API not responding"
	@echo ""
	@echo "Latest result:"
	@curl -s http://localhost:8080/result || echo "API not responding"
	@echo ""
	@echo "Raw result:"
	@curl -s http://localhost:8080/result/raw || echo "API not responding"

clean:
	@echo "Cleaning temporary files..."
	@rm -f $(DAEMON_WORKDIR)/*.zip $(DAEMON_WORKDIR)/*.csv
	@echo "Temporary files cleaned."

add-runlevel:
	@echo "Adding to runlevel..."
	@rc-update add $(DAEMON_NAME) default

del-runlevel:
	@echo "Removing from runlevel..."
	@rc-update del $(DAEMON_NAME) default

show-runlevels:
	@echo "Current runlevel configuration:"
	@rc-update show | grep $(DAEMON_NAME) || echo "Service not found in any runlevel"

help:
	@echo "DNS Performance Daemon Management (OpenRC)"
	@echo ""
	@echo "=== Daemon Commands ==="
	@echo "  install         - Install the daemon and API"
	@echo "  uninstall       - Remove daemon, API and all files"
	@echo "  start           - Start the daemon"
	@echo "  stop            - Stop the daemon"
	@echo "  restart         - Restart the daemon"
	@echo "  status          - Show daemon status"
	@echo "  logs            - Show daemon logs (follow mode)"
	@echo "  result          - Show latest DNS test result"
	@echo ""
	@echo "=== API Commands ==="
	@echo "  start-api       - Start the API server"
	@echo "  stop-api        - Stop the API server"
	@echo "  restart-api     - Restart the API server"
	@echo "  status-api      - Show API server status"
	@echo "  test-api        - Test API endpoints with curl"
	@echo ""
	@echo "=== Testing ==="
	@echo "  test            - Run backend functionality test"
	@echo "  test-results    - Show available test results"
	@echo ""
	@echo "=== Maintenance ==="
	@echo "  clean           - Clean temporary files"
	@echo "  add-runlevel    - Add service to default runlevel"
	@echo "  del-runlevel    - Remove service from default runlevel"
	@echo "  show-runlevels  - Show current runlevel configuration"
	@echo "  help            - Show this help"
	@echo ""
	@echo "=== Examples ==="
	@echo "  sudo make install     # Install daemon and API"
	@echo "  sudo make start       # Start daemon"
	@echo "  sudo make start-api   # Start API server"
	@echo "  make status           # Check daemon status"
	@echo "  make test-api         # Test API endpoints"
	@echo "  make result           # View latest result"
	@echo ""
	@echo "=== API Endpoints ==="
	@echo "  http://localhost:8080/health     - Health check"
	@echo "  http://localhost:8080/result     - Latest result (JSON)"
	@echo "  http://localhost:8080/result/raw - Latest result (raw number)"
	@echo ""
	@echo "Note: Run from the project root directory"
