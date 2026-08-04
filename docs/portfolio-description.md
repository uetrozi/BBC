# Portfolio-Kurztext (max. 3 Sätze)

BerlinBikeCountExplorer (BBC-X) demonstriert einen robusten End-to-End-Workflow für offizielle Berliner Radzähldaten: von CSV-Import und Datenqualitätsprüfung bis zur filterbaren Auswertung im Web.  
Die Anwendung verarbeitet Daten in PostgreSQL, aggregiert Tageswerte serverseitig mit Active Record und stellt Ergebnisse als Tabelle, Kennzahlen und Chart.js-Zeitreihe konsistent dar.  
Technisch liegt der Schwerpunkt auf Ruby on Rails, PostgreSQL, SQL-naher Datenaggregation, Testautomatisierung und produktionsnaher Konfigurationsvorbereitung.

# Lebenslauf-Bullets (3-5 Punkte)

- Entwickelte eine Rails-8-Anwendung zur Analyse offizieller Berliner Radzähldaten mit PostgreSQL-Backend und reproduzierbarem CSV-Importprozess.
- Implementierte robuste Importlogik mit Zeilenvalidierung, Duplikaterkennung via DB-Constraint und nachvollziehbarer Importhistorie (`ImportBatch`).
- Setzte serverseitige Filter- und Statistikabfragen um, inklusive Tagesaggregation und konsistenter Datenbasis für Tabelle, Kennzahlen und Diagramm.
- Integrierte Chart.js über Importmap und stellte barrierearme, URL-basierte Bedienbarkeit ohne JavaScript-Zwang sicher.
- Etablierte Qualitätssicherung mit Minitest (inkl. Systemtest), RuboCop und Brakeman für Regression, Stabilität und Security-Baseline.
