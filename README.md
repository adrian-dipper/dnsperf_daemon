# DNS Performance Daemon

Ein OpenRC-kompatibler Daemon zum kontinuierlichen Monitoring der DNS-Performance.

## Schnellstart

```bash
# Installation
sudo ./install.sh

# Daemon starten
sudo rc-service dnsperf_daemon start

# Status prüfen
sudo rc-service dnsperf_daemon status

# Neuestes Ergebnis anzeigen
cat /var/lib/dnsperf_daemon/latest_result.txt
```

## Ordnerstruktur

- `bin/` - Ausführbare Skripte
- `init/` - OpenRC Init-System Dateien
- `scripts/` - (leer - alle Skripte sind jetzt im Hauptverzeichnis)
- `docs/` - Vollständige Dokumentation
- `install.sh` - Installationsskript
- `Makefile` - Build- und Verwaltungsskript

## Vollständige Dokumentation

Siehe [docs/README.md](docs/README.md) für die komplette Anleitung.

## Makefile

Für erweiterte Verwaltung stehen Makefile-Targets zur Verfügung:

```bash
make help     # Zeigt alle verfügbaren Befehle
make install  # Installation
make start    # Daemon starten
make status   # Status prüfen
make result   # Neuestes Ergebnis anzeigen
```
