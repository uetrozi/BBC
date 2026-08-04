# Screenshot Guide (Portfolio)

## Zielbild

Ein Explorer-Screenshot mit:

- gesetztem Station-Filter
- gesetztem Zeitraum
- sichtbaren Kennzahlen
- sichtbarem Liniendiagramm
- sichtbarer Ergebnistabelle

## Vorbereitung

```bash
bin/rails db:prepare
bin/rails bbcx:seed_demo
bin/rails server
```

## Seite und Filter

1. Öffne `http://localhost:3000/explorer`
2. Setze:
   - Zählstelle: `DEMO-01-JAN-N - Jannowitzbrücke Nord (Demo)`
   - Start date: `2025-05-01`
   - End date: `2025-05-03`
3. Klicke `Apply filters`

## Empfohlene Bildschirmbreite

- Desktop-Screenshot: 1366 px Breite
- Browserfenster so skalieren, dass gleichzeitig sichtbar sind:
  - aktiver Filterbereich
  - Kennzahlenkarten
  - Diagramm
  - Tabellenbeginn

## Was nicht sichtbar sein soll

- Browser-Devtools
- Terminalfenster
- lokale Dateipfade
- Debug-Overlays
