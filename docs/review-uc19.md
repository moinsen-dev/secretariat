# Kritik UC19 / T024 (Verlauf mit Herkunft)

Unabhängiger Kritiker (Subagent, frischer Kontext), 2026-10-30.

- Runde 1 auf 2c7836d: **REWORK**, sieben Befunde (vier mittel: Nebenläufigkeit kaum belegt, ein ungültiges Byte leert den Verlauf, kaputte Zeile schaltet auf langsamen Weg/Nachbarn verschmelzen, Löschprüfung parst bei jedem CLI-Aufruf alles unter Sperre; drei niedrig: reservierte Herkunftsnamen, voller Pfad bei inject, kein Löschen beim App-Start). Alle behoben, siehe `docs/t024-evidence.md`.
- Runde 2 auf bbb2512: **PASS**. 83/83 grün; Datumsrechnung unabhängig nachgerechnet (292 560 Tage 1600–2400, 0 Abweichungen); Block-Parsing, Bytesuche und Löschen ohne Reihenfolge-Annahme bestätigt. Restpunkte niedrig, danach erledigt: Datum gegen Monatslänge und Uhrzeitgrenzen prüfen; fehlender Zeilenumbruch nach Absturz (neuer Eintrag wird jetzt abgesetzt); Test für zwei verschmelzende Hälften; Kommentar zu `prune`. Offen gelassen: die Wiederholschleife der Setup-Sperre (Ursache des seltenen `setup_busy` im parallelen Testlauf nicht abschließend geklärt; Nutzerverhalten unverändert, nur bis 0,5 s Wartezeit statt sofortigem Abbruch).
