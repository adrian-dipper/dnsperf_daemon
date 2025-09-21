# DNS Performance Daemon

**Languages / Sprachen:** [English](README.en.md) | Deutsch (dieses Dokument)

## ⚠️ Disclaimer: Enterprise-Grade Overkill Warning

*Ja, ich bin mir vollkommen bewusst, dass dieses Projekt für eine so simple Aufgabe wie "DNS-Latenz alle 30 Sekunden messen" ungefähr so übertrieben ist wie ein Kampfpanzer für den Einkauf beim Bäcker.*

**Was eigentlich ein 10-Zeilen Bash-Script hätte sein können, ist hier zu einem vollwertigen systemd-ähnlichen Daemon mit folgenden "notwendigen" Features mutiert:**

- **Signal-Handler für graceful shutdowns** (weil ein simples `kill` ja barbarisch wäre)
- **Live-Config-Reloading** (falls man nachts um 3 Uhr dringend den DNS-Server ändern muss)
- **Robuste Prozess-Verwaltung** (tötet alle Child-Prozesse nach Timeout, auch den harmlosen `head`)
- **Interruptible Sleep-Funktion** (normale Sleeps sind für Amateure)
- **Comprehensive Error-Handling** (für alle theoretisch möglichen Edge-Cases)
- **Enterprise Logging** (mit Timestamps und mehrzeiligem Input-Support!)
- **Vollständige Test-Suite** (weil man nie weiß...)

*Der wahre Grund?* Reine Neugier und sportlicher Ehrgeiz: Aus einem kleinen Basisskript wurde durch konsequentes, zielgerichtetes Feature-Prompting (Reload, sauberer Shutdown, Prozess-Kill, Logging-Ausbau, Tests ...) bewusst Schicht für Schicht ein überdimensionierter Baukasten. Kein nebulöses *"mach das professioneller"*, sondern iteratives *"Geht noch X? Dann auch Y."* Minimal kuratiert – den Großteil hat die KI gebaut.

**Das Ergebnis:** Ein Daemon, der vermutlich stabiler läuft als manche Produktionssysteme und dabei eine Aufgabe erledigt, die man auch mit `while true; do dig google.com; sleep 30; done` hätte lösen können.

### 🤖 AI-Generated Code Notice

**Der Großteil dieses Codes wurde von AI generiert.** Minimale manuelle Korrekturen wurden vorgenommen, aber selbst die meisten Korrekturen wurden durch weitere AI-Prompts implementiert. Es ist im Wesentlichen ein Experiment in AI-gesteuerter Software-Entwicklung.

**Verwendete AI-Modelle:**
- **Claude 4.0 Sonnet** (Anthropic) - Primäre Code-Generierung und Refactoring
- **Gemini 2.5 Pro** (Google) - Erweiterte Funktionalitäten und Optimierungen
- **GPT-5** (OpenAI) - Komplexe Problemlösung und Dokumentation
- **GitHub Copilot** - Code-Vervollständigung und kleinere Anpassungen

*Manchmal muss man einfach beweisen, dass man kann. Auch wenn man nicht sollte.*

---

Ein OpenRC-kompatibler Daemon zum kontinuierlichen Monitoring der DNS-Performance, der regelmäßig DNS-Antwortzeiten
testet und das neueste Ergebnis speichert.

## Features

- Kontinuierliche DNS-Performance-Tests alle 30 Sekunden (konfigurierbar)
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

Die Konfiguration erfolgt über die Datei `/etc/dnsperf_daemon.conf`:

```bash
# DNS Performance configuration
SLEEP_INTERVAL=30  # Sekunden zwischen Tests (Standard: 30 Sekunden)
DNS_SERVER="1.1.1.1"  # CloudflareDNS
QUERIES_PER_SECOND=20  # Anfragen pro Sekunde beim Test

# Domain list configuration
URL="http://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip"
DOMAIN_COUNT=1000  # Number of domains to extract from the list

# Static host list
STATIC_HOSTS=(
"google.de"
"youtube.com"
# ... weitere Hosts ...
)
```

Nach Änderungen an der Konfiguration laden Sie diese mit:
```bash
rc-service dnsperf_daemon reload
```

## Ordnerstruktur

- `bin/` - Ausführbare Skripte (Daemon-Skript)
- `config/` - Konfigurationsdateien
- `init/` - OpenRC Init-System Dateien  
- `install.sh` - Installationsskript
- `Makefile` - Build- und Verwaltungsskript

## Dateien und Pfade

- **Daemon-Skript:** `/usr/local/bin/dns_perf_backend.sh`
- **Konfigurationsdatei:** `/etc/dnsperf_daemon.conf`
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
make test     # Backend-Funktionalitäts-Test ausführen
make test-results  # Verfügbare Testergebnisse anzeigen
```

## Testing

Das Projekt enthält ein umfassendes Test-System für das Backend:

### Backend-Test ausführen

```bash
# Test direkt ausführen
./bin/test_dns_perf_backend.sh

# Oder über Makefile
make test
```

### Test-Features

- **Reduzierte Host-Anzahl**: Verwendet nur 10 Domains statt 1000 für schnelle Tests
- **Isolierte Umgebung**: Läuft in `/tmp` und beeinflusst nicht die Produktion
- **Automatische Bereinigung**: Löscht alle temporären Dateien nach dem Test
- **Ergebnis-Archivierung**: Speichert Testergebnis in `test_results/` mit Commit-Hash und Zeitstempel
- **Umfassende Tests**: Testet alle Kernfunktionen (Config laden, Host-Update, DNS-Test, Integration)

### Test-Ergebnisse

Testergebnisse werden automatisch archiviert in:
```
test_results/dns_test_result_<commit-hash>_<timestamp>.txt
```

Beispiel: `dns_test_result_a1b2c3d_20231221_143045.txt`

```bash
# Verfügbare Testergebnisse anzeigen
make test-results

# Neuestes Testergebnis anzeigen
ls -la test_results/ | tail -1
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

Das neueste Ergebnis wird nur als numerischer Wert gespeichert:
```
12.345678
```

Wobei `12.345678` die durchschnittliche Latenz in Sekunden ( 6 Nachkommastellen -> μs ) ist. Das Datum und die Uhrzeit sind im Log verfügbar.

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz. Siehe die [LICENSE](LICENSE) Datei für Details.
