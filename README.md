# DNS Performance Daemon

**Languages / Sprachen:** [English](README.en.md) | Deutsch (dieses Dokument)

> Änderungsverlauf / Release-Historie: siehe [CHANGELOG](CHANGELOG.md)

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

- Periodische DNS-Performance-Messung (Standard: 30s Intervall)
- Tägliches Aktualisieren einer Top-N (Standard 1000) Domainliste (Cisco Umbrella)
- Zusammenführung statischer und dynamischer Domains
- Persistiert nur die letzte durchschnittliche Latenz
- Strukturiertes Logging in dedizierte Log-Datei
- Konfigurations-Reload ohne Neustart (SIGHUP)
- Kindprozess-Überwachung & forcierter Kill nach Timeout
- OpenRC Service-Integration (start / stop / restart / reload / status)

## Schnellstart
```bash
sudo ./install.sh
sudo rc-service dnsperf_daemon start
rc-service dnsperf_daemon status
cat /var/lib/dnsperf_daemon/latest_result.txt
```

## Anforderungen
- OpenRC Init-System
- dnsperf
- wget
- unzip
- Root-Rechte für Installation / Betrieb

### Abhängigkeiten installieren (Gentoo / Alpine)
```bash
# Gentoo
emerge -av net-dns/bind-tools net-misc/wget app-arch/unzip

# Alpine
apk add bind-tools wget unzip
```
(Hinweis: dnsperf ggf. aus Quellen bauen.)

## Installation
```bash
chmod +x install.sh
sudo ./install.sh
```
Das Skript installiert Daemon, Init-Skript, Beispiel-Konfiguration und legt Verzeichnisse an.

### Manuelle Installation
```bash
cp bin/dns_perf_backend.sh /usr/local/bin/
chmod +x /usr/local/bin/dns_perf_backend.sh
cp init/dnsperf_daemon /etc/init.d/
chmod +x /etc/init.d/dnsperf_daemon
rc-update add dnsperf_daemon default
```

## Service-Befehle
```bash
rc-service dnsperf_daemon start
rc-service dnsperf_daemon status
rc-service dnsperf_daemon stop
rc-service dnsperf_daemon restart
rc-service dnsperf_daemon reload
```

## Konfiguration (`/etc/dnsperf_daemon.conf`)
```bash
# Intervall zwischen Testzyklen (Sekunden)
SLEEP_INTERVAL=30

# Ziel-DNS-Server
DNS_SERVER="1.1.1.1"

# Abfragerate für dnsperf
QUERIES_PER_SECOND=20

# Domainlisten-Quelle (Cisco Umbrella Top 1M)
URL="http://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip"
DOMAIN_COUNT=1000

# Statische Domains (werden vor dynamischer Liste eingefügt)
STATIC_HOSTS=(
  "google.de"
  "youtube.com"
  # weitere falls nötig
)
```
Reload ohne Neustart:
```bash
rc-service dnsperf_daemon reload
```

## Dateien & Pfade
| Zweck | Pfad |
|-------|------|
| Skript | /usr/local/bin/dns_perf_backend.sh |
| Konfiguration | /etc/dnsperf_daemon.conf |
| Init-Skript | /etc/init.d/dnsperf_daemon |
| PID-Datei | /var/run/dnsperf_daemon.pid |
| Log-Datei | /var/log/dnsperf_daemon.log |
| Arbeitsverzeichnis | /var/lib/dnsperf_daemon/ |
| Letztes Ergebnis | /var/lib/dnsperf_daemon/latest_result.txt |
| Domainliste (gefiltert) | /var/lib/dnsperf_daemon/top_domains.txt |

## Makefile Targets
```bash
make help
make install
make start
make status
make result
make test
make test-results
```

## Testing
Ein Backend-Test-Harness ist enthalten:
```bash
./bin/test_dns_perf_backend.sh
# oder
make test
```
**Testmodus Eigenschaften:**
- Reduzierte Domainanzahl (schneller)
- Isolierter Temp-Arbeitsbereich
- Ergebnis-Archivierung nach Commit & Zeitstempel
- Automatische Bereinigung
- Validiert Kernpfade (Config laden, Hosts aktualisieren, dnsperf-Aufruf, Integration)

## Überwachung
```bash
tail -f /var/log/dnsperf_daemon.log
cat /var/lib/dnsperf_daemon/latest_result.txt
rc-service dnsperf_daemon status
```

## Fehlerbehebung
| Symptom | Hinweis |
|---------|---------|
| Keine Ergebnisdatei | Log prüfen, dnsperf installiert? |
| Hohe CPU-Last | QUERIES_PER_SECOND reduzieren oder SLEEP_INTERVAL erhöhen |
| Stop dauert / hängt | Log prüfen: steckt ein Kindprozess (wget/dnsperf)? |
| Reload ohne Effekt | Prüfen ob SIGHUP an PID gesendet wurde |
| Domains nicht aktualisiert | Datum / Schreibrechte im Arbeitsverzeichnis prüfen |

### Sanity Checks
```bash
which dnsperf wget unzip
nslookup google.de 1.1.1.1
```

## Deinstallation
```bash
rc-service dnsperf_daemon stop
rc-update del dnsperf_daemon default
rm /etc/init.d/dnsperf_daemon
rm /usr/local/bin/dns_perf_backend.sh
rm -rf /var/lib/dnsperf_daemon
rm /var/log/dnsperf_daemon.log
rm /var/run/dnsperf_daemon.pid
```

## Beispiel-Ausgabe
```
12.345678
```
Repräsentiert Durchschnittslatenz in Sekunden (6 Nachkommastellen ~ Mikrosekundenauflösung). Details im Log.

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz. Siehe die [LICENSE](LICENSE) Datei für Details.

---
Wenn du das hier liest und dich fragst „Warum?“ – die Antwort lautet: *Weil iteratives Prompten plus Neugier dazu neigt, auszuufern.*
