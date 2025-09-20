#!/usr/bin/make -f

# DNS Performance Daemon Makefile (OpenRC)

DAEMON_NAME = dnsperf_daemon
DAEMON_PATH = /usr/local/bin
DAEMON_SCRIPT = dns_perf_backend.sh
DAEMON_WORKDIR = /var/lib/$(DAEMON_NAME)
DAEMON_LOGFILE = /var/log/$(DAEMON_NAME).log

.PHONY: all install uninstall start stop restart status logs clean help

all: help

install:
	@echo "Installing DNS Performance Daemon for OpenRC..."
	@./install.sh

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
	@echo "Available targets:"
	@echo "  install         - Install the daemon and add to default runlevel"
	@echo "  uninstall       - Remove daemon and all files"
	@echo "  start           - Start the daemon"
	@echo "  stop            - Stop the daemon"
	@echo "  restart         - Restart the daemon"
	@echo "  status          - Show daemon status"
	@echo "  logs            - Show daemon logs (follow mode)"
	@echo "  result          - Show latest DNS test result"
	@echo "  clean           - Clean temporary files"
	@echo "  add-runlevel    - Add service to default runlevel"
	@echo "  del-runlevel    - Remove service from default runlevel"
	@echo "  show-runlevels  - Show current runlevel configuration"
	@echo "  help            - Show this help"
	@echo ""
	@echo "Examples:"
	@echo "  sudo make install     # Install daemon"
	@echo "  sudo make start       # Start daemon"
	@echo "  make status           # Check status"
	@echo "  make logs             # Monitor logs"
	@echo "  make result           # View latest result"
