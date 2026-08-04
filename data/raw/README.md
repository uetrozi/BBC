# Raw Data Folder

Place locally downloaded source files in this directory.

Expected workflow for BBC-X phase 1:

1. Download the official XLSX resource from the Berlin Open Data dataset "Radzahldaten in Berlin".
2. Normalize one yearly sheet (for example year 2025) with the rake task:

   `bin/rails "bbcx:normalize_xlsx[data/raw/gesamtdatei-stundenwerte.xlsx,2025,data/raw/bbcx_normalized_2025.csv]"`

3. Run the importer task:

   `bin/rails "bbcx:import[data/raw/your_normalized_file.csv]"`

The normalized CSV must contain at least these headers:

- `counted_at`
- `station_external_id`
- `station_name`
- `count`

Optional headers:

- `latitude`
- `longitude`
- `installed_at`

Large source files in this folder are intentionally git-ignored.
