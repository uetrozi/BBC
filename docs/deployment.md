# Deployment Preparation (Phase 5)

## Ziel und gewählter Ansatz

Für die CV-Demo ist **Render** als Hosting-Ziel vorbereitet (`render.yaml` + Dockerfile).

## Was lokal vorbereitet wurde

- Produktions-Dockerfile vorhanden und auf Ruby 4.0.6 abgestimmt
- Rails-Produktionskonfiguration geprüft
- Healthcheck-Endpoint `/up` vorhanden
- Datenbankmigrationen lauffähig
- Asset-Pipeline mit Importmap/Chart.js integriert

## Render: konkrete Schritte

1. Repository mit Render verbinden
2. New + Blueprint verwenden und `render.yaml` auswählen
3. In Render folgende Variablen setzen:
   - `RAILS_MASTER_KEY`
   - `DATABASE_URL` (Render Postgres oder externer Anbieter)
4. Deploy starten
5. Nach erstem Deploy optional einmalig Seeds ausführen:
   - `bin/rails bbcx:seed_demo`

## Relevante Umgebungsvariablen in Produktion

- `RAILS_MASTER_KEY` (Pflicht)
- `DATABASE_URL` (Pflicht)
- optional: `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL`, `CABLE_DATABASE_URL`
  - falls nicht gesetzt, nutzen sie automatisch `DATABASE_URL`
- `RAILS_FORCE_SSL=true` (empfohlen)
- `RAILS_ASSUME_SSL=true` (hinter Reverse Proxy)
- `RAILS_ALLOWED_HOSTS=example.com,www.example.com` (optional auf Render)
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

## Demo-taugliche Infrastruktur-Reduktion

- **Kein Redis erforderlich**: `config/cable.yml` nutzt in Produktion `adapter: async`.
- **Single-Postgres möglich**: Primärdatenbank über `DATABASE_URL`; zusätzliche Rollen fallen standardmäßig auf dieselbe URL zurück.

## Sicherheits-/Secrets-Hinweise

- `config/master.key` darf nicht ins Repository.
- Keine Klartext-Passwörter/Schlüssel in der Repository-Historie speichern.

## Status

Render-Deployment ist per Blueprint vorbereitet; produktive Veröffentlichung hängt nur noch von gesetzten Secrets/DB-URL und dem ersten Render-Deploy ab.
