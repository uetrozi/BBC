# Deployment Preparation (Phase 5)

## Ziel und gewählter Ansatz

BBC-X nutzt bereits eine vorhandene **Kamal**-Konfiguration (`config/deploy.yml`) und ein produktionsfähiges Dockerfile.  
Deshalb wird Kamal als Deployment-Ziel beibehalten, statt eine zweite Plattformkonfiguration einzuführen.

## Was lokal vorbereitet wurde

- Produktions-Dockerfile vorhanden und auf Ruby 4.0.6 abgestimmt
- Rails-Produktionskonfiguration geprüft
- Healthcheck-Endpoint `/up` vorhanden
- Datenbankmigrationen lauffähig
- Asset-Pipeline mit Importmap/Chart.js integriert

## Manuell erforderliche Schritte (nicht automatisierbar ohne Zugangsdaten)

1. Zielserver bereitstellen (Linux-Host mit Docker und SSH-Zugang)
2. DNS/Domain konfigurieren (optional, aber empfohlen)
3. Container-Registry festlegen (z. B. GHCR oder Docker Hub)
4. Zugangsdaten für Registry und `RAILS_MASTER_KEY` als Secrets hinterlegen
5. `config/deploy.yml` mit echten Hosts/Registry-Werten ersetzen

## Relevante Umgebungsvariablen in Produktion

- `RAILS_MASTER_KEY` (Pflicht)
- `DATABASE_URL` oder DB-Einzelvariablen
- `BERLIN_BIKE_COUNT_EXPLORER_DATABASE_PASSWORD` (falls kein `DATABASE_URL`)
- `RAILS_FORCE_SSL=true` (empfohlen)
- `RAILS_ASSUME_SSL=true` (hinter Reverse Proxy)
- `RAILS_ALLOWED_HOSTS=example.com,www.example.com`
- `RAILS_LOG_LEVEL=info`

## Build-, Start- und Migrationsschritte

### Mit Docker lokal prüfen

```bash
docker build -t berlin_bike_count_explorer .
docker run --rm -p 3000:80 \
  -e RAILS_ENV=production \
  -e RAILS_MASTER_KEY=... \
  -e DATABASE_URL=... \
  berlin_bike_count_explorer
```

### Mit Kamal (nach manueller Konfiguration)

```bash
bin/kamal setup
bin/kamal deploy
bin/kamal app exec "bin/rails db:migrate"
```

Hinweis: Je nach Kamal-Setup kann die Migration bereits im Deploy-Ablauf enthalten sein; der explizite Befehl ist als sichere Nachkontrolle dokumentiert.

## Sicherheits-/Secrets-Hinweise

- `config/master.key` darf nicht ins Repository.
- Keine Klartext-Passwörter in `config/deploy.yml`.
- `.kamal/secrets` referenziert Secrets über Umgebungsvariablen/Dateien.

## Status

Deployment ist bis zum notwendigen manuellen Anmeldeschritt (Server/Registry/Secrets) vorbereitet, aber nicht automatisiert abgeschlossen.
