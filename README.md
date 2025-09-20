# DNS Performance Daemon

Ein Daemon zum kontinuierlichen Monitoring der DNS-Performance, der regelmäßig DNS-Antwortzeiten testet und die
Ergebnisse protokolliert.

## Features

- Kontinuierliche DNS-Performance-Tests alle 5 Minuten (konfigurierbar)
- Tägliche Aktualisierung der Top-1000-Domains von Cisco Umbrella
- Kombiniert statische Host-Liste mit aktuellen Top-Domains
- Automatisches Logging aller Aktivitäten
- Speichert Testergebnisse mit Zeitstempel in CSV-Format
- Unterstützt sowohl systemd als auch traditionelle RC-Skripte
- Rückwärtskompatibilität für Standalone-Ausführung

## Anforderungen

- `dnsperf` Tool (DNS Performance Testing Tool)
- `wget` für Domain-Liste Download
- `unzip` für Archiv-Extraktion
- Root-Berechtigung für Daemon-Installation

### Installation der Abhängigkeiten

**Ubuntu/Debian:**

```bash
sudo apt-get update
sudo apt-get install dnsperf wget unzip
```

**RHEL/CentOS/Fedora:**

```bash
sudo yum install bind-utils wget unzip
# oder
sudo dnf install bind-utils wget unzip
```

**Hinweis:** `dnsperf` ist möglicherweise nicht in allen Standard-Repositories verfügbar und muss eventuell aus den
Quellen kompiliert werden.

## Installation

1. Alle Dateien in ein Verzeichnis kopieren
2. Installationsskript ausführen:

```bash
sudo chmod +x install.sh
sudo ./install.sh
```

Das Skript erkennt automatisch das Init-System (systemd oder SysV) und installiert entsprechend.

## Manuelle Installation

### Für systemd-Systeme:

```bash
# Daemon-Skript kopieren
sudo cp dns_perf_backend.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/dns_perf_backend.sh

# Service-Datei kopieren
sudo cp dnsperf_daemon.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable dnsperf_daemon
```

### Für SysV-Init-Systeme:

```bash
# Daemon-Skript kopieren
sudo cp dns_perf_backend.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/dns_perf_backend.sh

# RC-Skript kopieren
sudo cp dnsperf_daemon /etc/init.d/
sudo chmod +x /etc/init.d/dnsperf_daemon

# Service aktivieren (RHEL/CentOS)
sudo chkconfig --add dnsperf_daemon
sudo chkconfig dnsperf_daemon on

# Service aktivieren (Debian/Ubuntu)
sudo update-rc.d dnsperf_daemon defaults
```

## Verwendung

### Systemd-Systeme:

```bash
# Daemon starten
sudo systemctl start dnsperf_daemon

# Status prüfen
sudo systemctl status dnsperf_daemon

# Daemon stoppen
sudo systemctl stop dnsperf_daemon

# Daemon neustarten
sudo systemctl restart dnsperf_daemon

# Logs anzeigen
sudo journalctl -u dnsperf_daemon -f
```

### SysV-Init-Systeme:

```bash
# Daemon starten
sudo service dnsperf_daemon start

# Status prüfen
sudo service dnsperf_daemon status

# Daemon stoppen
sudo service dnsperf_daemon stop

# Daemon neustarten
sudo service dnsperf_daemon restart
```

## Konfiguration

Die Konfiguration erfolgt durch Bearbeitung der Variablen am Anfang von `/usr/local/bin/dns_perf_backend.sh`:

```bash
# DNS Performance configuration
SLEEP_INTERVAL=300  # Sekunden zwischen Tests (Standard: 5 Minuten)
DNS_SERVER="1.1.1.1"  # Zu testender DNS-Server
QUERIES_PER_SECOND=20  # Anfragen pro Sekunde beim Test
```

## Dateien und Pfade

- **Daemon-Skript:** `/usr/local/bin/dns_perf_backend.sh`
- **PID-Datei:** `/var/run/dnsperf_daemon.pid`
- **Log-Datei:** `/var/log/dnsperf_daemon.log`
- **Arbeitsverzeichnis:** `/var/lib/dnsperf_daemon/`
- **Ergebnisdatei:** `/var/lib/dnsperf_daemon/dns_results.txt`
- **Domain-Listen:** `/var/lib/dnsperf_daemon/top_domains.txt`

## Überwachung

### Log-Datei überwachen:

```bash
sudo tail -f /var/log/dnsperf_daemon.log
```

### Ergebnisse anzeigen:

```bash
sudo tail -f /var/lib/dnsperf_daemon/dns_results.txt
```

### Aktuelle Performance anzeigen:

```bash
sudo tail -10 /var/lib/dnsperf_daemon/dns_results.txt
```

## Standalone-Verwendung

Das Skript kann auch weiterhin im Standalone-Modus verwendet werden (für Rückwärtskompatibilität):

```bash
/usr/local/bin/dns_perf_backend.sh
```

## Fehlerbehebung

### Daemon startet nicht:

1. Abhängigkeiten prüfen: `which dnsperf wget unzip`
2. Berechtigungen prüfen: `ls -la /usr/local/bin/dns_perf_backend.sh`
3. Log-Datei überprüfen: `sudo cat /var/log/dnsperf_daemon.log`

### Keine Testergebnisse:

1. DNS-Server erreichbarkeit testen: `nslookup google.de 1.1.1.1`
2. dnsperf manuell testen: `echo "google.de A" | dnsperf -s 1.1.1.1`

### Hoher CPU-Verbrauch:

- `QUERIES_PER_SECOND` reduzieren
- `SLEEP_INTERVAL` erhöhen

## Deinstallation

### Systemd:

```bash
sudo systemctl stop dnsperf_daemon
sudo systemctl disable dnsperf_daemon
sudo rm /etc/systemd/system/dnsperf_daemon.service
sudo systemctl daemon-reload
```

### SysV:

```bash
sudo service dnsperf_daemon stop
sudo chkconfig dnsperf_daemon off  # oder: sudo update-rc.d dnsperf_daemon remove
sudo rm /etc/init.d/dnsperf_daemon
```

### Dateien entfernen:

```bash
sudo rm /usr/local/bin/dns_perf_backend.sh
sudo rm -rf /var/lib/dnsperf_daemon
sudo rm /var/log/dnsperf_daemon.log
sudo rm /var/run/dnsperf_daemon.pid
```

## Lizenz

Dieses Projekt steht unter einer freien Lizenz zur Verfügung.
