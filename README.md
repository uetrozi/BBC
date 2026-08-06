# BerlinBikeCountExplorer

BerlinBikeCountExplorer ist eine Ruby-on-Rails-Anwendung zur Auswertung offizieller Berliner Radzähldaten: CSV-Import, serverseitige Filterung, tabellarische Anzeige, Kennzahlen und Zeitreihen-Diagramm.

## 1) Screenshot

Aktuell liegt kein finaler Screenshot im Repository. Nutze die Anleitung in `docs/screenshot-guide.md`, um reproduzierbar einen Portfolio-Screenshot zu erstellen.

## 2) Live-Demo

- Live-Demo: _noch nicht veröffentlicht_
- Deployment-Vorbereitung und manuelle Schritte: `docs/deployment.md`

## 3) Problemstellung und Nutzen

Die offiziellen Berliner Radzähldaten liegen als große Rohdateien vor. Das Projekt zeigt, wie diese Daten robust importiert, in PostgreSQL modelliert und für eine nachvollziehbare Analyseoberfläche aufbereitet werden können.

## 4) Funktionsumfang

- Import normalisierter CSV-Dateien in PostgreSQL
- Duplikatsschutz und zeilenweise Fehlerbehandlung beim Import
- Explorer mit URL-basierten Filtern (`station_id`, `from`, `to`, `page`)
- Paginierte Ergebnistabelle
- SQL-basierte Kennzahlen:
  - Gesamtzahl
  - Durchschnitt pro ausgewertetem Tag
  - Stärkster Tag
  - Anzahl ausgewerteter Tage
- Chart.js-Liniendiagramm auf Tagesaggregation
- Importhistorie über `ImportBatch`

## 5) Verwendete Technologien

- Ruby 4.0.6
- Rails 8.1.x
- PostgreSQL 16
- Minitest (inkl. Systemtest mit Rack::Test)
- Chart.js (via Importmap)
- RuboCop, Brakeman, Bundler Audit
- Dockerfile + Render Blueprint (`render.yaml`)

## 6) Datenquelle und Lizenz

- Datensatz: **Radzahldaten in Berlin**
- Veröffentlichende Stelle: Senatsverwaltung für Mobilität, Verkehr, Klimaschutz und Umwelt
- Portal: https://daten.berlin.de/datensaetze/radzahldaten-in-berlin
- Lizenz: **Datenlizenz Deutschland - Zero - Version 2.0 (dl-de-zero-2.0)**
- Detailanalyse der realen Quellstruktur: `docs/data_source_analysis.md`

## 7) Architekturübersicht

```text
Offizielle XLSX/CSV-Quelle
  -> Normalisierung (XlsxNormalizer, optional)
  -> CsvImporter / ImportRunner
  -> PostgreSQL (counting_stations, bike_counts, import_batches)
  -> Active Record Query Objects (FilterQuery, Statistics)
  -> Rails Controller + Views
  -> HTML-Tabelle + Kennzahlen + Chart.js
```

## 8) Datenmodell

### counting_stations
- `external_id` (unique)
- `name`
- `latitude` (optional)
- `longitude` (optional)
- `installed_at` (optional)

### bike_counts
- `counting_station_id` (FK)
- `counted_at`
- `count`
- Unique-Index auf `(counting_station_id, counted_at)`
- Zusatzindex auf `counted_at` für Datumsfilter/Aggregation

### import_batches
- `filename`
- `imported_at`
- `rows_read`
- `imported_rows`
- `skipped_duplicates`
- `invalid_rows`
- `status` (`running`, `completed`, `completed_with_errors`, `failed`)

## 9) CSV-Importprozess

1. Datei- und Header-Validierung
2. Zeilenweises Parsing und fachliche Validierung
3. Station anlegen/finden (`external_id`)
4. `bike_counts` per `insert_all` importieren
5. Duplikate über DB-Unique-Index erkennen
6. Importzusammenfassung + Fehlerliste erzeugen
7. Importlauf in `import_batches` protokollieren

## 10) Filter- und Analysefunktionen

- Filterung erfolgt serverseitig in SQL, nicht in Ruby-Arrays.
- Alle Explorer-Bereiche nutzen dieselbe gefilterte Relation:
  - Tabelle
  - Trefferanzahl
  - Kennzahlen
  - Chartdaten
