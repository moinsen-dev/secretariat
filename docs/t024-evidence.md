# T024 – Verlauf mit Herkunft (Nachweis)

Stand: 3c9d7b1 plus Korrekturen (Commit siehe Tracker), signiertes `dist/Secretariat.app` aus `script/build.sh`, App gestartet mit `SECRETARIAT_HOME=/private/tmp/claude-501/history-test/home` (Test-Tresor), macOS 27.0, 2026-10-30.

## Fehler „Verlauf öffnen verschiebt das Fenster“

Ursache per Ausschluss am laufenden Test-Build gefunden (Schalter, die je einen Teil weglassen): ohne Liste rechts weiter verschoben, ohne Titel weiter verschoben, ohne mittlere Spalte nicht. Ursache war der Hinweistext unter dem Löschschalter im `safeAreaInset` mit `fixedSize(horizontal: false, vertical: true)`: ohne angebotene Breite gemessen wird er Hunderte Punkte hoch, und der ganze Fensterinhalt rutschte nach oben (Seitenleiste unter den Fensterknöpfen, Liste rechts außerhalb). Ohne `fixedSize` bleiben Fenster (Rahmen vor/nach Klick gleich: 1379×795 bei 322,207) und Inhalt stehen; Testschalter danach wieder entfernt.

## Schritte und Beobachtung (UC19)

| Schritt | Erwartung | Beobachtung |
|---|---|---|
| (1) Test-Tresor | Einträge aus App, Terminal, Claude Code, Codex, MCP-Client, Skript, eine 40 Tage alte Zeile ohne Herkunft | `audit.log` mit 13 Zeilen, darunter `2026-09-20` ohne `via` und `2026-10-10` von Codex |
| (2) History, 7 Tage | Diagramm, Anzahl je Herkunft, Liste ohne alte Zeile, Hinweis „nur dieser Mac“ | 11 Zugriffe, gestapeltes Balkendiagramm, Herkunftsliste (Script 4, Claude Code 3, App/Codex/MCP · Claude Desktop/Terminal je 1) mit Farbpunkten als Legende, Liste ohne die alten Zeilen; Hinweis „Only this Mac's history. The origin is what the calling program reports; an agent can hide it. Names only, never values.“ |
| (2) Jahr | alte Zeile unter „Before origins were recorded“ | 13 Zugriffe, „Before origins were recorded 1“, Zeile vom 20.09. in der Liste |
| (3) Filter Claude Code | nur dessen Einträge | 3 Zugriffe, drei „Run with profile acme-shop“, Untertitel „Claude Code“, „Show all origins“ hebt auf |
| (4) Löschen nach 30 Tagen an | 40-Tage-Zeile weg aus Datei und Ansicht, neuere bleiben, Löschen im Verlauf | Liste: „Deleted 1 entry older than 30 days“ und „Automatic deletion after 30 days“ oben, 20.09. weg, 10.10. bleibt (`docs/t024/history-year-retention-on.png`, Aufnahme vor der Korrektur „1 entries“ → „1 entry“); Datei: `grep -c 2026-09-20` → 0, Rechte `-rw-------` |
| (5) `secretariat history --period week` | dieselben Anzahlen, Schalter nicht änderbar | „13 entries in the last 7 days on this Mac: Script 4, App 3, Claude Code 3, Codex 1, MCP · Claude Desktop 1, Terminal 1 · automatic deletion: after 30 days (change it in the app)“ – entspricht der App nach Schritt 4; `--json` gleiche Zahlen; `history --retention off` → „Unknown option“; es gibt keinen CLI-Befehl für den Schalter |
| Mehrere Prozesse | kein Eintrag verloren | 300 Zeilen vom 01.08. angehängt, dann drei parallele Shell-Schleifen mit je 25 echten CLI-Aufrufen `get` (jeder Aufruf löscht vorher nach der Einstellung): 0 alte Zeilen übrig, 75 von 75 `get`-Einträgen da, `history.pruned` mit `entries: 300` |
| Unit-Tests `xcrun swift test` | grün | 79/79, zweimal. Darin: Herkunftserkennung (innerster Agent zuerst), alte/neue/kaputte Zeilen, Zeiträume, Löschen Tag 31 weg/Tag 29 bleibt mit 0600, paralleles Schreiben beim Löschen (Threads), nie Werte, CLI nur lesend, 200 000 Zeilen in 1,2 s (Debug; vorher 2,05–2,2 s), Einzahl/Mehrzahl |
| Werte im Protokoll | keine | `grep -iE 'sk_\|"value"'` im Test-Protokoll → 0 |

## Einschränkungen

- Herkunft ist die Angabe des aufrufenden Prozesses; ein Agent kann seine Umgebung leeren (steht im Plan als Restrisiko und im Hinweis der App).
- Erkennung „Protokoll wurde zurückgesetzt“ (Vorschlag der Planprüfung) ist nicht gebaut; ein Prozess als Nutzer kann `audit.log` ändern (Restrisiko im Plan).
- Der Lauf mit mehreren Prozessen nutzt drei Schreiber, die selbst löschen; das Unit-Test-Gegenstück nutzt Threads.
