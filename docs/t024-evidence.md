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
| Mehrere Prozesse | kein Eintrag verloren, jedes Löschen schreibt wirklich neu | Ein eigener Python-Prozess hängt mit derselben Sperre (`audit.lock`, `flock`) abwechselnd 2000 alte (01.08.) und 2000 neue Zeilen an, gleichzeitig drei Shell-Schleifen mit je 40 echten CLI-Aufrufen `get` (jeder löscht vorher nach der Einstellung). Ergebnis: 15 Löschläufe haben die Datei neu geschrieben, 2000 von 2000 neuen Zeilen da (alle verschieden), 0 alte übrig, 121 von 121 `get`-Einträgen da, Rechte `-rw-------`. Der erste Versuch fand eine Lücke: Python schreibt `"at": "…"` mit Leerzeichen, die Bytesuche erwartete `"at":"`, solche Zeilen blieben stehen. Behoben und mit Test belegt |
| Unit-Tests `xcrun swift test` | grün | 83/83, sechsmal. Darin: Herkunftserkennung (innerster Agent zuerst, `AI_AGENT=app` wird `agent-app`), alte/neue/kaputte Zeilen, eine Zeile mit abgeschnittenem Umlaut und eine zerrissene Zeile kosten nur sich selbst (Lesen, Löschen, `tail`), Zeiträume, Löschen Tag 31 weg/Tag 29 bleibt mit 0600, Schreiben und Löschen gleichzeitig (Threads, alte und neue Zeilen, mindestens 6 echte Neuschreibungen), nie Werte, CLI nur lesend, `inject` zeigt nur den Dateinamen, schnelle Datumsrechnung gleich `ISO8601DateFormatter` (Schalttag, Jahrhundert), 200 000 Zeilen mit einer kaputten Zeile unter 2 s im vollen, parallelen Testlauf (allein gemessen 0,55 s im Debug-Build; vorher 2,05–2,9 s, Engpass war `timegm` mit Zeitzonen-Sperre) |
| Werte im Protokoll | keine | `grep -iE 'sk_\|"value"'` im Test-Protokoll → 0 |

## Kritik und Korrekturen

Unabhängige Kritik auf 2c7836d: Plan **PASS**, UC19 **REWORK** mit sieben Punkten, alle behoben:

1. Nebenläufigkeit war kaum belegt (nur ein Löschlauf schrieb wirklich) → Test mit fortlaufend alten und neuen Zeilen und mindestens 6 Neuschreibungen; Prozesslauf mit fremdem Schreiber (s. o.).
2. Ein ungültiges Byte leerte den ganzen Verlauf und stoppte das Löschen → Lesen als `Data`, Zeilen einzeln dekodiert, Test mit abgeschnittenem Umlaut.
3. Eine kaputte Zeile schaltete auf den langsamen Weg, Nachbarzeilen konnten verschmelzen → Blöcke zu 5000 Zeilen, ein Block mit Fehler oder weniger Objekten als Zeilen wird zeilenweise gelesen; Test mit kaputter Zeile in 200 000.
4. Jeder CLI-Aufruf parste die ganze Datei unter Sperre; Einschalten in der App auf dem Hauptthread → Löschen datiert Zeilen per Bytesuche und schreibt nur, wenn etwas wegfällt; Umschalten speichert nur die Einstellung, gelöscht wird abseits des Hauptthreads.
5. `AI_AGENT=app/terminal/script/earlier/mcp` gab sich als App oder Person aus → wird zu `agent-…`.
6. `inject` zeigte den vollen Pfad → nur Dateiname.
7. App löschte nur beim Öffnen von History → auch bei jedem Laden/Zurückkehren, abseits des Hauptthreads.

Nebenbei: Der schon vorher gelegentlich rote Test `setupPreservesExistingBytesAndIsIdempotent` (`setup_busy`, `errno` 35, kein anderer Halter laut `lsof`) wartet eine kurz gehaltene Ordnersperre jetzt bis zu 0,5 s ab; seitdem 6 von 6 Läufen grün.

## Einschränkungen

- Herkunft ist die Angabe des aufrufenden Prozesses; ein Agent kann seine Umgebung leeren (steht im Plan als Restrisiko und im Hinweis der App).
- Erkennung „Protokoll wurde zurückgesetzt“ (Vorschlag der Planprüfung) ist nicht gebaut; ein Prozess als Nutzer kann `audit.log` ändern (Restrisiko im Plan).
- Der Lauf mit mehreren Prozessen nutzt drei Schreiber, die selbst löschen; das Unit-Test-Gegenstück nutzt Threads.
