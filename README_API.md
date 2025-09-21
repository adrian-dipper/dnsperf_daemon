# DNS Performance API - nginx + FastCGI

Diese Implementierung ersetzt das ursprüngliche Bash-Skript durch eine professionelle nginx + FastCGI Lösung mit Python.

## Architektur

- **nginx**: Webserver für HTTP-Verarbeitung und Load Balancing
- **Python FastCGI**: Effiziente Verarbeitung der API-Anfragen
- **Unix Socket**: Kommunikation zwischen nginx und FastCGI für bessere Performance

## Installation

### Automatische Installation

```bash
sudo ./install_api.sh
```

Das Skript:
- Erkennt automatisch systemd oder OpenRC
- Stoppt die alte Bash-API
- Installiert erforderliche Pakete (nginx, python3, flup)
- Richtet Services ein
- Konfiguriert nginx
- Startet alle Services

### Manuelle Installation

1. **Abhängigkeiten installieren:**
   ```bash
   # Ubuntu/Debian
   apt-get install nginx python3 python3-pip
   pip3 install flup
   
   # Alpine Linux
   apk add nginx python3 py3-pip
   pip3 install flup
   ```

2. **Dateien kopieren:**
   ```bash
   cp bin/dns_perf_api.py /usr/local/bin/
   chmod +x /usr/local/bin/dns_perf_api.py
   ```

3. **Service installieren:**
   ```bash
   # systemd
   cp init/dnsperf_api_fastcgi.service /etc/systemd/system/
   systemctl enable dnsperf_api_fastcgi
   
   # OpenRC
   cp init/dnsperf_api_fastcgi /etc/init.d/
   chmod +x /etc/init.d/dnsperf_api_fastcgi
   rc-update add dnsperf_api_fastcgi
   ```

4. **nginx konfigurieren:**
   ```bash
   cp config/nginx_dnsperf_api.conf /etc/nginx/sites-available/dnsperf_api
   ln -s /etc/nginx/sites-available/dnsperf_api /etc/nginx/sites-enabled/
   ```

## API Endpoints

- `GET /health` - Health Check
- `GET /result` - JSON-formatierte Latenz-Daten
- `GET /result/raw` - Roh-Latenz-Wert (nur Zahl)

### Beispiel-Responses

**Health Check:**
```json
{
  "status": "ok",
  "timestamp": "2025-01-21T14:30:00.123456",
  "service": "dnsperf-api"
}
```

**Result:**
```json
{
  "latency": 12.5,
  "unit": "ms",
  "timestamp": "2025-01-21T14:29:45.000000",
  "status": "ok"
}
```

## Service Management

### systemd
```bash
systemctl start dnsperf_api_fastcgi
systemctl stop dnsperf_api_fastcgi
systemctl restart dnsperf_api_fastcgi
systemctl status dnsperf_api_fastcgi
```

### OpenRC
```bash
rc-service dnsperf_api_fastcgi start
rc-service dnsperf_api_fastcgi stop
rc-service dnsperf_api_fastcgi restart
rc-service dnsperf_api_fastcgi status
```

## Logs

- **FastCGI Application:** `/var/log/dnsperf_api.log`
- **nginx Access:** `/var/log/nginx/dnsperf_api_access.log`
- **nginx Error:** `/var/log/nginx/dnsperf_api_error.log`
- **systemd Journal:** `journalctl -u dnsperf_api_fastcgi`

## Testing

```bash
# Health Check
curl http://localhost:8080/health

# Get DNS latency result
curl http://localhost:8080/result

# Get raw latency value
curl http://localhost:8080/result/raw
```

## Vorteile gegenüber Bash-API

1. **Performance**: FastCGI ist effizienter als netcat-basierte Lösung
2. **Stabilität**: nginx ist ein robuster Webserver
3. **Skalierbarkeit**: nginx kann Load Balancing und mehrere FastCGI-Worker verwalten
4. **Sicherheit**: Bessere Isolation und Sicherheitsfeatures
5. **Monitoring**: Bessere Log- und Monitoring-Möglichkeiten
6. **Wartung**: Einfachere Konfiguration und Wartung

## Konfiguration

### nginx Konfiguration
Die nginx-Konfiguration kann in `/etc/nginx/sites-available/dnsperf_api` oder `/etc/nginx/conf.d/dnsperf_api.conf` angepasst werden.

### FastCGI Konfiguration
Umgebungsvariablen können im Service-File gesetzt werden:
- `DAEMON_WORKDIR`: Arbeitsverzeichnis (default: `/var/lib/dnsperf_daemon`)

### Socket-Pfad
Der Unix Socket wird unter `/var/run/dnsperf_api.sock` erstellt.

## Troubleshooting

1. **Socket-Berechtigungen**: Der Socket muss für nginx lesbar sein
2. **Firewall**: Port 8080 muss geöffnet sein
3. **SELinux**: Kann FastCGI-Kommunikation blockieren
4. **Logs prüfen**: Immer zuerst die Logs kontrollieren