- Tagesaggregation: erst Summe pro Kalendertag, dann Kennzahlen.

## 11) Lokale Einrichtung

Bevorzugter Weg:

```bash
cd BerlinBikeCountExplorer
bin/setup --skip-server
bin/rails db:seed
bin/rails server
```

Alternativ manuell:

```bash
bundle install
bin/rails db:prepare
```

Dann:
- Startseite: `http://localhost:3000`
- Explorer: `http://localhost:3000/explorer`

## 12) Erforderliche Umgebungsvariablen

### Lokal (optional)
- `RAILS_MAX_THREADS` (Default 5 in DB-Konfiguration)

### Produktion (relevant)
- `RAILS_ENV=production`
- `RAILS_MASTER_KEY`
- `DATABASE_URL` (Pflicht, z. B. Render Postgres oder externer Anbieter)
- `RAILS_FORCE_SSL=true` (empfohlen)
- `RAILS_ASSUME_SSL=true` (hinter SSL-terminierendem Proxy)
- `RAILS_ALLOWED_HOSTS=example.com,www.example.com` (optional auf Render, da `RENDER_EXTERNAL_HOSTNAME` automatisch berücksichtigt wird)
- `RAILS_LOG_LEVEL=info` (Default)

## 13) Datenbankanlage und Migrationen

```bash
bin/rails db:create
bin/rails db:migrate
```

oder kombiniert:

```bash
bin/rails db:prepare
```

## 14) Importbefehle

Normalisierung der offiziellen XLSX (optional):

```bash
bin/rails "bbcx:normalize_xlsx[data/raw/gesamtdatei-stundenwerte.xlsx,2025,data/raw/bbcx_normalized_2025.csv]"
```

CSV-Import:

```bash
bin/rails "bbcx:import[data/raw/bbcx_normalized_2025.csv]"
```

Normalisieren + Import in einem Schritt:

```bash
bin/rails "bbcx:normalize_and_import[data/raw/gesamtdatei-stundenwerte.xlsx,2025,data/raw/bbcx_normalized_2025.csv]"
```

Reproduzierbare Demodaten:

```bash
bin/rails bbcx:seed_demo
```

## 15) Testbefehle

```bash
bin/rails test
bin/rails test test/system
bin/rails test test/services/bike_counts/csv_importer_test.rb
bin/rails test test/queries/bike_counts/statistics_test.rb
```

## 16) Qualitäts- und Sicherheitsprüfungen

```bash
bin/rubocop
bin/brakeman -q
bin/bundler-audit
bin/importmap audit
```

Kombinierter CI-Ablauf:

```bash
bin/ci
```

## 17) Produktionsfähigkeit / Konfiguration

- Produktions-Rails-Konfiguration vorhanden (`config/environments/production.rb`)
- Healthcheck-Route vorhanden: `GET /up`
- Asset-Precompile über Dockerfile und Rails-Task vorbereitet
- Secrets sind von Git getrennt (`config/*.key` ignoriert)
- `.gitignore` schließt lokale Rohdaten (`data/raw/*`) und lokale Gem-Installationen (`vendor/bundle`) aus
- Fehlermeldungen im Import zeigen keine internen Dateisystempfade

## 18) Deployment

Für ein kostenloses CV-Demo-Hosting ist **Render** vorbereitet:

- Blueprint-Datei: `render.yaml`
- Runtime: Docker (nutzt vorhandenes `Dockerfile`)
- Healthcheck: `/up`
- Infrastruktur reduziert:
  - keine Redis-Pflicht (Action Cable läuft in Produktion mit `async`)
  - Single-Postgres-Setup möglich (alle DB-Rollen können auf `DATABASE_URL` fallen)


## 19) Bekannte Einschränkungen

- Keine Multi-Station-Vergleichsansicht.
- Keine Mehrjahres-/Wochentagsanalyse.
- Keine Kartenansicht.
- Keine Upload-Oberfläche für Imports (nur Rake-Tasks).
- `import_batches` wird aktuell nicht in einer eigenen UI dargestellt.

## 20) Mögliche Erweiterungen

- Vergleich mehrerer Zählstellen
- weitere Zeitfilter (z. B. Wochentage)
- erweiterte Importhistorie als Admin-Ansicht
- weitere Diagrammtypen
- Produktionsspeicher für Active Storage (statt lokal)
