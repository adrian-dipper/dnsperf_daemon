# DNS Performance Daemon

Ein OpenRC-kompatibler Daemon zum kontinuierlichen Monitoring der DNS-Performance, der regelmäßig DNS-Antwortzeiten
testet und das neueste Ergebnis speichert.

## Features

- Kontinuierliche DNS-Performance-Tests alle 5 Minuten (konfigurierbar)
- Tägliche Aktualisierung der Top-1000-Domains von Cisco Umbrella
- Kombiniert statische Host-Liste mit aktuellen Top-Domains
- Automatisches Logging aller Aktivitäten
- Speichert nur das neueste Testergebnis (überschreibt vorherige Werte)
- OpenRC-kompatibel für einfache Integration mit `rc-update`

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

## Anforderungen

- OpenRC Init-System
- `dnsperf` Tool (DNS Performance Testing Tool)
- `wget` für Domain-Liste Download
- `unzip` für Archiv-Extraktion
- Root-Berechtigung für Daemon-Installation

### Installation der Abhängigkeiten

**Gentoo/Alpine Linux:**

```bash
# Gentoo
emerge -av net-dns/bind-tools net-misc/wget app-arch/unzip

# Alpine
apk add bind-tools wget unzip

# dnsperf muss möglicherweise aus den Quellen kompiliert werden
```

## Installation

1. Alle Dateien in ein Verzeichnis kopieren
2. Installationsskript ausführen:

```bash
# Auf Linux/Unix-Systemen:
chmod +x install.sh
sudo ./install.sh

# Oder explizit mit bash:
sudo bash install.sh
```

Das Skript prüft automatisch OpenRC-Verfügbarkeit und installiert entsprechend.

## Manuelle Installation

```bash
# Daemon-Skript kopieren
cp bin/dns_perf_backend.sh /usr/local/bin/
chmod +x /usr/local/bin/dns_perf_backend.sh

# OpenRC Init-Skript kopieren
cp init/dnsperf_daemon /etc/init.d/
chmod +x /etc/init.d/dnsperf_daemon

# Service zum default runlevel hinzufügen
rc-update add dnsperf_daemon default
```

## Verwendung

```bash
# Daemon starten
rc-service dnsperf_daemon start

# Status prüfen
rc-service dnsperf_daemon status

# Daemon stoppen
rc-service dnsperf_daemon stop

# Daemon neustarten
rc-service dnsperf_daemon restart

# Service aus runlevel entfernen
rc-update del dnsperf_daemon default
```

## Konfiguration

Die Konfiguration erfolgt durch Bearbeitung der Variablen am Anfang von `/usr/local/bin/dns_perf_backend.sh`:

```bash
# DNS Performance configuration
SLEEP_INTERVAL=300  # Sekunden zwischen Tests (Standard: 5 Minuten)
DNS_SERVER="1.1.1.1"  # Zu testender DNS-Server
QUERIES_PER_SECOND=20  # Anfragen pro Sekunde beim Test
```

## Ordnerstruktur

- `bin/` - Ausführbare Skripte
- `init/` - OpenRC Init-System Dateien
- `install.sh` - Installationsskript
- `Makefile` - Build- und Verwaltungsskript

## Dateien und Pfade

- **Daemon-Skript:** `/usr/local/bin/dns_perf_backend.sh`
- **OpenRC Init-Skript:** `/etc/init.d/dnsperf_daemon`
- **PID-Datei:** `/var/run/dnsperf_daemon.pid`
- **Log-Datei:** `/var/log/dnsperf_daemon.log`
- **Arbeitsverzeichnis:** `/var/lib/dnsperf_daemon/`
- **Neuestes Ergebnis:** `/var/lib/dnsperf_daemon/latest_result.txt`
- **Domain-Listen:** `/var/lib/dnsperf_daemon/top_domains.txt`

## Makefile

Für erweiterte Verwaltung stehen Makefile-Targets zur Verfügung:

```bash
make help     # Zeigt alle verfügbaren Befehle
make install  # Installation
make start    # Daemon starten
make status   # Status prüfen
make result   # Neuestes Ergebnis anzeigen
```

## Überwachung

### Log-Datei überwachen:

```bash
tail -f /var/log/dnsperf_daemon.log
```

### Neuestes Ergebnis anzeigen:

```bash
cat /var/lib/dnsperf_daemon/latest_result.txt
```

### Service-Status überwachen:

```bash
rc-service dnsperf_daemon status
```

## Fehlerbehebung

### Daemon startet nicht:

1. Abhängigkeiten prüfen: `which dnsperf wget unzip`
2. OpenRC verfügbar: `which rc-update rc-service`
3. Berechtigungen prüfen: `ls -la /usr/local/bin/dns_perf_backend.sh`
4. Log-Datei überprüfen: `cat /var/log/dnsperf_daemon.log`

### Keine Testergebnisse:

1. DNS-Server erreichbarkeit testen: `nslookup google.de 1.1.1.1`
2. dnsperf manuell testen: `echo "google.de A" | dnsperf -s 1.1.1.1`

### Hoher CPU-Verbrauch:

- `QUERIES_PER_SECOND` reduzieren
- `SLEEP_INTERVAL` erhöhen

## OpenRC Runlevel Management

```bash
# Service zu verschiedenen runlevels hinzufügen
rc-update add dnsperf_daemon default    # Standard runlevel
rc-update add dnsperf_daemon boot       # Boot runlevel

# Alle Services in einem runlevel anzeigen
rc-update show default

# Service-Status für alle runlevels anzeigen
rc-update show
```

## Deinstallation

```bash
# Service stoppen und entfernen
rc-service dnsperf_daemon stop
rc-update del dnsperf_daemon default

# Dateien entfernen
rm /etc/init.d/dnsperf_daemon
rm /usr/local/bin/dns_perf_backend.sh
rm -rf /var/lib/dnsperf_daemon
rm /var/log/dnsperf_daemon.log
rm /var/run/dnsperf_daemon.pid
```

## Beispiel-Output

Das neueste Ergebnis wird in folgendem Format gespeichert:

```
2025-01-21 14:30:25,12.34
```

Wobei `12.34` die durchschnittliche Latenz in Millisekunden ist.

## Lizenz

Dieses Projekt steht unter einer freien Lizenz zur Verfügung.
