# Data Source Analysis (Phase 1)

## Official source used

- Dataset name: Radzahldaten in Berlin
- Publisher: Senatsverwaltung fur Mobilitat, Verkehr, Klimaschutz und Umwelt
- Open data portal page: https://daten.berlin.de/datensaetze/radzahldaten-in-berlin
- Resource URL used for analysis: https://www.berlin.de/sen/uvk/_assets/verkehr/verkehrsplanung/radverkehr/weitere-radinfrastruktur/zaehlstellen-und-fahrradbarometer/gesamtdatei-stundenwerte.xlsx
- License: Datenlizenz Deutschland - Zero - Version 2.0 (dl-de-zero-2.0)
- Temporal coverage listed in metadata: 2012-01-01 to 2025-12-31

## Important finding

The official open resource is currently provided as XLSX, not as CSV. For BBC-X phase 1, we therefore derive a normalized CSV import file from the official XLSX content.

## Workbook structure (real file)

Sheets found:

- Hinweise
- Legende
- Standortdaten
- Jahresdatei 2012 ... Jahresdatei 2025

### Standort metadata sheet

`Standortdaten` columns:

- `Zahlstelle`
- `Beschreibung - Fahrtrichtung`
- `Breitengrad`
- `Langengrad`
- `Installationsdatum`

This sheet provides station identity and descriptive metadata.

### Yearly measurement sheets

Each yearly sheet contains:

- Column 1: hourly timestamp (`datetime` values)
- Remaining columns: station-specific count series
- Header pattern in station columns: external station code plus installation date, for example `02-MI-JAN-N 01.04.2015`

Observations:

- Hourly granularity is confirmed.
- Missing values occur (`nil`/empty cells).
- In some years there are explicit `0` values.
- The number of station columns changes across years.
- Some station identifiers can differ between sheets due to source-side naming inconsistencies.

## Import-relevant mapping for BBC-X

For the phase-1 importer, we import a normalized CSV with these fields:

- `counted_at` (timestamp)
- `station_external_id` (station code)
- `station_name` (description)
- `count` (integer)
- optional: `latitude`, `longitude`, `installed_at`

## Required transformations before CSV import

To convert from official XLSX to the normalized CSV:

1. Choose one yearly sheet (for MVP: 2025 recommended).
2. Unpivot wide hourly station columns into row-wise records.
3. Join station code with metadata from `Standortdaten` to add name and coordinates.
4. Keep UTF-8 output and ISO-8601 timestamps.
5. Preserve missing values handling:
   - skip rows without valid timestamp or count
   - allow zero counts as valid measurements
