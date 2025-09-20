#!/usr/bin/make -f

# DNS Performance Daemon Makefile

DAEMON_NAME = dnsperf_daemon
DAEMON_PATH = /usr/local/bin
DAEMON_SCRIPT = dns_perf_backend.sh
DAEMON_WORKDIR = /var/lib/$(DAEMON_NAME)
DAEMON_LOGFILE = /var/log/$(DAEMON_NAME).log

.PHONY: all install uninstall start stop restart status logs clean help

all: help

install:
	@echo "Installing DNS Performance Daemon..."
	@./install.sh

uninstall:
	@echo "Uninstalling DNS Performance Daemon..."
	@if systemctl --version >/dev/null 2>&1; then \
		systemctl stop $(DAEMON_NAME) 2>/dev/null || true; \
		systemctl disable $(DAEMON_NAME) 2>/dev/null || true; \
		rm -f /etc/systemd/system/$(DAEMON_NAME).service; \
		systemctl daemon-reload; \
	elif [ -f /etc/init.d/$(DAEMON_NAME) ]; then \
		service $(DAEMON_NAME) stop 2>/dev/null || true; \
		if command -v chkconfig >/dev/null 2>&1; then \
			chkconfig $(DAEMON_NAME) off 2>/dev/null || true; \
		elif command -v update-rc.d >/dev/null 2>&1; then \
			update-rc.d $(DAEMON_NAME) remove 2>/dev/null || true; \
		fi; \
		rm -f /etc/init.d/$(DAEMON_NAME); \
	fi
	@rm -f $(DAEMON_PATH)/$(DAEMON_SCRIPT)
	@rm -rf $(DAEMON_WORKDIR)
	@rm -f $(DAEMON_LOGFILE)
	@rm -f /var/run/$(DAEMON_NAME).pid
	@echo "Uninstallation completed."

start:
	@if systemctl --version >/dev/null 2>&1; then \
		systemctl start $(DAEMON_NAME); \
	else \
		service $(DAEMON_NAME) start; \
	fi

stop:
	@if systemctl --version >/dev/null 2>&1; then \
		systemctl stop $(DAEMON_NAME); \
	else \
		service $(DAEMON_NAME) stop; \
	fi

restart:
	@if systemctl --version >/dev/null 2>&1; then \
		systemctl restart $(DAEMON_NAME); \
	else \
		service $(DAEMON_NAME) restart; \
	fi

status:
	@if systemctl --version >/dev/null 2>&1; then \
		systemctl status $(DAEMON_NAME); \
	else \
		service $(DAEMON_NAME) status; \
	fi

logs:
	@if systemctl --version >/dev/null 2>&1; then \
		journalctl -u $(DAEMON_NAME) -f; \
	else \
		tail -f $(DAEMON_LOGFILE); \
	fi

results:
	@echo "Recent DNS performance results:"
	@tail -20 $(DAEMON_WORKDIR)/dns_results.txt 2>/dev/null || echo "No results file found"

clean:
	@echo "Cleaning temporary files..."
	@rm -f $(DAEMON_WORKDIR)/*.zip $(DAEMON_WORKDIR)/*.csv
	@echo "Temporary files cleaned."

test-standalone:
	@echo "Running standalone test..."
	@$(DAEMON_PATH)/$(DAEMON_SCRIPT)

help:
	@echo "DNS Performance Daemon Management"
	@echo ""
	@echo "Available targets:"
	@echo "  install      - Install the daemon and enable service"
	@echo "  uninstall    - Remove daemon and all files"
	@echo "  start        - Start the daemon"
	@echo "  stop         - Stop the daemon"
	@echo "  restart      - Restart the daemon"
	@echo "  status       - Show daemon status"
	@echo "  logs         - Show daemon logs (follow mode)"
	@echo "  results      - Show recent DNS test results"
	@echo "  clean        - Clean temporary files"
	@echo "  test-standalone - Run a single test in standalone mode"
	@echo "  help         - Show this help"
	@echo ""
	@echo "Examples:"
	@echo "  sudo make install    # Install daemon"
	@echo "  sudo make start      # Start daemon"
	@echo "  make status          # Check status"
	@echo "  make logs            # Monitor logs"
	@echo "  make results         # View results"
